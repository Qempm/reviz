import type { ZodType } from 'zod'
import { complete, EmptyContentError, extractJson, HttpError } from './client'
import { estimateCost, MODELS, readApiKey, type ModelKey } from './providers'
import { TASK_SCHEMAS, type AiTask } from './schemas'
import {
  AiError,
  EMPTY_USAGE,
  type Attempt,
  type ChatMessage,
  type ModelSpec,
} from './types'

/**
 * Table de routage : DeepSeek en tête, puis Qwen, puis GLM
 * (CLAUDE.md, section Stack).
 *
 * La bascule se déclenche sur erreur réseau, erreur HTTP, JSON illisible ou
 * JSON invalide au regard du schéma Zod (règle métier 7).
 */
export const ROUTES: Record<AiTask, ModelKey[]> = {
  // Texte (docs/STACK-IA.md § 0).
  questions: ['deepseekFlash', 'qwenFlash', 'glmFlash'],
  flashcards: ['deepseekFlash', 'qwenFlash', 'glmFlash'],
  exam_predictions: ['deepseekFlash', 'qwenFlash', 'glmFlash'],
  // Correction notée difficile : DeepSeek Pro puis GLM 5.3, les deux seuls
  // modèles de raisonnement de la pile.
  correction: ['deepseekPro', 'glmPro'],
  // Lecture de photo : GLM 5.3 Flash a la vision native et passe avant Qwen,
  // dont le modèle vision est qwen3-vl-flash et non qwen3.8-flash.
  student_card: ['deepseekVision', 'glmFlash', 'qwenVlFlash'],
}

/**
 * Paramètres d'appel par tâche (docs/STACK-IA.md § 4.4).
 *
 * Une correction se veut déterministe et tient en 4 000 jetons ; une
 * génération de QCM a besoin de latitude et de place, sous peine de JSON
 * tronqué (§ 1.4).
 */
const TASK_PARAMS: Record<AiTask, { temperature: number; maxTokens: number }> = {
  questions: { temperature: 0.7, maxTokens: 8000 },
  flashcards: { temperature: 0.7, maxTokens: 8000 },
  exam_predictions: { temperature: 0.7, maxTokens: 8000 },
  correction: { temperature: 0.2, maxTokens: 4000 },
  student_card: { temperature: 0.2, maxTokens: 2000 },
}

/** Codes HTTP qui justifient un réessai chez le même fournisseur. */
const RETRIABLE_STATUS = new Set([429])

/** Nombre de tentatives sur le même fournisseur avant de basculer. */
export const SAME_PROVIDER_ATTEMPTS = 3

/** Attente entre deux tentatives sur le même fournisseur. */
export const RETRY_DELAY_MS = 2000

const sleep = (ms: number) =>
  ms > 0 ? new Promise((r) => setTimeout(r, ms)) : Promise.resolve()

/** Un message contient-il une image ? */
function needsVision(messages: ChatMessage[]): boolean {
  return messages.some(
    (m) =>
      Array.isArray(m.content) && m.content.some((p) => p.type === 'image_url'),
  )
}

export type UsageRecorder = (entry: {
  jobId?: string
  provider: string
  model: string
  promptTokens: number
  completionTokens: number
  cacheHitTokens: number
  costUsdEstimate: number
}) => void | Promise<void>

export type RunOptions<T> = {
  task: AiTask
  messages: ChatMessage[]
  /** Par défaut, le schéma associé à la tâche. */
  schema?: ZodType<T>
  jobId?: string
  temperature?: number
  maxTokens?: number
  /** Isolation du cache DeepSeek par étudiant. Jamais de donnée personnelle. */
  userId?: string
  /** Consigne la consommation, typiquement dans ai_usage. */
  recordUsage?: UsageRecorder
  env?: NodeJS.ProcessEnv
  fetchImpl?: typeof fetch
  signal?: AbortSignal
  /** Horloge, pour dater le tarif appliqué. */
  now?: () => Date
  /** Attente entre deux tentatives. Mise à 0 dans les tests. */
  retryDelayMs?: number
}

export type RunResult<T> = {
  data: T
  provider: string
  model: string
  attempts: Attempt[]
}

/**
 * Exécute une tâche IA en descendant la chaîne de secours.
 *
 * Chaque tentative est consignée, y compris celles qui échouent : un appel
 * dont le JSON est invalide a tout de même consommé des jetons, et les
 * ignorer fausserait le suivi de coût.
 */
