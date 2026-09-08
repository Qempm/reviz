import type { ZodType } from 'zod'
import { complete, extractJson, HttpError } from './client'
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
  questions: ['deepseekFlash', 'qwenFlash', 'glmFlash'],
  flashcards: ['deepseekFlash', 'qwenFlash', 'glmFlash'],
  exam_predictions: ['deepseekFlash', 'qwenFlash', 'glmFlash'],
  // Corrections notées difficiles : DeepSeek Pro avec raisonnement activé.
  correction: ['deepseekPro', 'deepseekFlash', 'qwenFlash', 'glmFlash'],
  // Lecture de photos : seuls les modèles vision peuvent traiter la demande.
  student_card: ['deepseekVision', 'qwenFlash'],
}

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
  /** Consigne la consommation, typiquement dans ai_usage. */
  recordUsage?: UsageRecorder
  env?: NodeJS.ProcessEnv
  fetchImpl?: typeof fetch
  signal?: AbortSignal
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

    const debut = Date.now()
    let usage = { ...EMPTY_USAGE }
    let outcome: Attempt['outcome'] = 'network_error'
    let erreur: string | undefined

    try {
      const res = await complete({
        spec,
        messages: opts.messages,
        apiKey,
        temperature: opts.temperature,
        maxTokens: opts.maxTokens,
        jsonMode: true,
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

      outcome = 'success'
      const cout = estimateCost(spec, usage)

      attempts.push({
        provider: spec.provider,
        model: spec.model,
        outcome,
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
      if (outcome === 'network_error' && e instanceof HttpError) {
        outcome = 'http_error'
      }
      erreur = e instanceof Error ? e.message : String(e)

      const cout = estimateCost(spec, usage)
      attempts.push({
        provider: spec.provider,
        model: spec.model,
        outcome,
        usage,
        costUsd: cout,
        durationMs: Date.now() - debut,
        error: erreur,
      })

      // L'appel a pu aboutir et ne échouer qu'à la validation : les jetons
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
    }
  }

  throw new AiError(
    `Aucun fournisseur n'a produit de réponse valide pour « ${opts.task} ».`,
    attempts,
  )
}
