/**
 * Couche IA de Reviz.
 *
 * Point d'entrée unique : `runAiTask`. Elle descend la chaîne de secours
 * DeepSeek → Qwen → GLM, valide la sortie par un schéma Zod et consigne la
 * consommation.
 *
 * Ces appels ne se font que depuis le serveur : les clés vivent dans
 * l'environnement, jamais dans le client (CLAUDE.md, section Stack).
 */
export {
  runAiTask,
  ROUTES,
  SAME_PROVIDER_ATTEMPTS,
  RETRY_DELAY_MS,
} from './routing'
export type { RunOptions, RunResult, UsageRecorder } from './routing'

export { recordAiUsage } from './usage'

export {
  canStartJob,
  isDeepSeekPeakHour,
  nextAllowedStart,
  HEAVY_JOB_TYPES,
  MAX_WAIT_MS,
} from './peak-hours'

export {
  correctionPayloadSchema,
  flashcardsPayloadSchema,
  questionsPayloadSchema,
  studentCardPayloadSchema,
  questionSchema,
  flashcardSchema,
  TASK_SCHEMAS,
} from './schemas'
export type {
  AiTask,
  CorrectionPayload,
  FlashcardsPayload,
  Question,
  QuestionsPayload,
  StudentCardPayload,
} from './schemas'

export { MODELS, PROVIDERS, estimateCost, pricingAt } from './providers'
export type { ModelKey, ProviderSpec } from './providers'

export { complete, extractJson, parseUsage, HttpError, EmptyContentError } from './client'
export { AiError } from './types'
export type {
  Attempt,
  ChatMessage,
  Capability,
  ModelSpec,
  Pricing,
  ProviderId,
  ReasoningEffort,
  TokenUsage,
} from './types'
