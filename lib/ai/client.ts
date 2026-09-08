import { PROVIDERS } from './providers'
import { EMPTY_USAGE, type ChatMessage, type ModelSpec, type TokenUsage } from './types'

/**
 * Client générique pour une API au format OpenAI Chat Completions.
 * Les trois fournisseurs de la pile l'exposent, d'où un seul client.
 */

export type CompletionOptions = {
  spec: ModelSpec
  messages: ChatMessage[]
  apiKey: string
  temperature?: number
  maxTokens?: number
  /** Demande une réponse strictement JSON quand le fournisseur le supporte. */
  jsonMode?: boolean
  signal?: AbortSignal
  fetchImpl?: typeof fetch
}

export type CompletionResult = {
  /** Contenu brut du message, avant toute tentative d'analyse. */
  content: string
  usage: TokenUsage
  raw: unknown
}

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly body: string,
  ) {
    super(`HTTP ${status}: ${body.slice(0, 300)}`)
    this.name = 'HttpError'
  }
}

/**
 * Lit la consommation renvoyée par le fournisseur.
 *
 * Les trois n'utilisent pas les mêmes noms pour les jetons servis en cache :
 * DeepSeek expose `prompt_cache_hit_tokens`, les autres passent par
 * `prompt_tokens_details.cached_tokens`. Un champ absent vaut zéro plutôt
 * que de faire échouer l'appel — une facturation approximative est moins
 * grave qu'un job perdu.
 */
export function parseUsage(raw: unknown): TokenUsage {
  const u = (raw as { usage?: Record<string, unknown> } | null)?.usage
  if (!u) return { ...EMPTY_USAGE }

  const nombre = (v: unknown): number =>
    typeof v === 'number' && Number.isFinite(v) && v >= 0 ? Math.round(v) : 0

  const details = u.prompt_tokens_details as
    | { cached_tokens?: unknown }
    | undefined

  return {
    promptTokens: nombre(u.prompt_tokens),
    completionTokens: nombre(u.completion_tokens),
    cacheHitTokens:
      nombre(u.prompt_cache_hit_tokens) || nombre(details?.cached_tokens),
  }
}

export async function complete(
  opts: CompletionOptions,
): Promise<CompletionResult> {
  const doFetch = opts.fetchImpl ?? fetch
  const base = PROVIDERS[opts.spec.provider].baseUrl.replace(/\/+$/, '')

  const body: Record<string, unknown> = {
    model: opts.spec.model,
    messages: opts.messages,
    temperature: opts.temperature ?? 0.2,
  }

  if (opts.maxTokens) body.max_tokens = opts.maxTokens
  if (opts.jsonMode) body.response_format = { type: 'json_object' }
  if (opts.spec.thinking) body.thinking = { type: 'enabled' }

  const res = await doFetch(`${base}/chat/completions`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${opts.apiKey}`,
    },
    body: JSON.stringify(body),
    signal: opts.signal,
  })

  if (!res.ok) {
    throw new HttpError(res.status, await res.text().catch(() => ''))
  }

  const raw = (await res.json()) as {
    choices?: Array<{ message?: { content?: unknown } }>
  }

  const content = raw?.choices?.[0]?.message?.content
  if (typeof content !== 'string') {
    throw new Error('Réponse sans contenu textuel exploitable.')
  }

  return { content, usage: parseUsage(raw), raw }
}

/**
 * Extrait un objet JSON d'une réponse de modèle.
 *
 * Même en mode JSON, les modèles encadrent parfois leur sortie d'une clôture
 * markdown ou d'une phrase d'introduction. On nettoie avant d'abandonner,
 * plutôt que de basculer vers le fournisseur suivant pour trois backticks.
 */
export function extractJson(content: string): unknown {
  const texte = content.trim()

  try {
    return JSON.parse(texte)
  } catch {
    // On poursuit avec les stratégies de repli.
  }

  const fence = texte.match(/```(?:json)?\s*([\s\S]*?)```/i)
  if (fence?.[1]) {
    try {
      return JSON.parse(fence[1].trim())
    } catch {
      // On poursuit.
    }
  }

  const debut = texte.search(/[[{]/)
  const fin = Math.max(texte.lastIndexOf('}'), texte.lastIndexOf(']'))
  if (debut !== -1 && fin > debut) {
    return JSON.parse(texte.slice(debut, fin + 1))
  }

  throw new SyntaxError('Aucun JSON exploitable dans la réponse.')
}
