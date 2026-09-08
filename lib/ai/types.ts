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

/** Tarifs en dollars par million de jetons. */
export type Pricing = {
  input: number
  cacheHit: number
  output: number
}

export type ReasoningEffort = 'low' | 'high' | 'max'

export type ModelSpec = {
  provider: ProviderId
  model: string
  capabilities: readonly Capability[]
  /** Active le mode réflexion chez les fournisseurs qui l'exposent. */
  thinking?: boolean
  /**
   * Intensité de raisonnement. GLM la met à « high » par défaut : la laisser
   * implicite reviendrait à payer du raisonnement sur des tâches qui n'en
   * demandent pas (docs/STACK-IA.md § 3.3).
   */
  reasoningEffort?: ReasoningEffort
  pricing: Pricing
  /**
   * Tarif heures pleines. DeepSeek facture le double entre 01:00–04:00 et
   * 06:00–10:00 UTC en semaine depuis le 16/08/2026 (docs/STACK-IA.md § 1.2).
   */
  peakPricing?: Pricing
}

export type AttemptOutcome =
  | 'success'
  | 'http_error'
  | 'network_error'
  | 'invalid_json'
  | 'schema_error'
  | 'empty_content'
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