export async function runAiTask<T = unknown>(
  opts: RunOptions<T>,
): Promise<RunResult<T>> {
  const schema = (opts.schema ?? TASK_SCHEMAS[opts.task]) as ZodType<T>
  const env = opts.env ?? process.env
  const vision = needsVision(opts.messages)
  const horloge = opts.now ?? (() => new Date())
  const attempts: Attempt[] = []

  for (const key of ROUTES[opts.task]) {
    const spec = MODELS[key] as ModelSpec

    // Un modèle sans vision ne peut rien faire d'une photo : on le saute
    // sans l'appeler plutôt que de payer une erreur.
    if (vision && !spec.capabilities.includes('vision')) {
      attempts.push({
        provider: spec.provider,
        model: spec.model,
        outcome: 'skipped_capability',
        usage: { ...EMPTY_USAGE },
        costUsd: 0,
        durationMs: 0,
        error: 'Le modèle ne traite pas les images.',
      })
      continue
    }

    const apiKey = readApiKey(spec.provider, env)
    if (!apiKey) {
      attempts.push({
        provider: spec.provider,
        model: spec.model,
        outcome: 'skipped_capability',
        usage: { ...EMPTY_USAGE },
        costUsd: 0,
        durationMs: 0,
        error: 'Clé absente de l’environnement.',
      })
      continue
    }

    const params = TASK_PARAMS[opts.task]
    let basculer = false

    // Réessais sur le même fournisseur avant de descendre la chaîne : un 429
    // est une saturation passagère, pas une panne (docs/STACK-IA.md § 1.7).
    for (let essai = 1; essai <= SAME_PROVIDER_ATTEMPTS && !basculer; essai++) {
      const debut = Date.now()
      let usage = { ...EMPTY_USAGE }
      let outcome: Attempt['outcome'] = 'network_error'

      try {
        const res = await complete({
          spec,
          messages: opts.messages,
          apiKey,
          temperature: opts.temperature ?? params.temperature,
          maxTokens: opts.maxTokens ?? params.maxTokens,
          jsonMode: true,
          userId: opts.userId,
          signal: opts.signal,
          fetchImpl: opts.fetchImpl,
        })

        usage = res.usage

        let brut: unknown
        try {
          brut = extractJson(res.content)
        } catch (e) {
          outcome = 'invalid_json'
          throw e
        }

        const parsed = schema.safeParse(brut)
        if (!parsed.success) {
          outcome = 'schema_error'
          throw new Error(
            parsed.error.issues
              .slice(0, 3)
              .map((i) => `${i.path.join('.') || '(racine)'} : ${i.message}`)
              .join(' ; '),
          )
        }

        const cout = estimateCost(spec, usage, horloge())

        attempts.push({
          provider: spec.provider,
          model: spec.model,
          outcome: 'success',
          usage,
          costUsd: cout,
          durationMs: Date.now() - debut,
        })

        await opts.recordUsage?.({
          jobId: opts.jobId,
          provider: spec.provider,
          model: spec.model,
          promptTokens: usage.promptTokens,
          completionTokens: usage.completionTokens,
          cacheHitTokens: usage.cacheHitTokens,
          costUsdEstimate: cout,
        })

        return {
          data: parsed.data,
          provider: spec.provider,
          model: spec.model,
          attempts,
        }
      } catch (e) {
        if (outcome === 'network_error') {
          if (e instanceof HttpError) outcome = 'http_error'
          else if (e instanceof EmptyContentError) outcome = 'empty_content'
        }

        const reessayable =
          (e instanceof HttpError && RETRIABLE_STATUS.has(e.status)) ||
          e instanceof EmptyContentError

        const cout = estimateCost(spec, usage, horloge())
        attempts.push({
          provider: spec.provider,
          model: spec.model,
          outcome,
          usage,
          costUsd: cout,
          durationMs: Date.now() - debut,
          error: e instanceof Error ? e.message : String(e),
        })

        // L'appel a pu aboutir et n'échouer qu'à la validation : les jetons
        // sont dus, on les consigne.
        if (usage.promptTokens > 0 || usage.completionTokens > 0) {
          await opts.recordUsage?.({
            jobId: opts.jobId,
            provider: spec.provider,
            model: spec.model,
            promptTokens: usage.promptTokens,
            completionTokens: usage.completionTokens,
            cacheHitTokens: usage.cacheHitTokens,
            costUsdEstimate: cout,
          })
        }

        if (!reessayable || essai === SAME_PROVIDER_ATTEMPTS) {
          basculer = true
        } else {
          await sleep(opts.retryDelayMs ?? RETRY_DELAY_MS)
        }
      }
    }
  }

  throw new AiError(
    `Aucun fournisseur n'a produit de réponse valide pour « ${opts.task} ».`,
    attempts,
  )
}
