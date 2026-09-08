/** Types partagés par le client IA et la table de routage. */

export type ChatRole = 'system' | 'user' | 'assistant'

export type TextPart = { type: 'text'; text: string }
export type ImagePart = { type: 'image_url'; image_url: { url: string } }
export type ContentPart = TextPart | ImagePart

export type ChatMessage = {
  role: ChatRole
  /** Chaîne simple, ou parts multimodales pour les appels vision. */
  content: string | ContentPart[]
}

export type TokenUsage = {
  promptTokens: number
  completionTokens: number
  /** Jetons servis depuis le cache du fournisseur, facturés moins cher. */
  cacheHitTokens: number
}

export const EMPTY_USAGE: TokenUsage = {
  promptTokens: 0,
  completionTokens: 0,
  cacheHitTokens: 0,
}

/** Ce que le fournisseur sait faire — sert à filtrer la chaîne de secours. */
export type Capability = 'text' | 'vision' | 'thinking'

export type ProviderId = 'deepseek' | 'qwen' | 'glm'

export type ModelSpec = {
  provider: ProviderId
  model: string
  capabilities: Capability[]
  /** Active le mode raisonnement chez les fournisseurs qui l'exposent. */
  thinking?: boolean
  /**
   * Tarifs en dollars par million de jetons.
   *
   * ATTENTION : valeurs provisoires. docs/STACK-IA.md, qui devait porter les
   * tarifs réels, n'existe pas encore. `cost_usd_estimate` dans ai_usage n'a
   * donc qu'une valeur indicative tant que ces nombres n'ont pas été
   * confrontés aux grilles des fournisseurs.
   */
  pricing: { input: number; output: number; cacheHit: number }
}

export type AttemptOutcome =
  | 'success'
  | 'http_error'
  | 'network_error'
  | 'invalid_json'
  | 'schema_error'
  | 'skipped_capability'

export type Attempt = {
  provider: ProviderId
  model: string
  outcome: AttemptOutcome
  usage: TokenUsage
  costUsd: number
  durationMs: number
  error?: string
}

export class AiError extends Error {
  constructor(
    message: string,
    readonly attempts: Attempt[],
  ) {
    super(message)
    this.name = 'AiError'
  }
}
