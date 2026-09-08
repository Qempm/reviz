import { isDeepSeekPeakHour } from './peak-hours'
import type { ModelSpec, Pricing, ProviderId } from './types'

/**
 * Fournisseurs IA, tous au format OpenAI Chat Completions.
 * Source : docs/STACK-IA.md, vérifié le 8 septembre 2026.
 */
export type ProviderSpec = {
  id: ProviderId
  label: string
  baseUrl: string
  /** Nom de la variable d'environnement portant la clé. */
  apiKeyEnv: string
  /** En-têtes constants exigés par le fournisseur. */
  headers?: Record<string, string>
}

export const PROVIDERS: Record<ProviderId, ProviderSpec> = {
  deepseek: {
    id: 'deepseek',
    label: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    apiKeyEnv: 'DEEPSEEK_API_KEY',
  },
  qwen: {
    id: 'qwen',
    label: 'Qwen',
    // Région Singapour. Ne pas viser dashscope.aliyuncs.com sans « -intl » :
    // c'est Pékin, avec des clés et une facturation distinctes.
    baseUrl: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
    apiKeyEnv: 'DASHSCOPE_API_KEY',
  },
  glm: {
    id: 'glm',
    label: 'GLM',
    baseUrl: 'https://api.z.ai/api/paas/v4',
    apiKeyEnv: 'ZAI_API_KEY',
    headers: { 'accept-language': 'en-US,en' },
  },
}

/**
 * Modèles, tarifs en dollars par million de jetons (docs/STACK-IA.md § 1.2,
 * 2.2 et 3.2).
 *
 * DeepSeek facture le double en heures pleines depuis le 16/08/2026 : d'où
 * `peakPricing`, appliqué par estimateCost selon l'heure de l'appel.
 */
export const MODELS = {
  deepseekFlash: {
    provider: 'deepseek',
    model: 'deepseek-v4-flash',
    capabilities: ['text'],
    pricing: { input: 0.22, cacheHit: 0.007, output: 0.66 },
    peakPricing: { input: 0.44, cacheHit: 0.014, output: 1.32 },
  },
  deepseekVision: {
    provider: 'deepseek',
    model: 'deepseek-v4-flash-vision-exp',
    capabilities: ['text', 'vision'],
    // « identique à Flash » (docs/STACK-IA.md § 1.2).
    pricing: { input: 0.22, cacheHit: 0.007, output: 0.66 },
    peakPricing: { input: 0.44, cacheHit: 0.014, output: 1.32 },
  },
  deepseekPro: {
    provider: 'deepseek',
    model: 'deepseek-v4-pro',
    capabilities: ['text', 'thinking'],
    thinking: true,
    reasoningEffort: 'high',
    pricing: { input: 0.66, cacheHit: 0.022, output: 1.98 },
    peakPricing: { input: 1.32, cacheHit: 0.044, output: 3.96 },
  },
  qwenFlash: {
    provider: 'qwen',
    model: 'qwen3.8-flash',
    // Modèle texte : la vision passe par qwen3-vl-flash.
    capabilities: ['text'],
    pricing: { input: 0.14, cacheHit: 0.14, output: 0.42 },
  },
  qwenVlFlash: {
    provider: 'qwen',
    model: 'qwen3-vl-flash',
    capabilities: ['text', 'vision'],
    // docs/STACK-IA.md ne donne pas de tarif pour les modèles vision Qwen :
    // on reprend celui de qwen3.8-flash faute de mieux. À confirmer.
    pricing: { input: 0.14, cacheHit: 0.14, output: 0.42 },
  },
  glmFlash: {
    provider: 'glm',
    model: 'glm-5.3-flash',
    // Vision native et raisonnement (docs/STACK-IA.md § 3.1).
    capabilities: ['text', 'vision', 'thinking'],
    // Le défaut du fournisseur est « high » : on force « low » partout sauf
    // sur les corrections, sinon on paie du raisonnement pour rien.
    reasoningEffort: 'low',
    pricing: { input: 0.15, cacheHit: 0.15, output: 0.5 },
  },
  glmPro: {
    provider: 'glm',
    model: 'glm-5.3',
    capabilities: ['text', 'vision', 'thinking'],
    reasoningEffort: 'high',
    pricing: { input: 1.4, cacheHit: 1.4, output: 4.4 },
  },
} as const satisfies Record<string, ModelSpec>

export type ModelKey = keyof typeof MODELS

/** Tarif applicable à l'instant donné. */
export function pricingAt(spec: ModelSpec, at: Date = new Date()): Pricing {
  return spec.peakPricing && isDeepSeekPeakHour(at)
    ? spec.peakPricing
    : spec.pricing
}

/** Coût estimé d'un appel, en dollars. */
export function estimateCost(
  spec: ModelSpec,
  usage: { promptTokens: number; completionTokens: number; cacheHitTokens: number },
  at: Date = new Date(),
): number {
  const tarif = pricingAt(spec, at)

  // Les jetons servis par le cache sont comptés à part : on les retire de
  // l'assiette d'entrée pour ne pas les facturer deux fois.
  const facturesEnEntree = Math.max(0, usage.promptTokens - usage.cacheHitTokens)

  const total =
    (facturesEnEntree * tarif.input +
      usage.completionTokens * tarif.output +
      usage.cacheHitTokens * tarif.cacheHit) /
    1_000_000

  // Six décimales : la précision de ai_usage.cost_usd_estimate.
  return Math.round(total * 1e6) / 1e6
}

/** Lit la clé du fournisseur. Renvoie null si elle n'est pas configurée. */
export function readApiKey(
  provider: ProviderId,
  env: NodeJS.ProcessEnv = process.env,
): string | null {
  return env[PROVIDERS[provider].apiKeyEnv]?.trim() || null
}
