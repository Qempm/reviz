import type { ModelSpec, ProviderId } from './types'

/**
 * Fournisseurs IA, tous au format OpenAI Chat Completions.
 * Sources : CLAUDE.md, section Stack.
 */
export type ProviderSpec = {
  id: ProviderId
  label: string
  baseUrl: string
  /** Nom de la variable d'environnement portant la clé. */
  apiKeyEnv: string
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
    baseUrl: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
    apiKeyEnv: 'DASHSCOPE_API_KEY',
  },
  glm: {
    id: 'glm',
    label: 'GLM',
    baseUrl: 'https://api.z.ai/api/paas/v4',
    apiKeyEnv: 'ZAI_API_KEY',
  },
}

/**
 * Modèles disponibles.
 *
 * Les tarifs sont provisoires (voir ModelSpec.pricing) et les capacités des
 * modèles de secours en vision n'ont pas été vérifiées auprès des
 * fournisseurs : c'est ce que docs/STACK-IA.md doit trancher.
 */
export const MODELS = {
  deepseekFlash: {
    provider: 'deepseek',
    model: 'deepseek-v4-flash',
    capabilities: ['text'],
    pricing: { input: 0.27, output: 1.1, cacheHit: 0.07 },
  },
  deepseekVision: {
    provider: 'deepseek',
    model: 'deepseek-v4-flash-vision-exp',
    capabilities: ['text', 'vision'],
    pricing: { input: 0.27, output: 1.1, cacheHit: 0.07 },
  },
  deepseekPro: {
    provider: 'deepseek',
    model: 'deepseek-v4-pro',
    capabilities: ['text', 'thinking'],
    thinking: true,
    pricing: { input: 0.55, output: 2.19, cacheHit: 0.14 },
  },
  qwenFlash: {
    provider: 'qwen',
    model: 'qwen3.8-flash',
    capabilities: ['text', 'vision'],
    pricing: { input: 0.3, output: 1.2, cacheHit: 0.08 },
  },
  glmFlash: {
    provider: 'glm',
    model: 'glm-5.3-flash',
    capabilities: ['text'],
    pricing: { input: 0.29, output: 1.15, cacheHit: 0.08 },
  },
} as const satisfies Record<string, ModelSpec>

export type ModelKey = keyof typeof MODELS

/** Coût estimé d'un appel, en dollars. */
export function estimateCost(
  spec: ModelSpec,
  usage: { promptTokens: number; completionTokens: number; cacheHitTokens: number },
): number {
  // Les jetons servis par le cache sont comptés à part : on les retire de
  // l'assiette d'entrée pour ne pas les facturer deux fois.
  const facturesEnEntree = Math.max(0, usage.promptTokens - usage.cacheHitTokens)

  const total =
    (facturesEnEntree * spec.pricing.input +
      usage.completionTokens * spec.pricing.output +
      usage.cacheHitTokens * spec.pricing.cacheHit) /
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
