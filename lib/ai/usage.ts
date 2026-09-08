import { createAdminClient } from '@/lib/supabase/admin'
import type { UsageRecorder } from './routing'

/**
 * Consigne la consommation IA dans `ai_usage`.
 *
 * Écrit avec le rôle de service : la table n'a aucune politique RLS, elle est
 * fermée au client (supabase/migrations/20260908120600_rls.sql).
 *
 * Une écriture ratée ne fait pas échouer le job : perdre une ligne de suivi
 * de coût est moins grave que perdre un cours déjà traité et payé. L'erreur
 * part en journal pour être vue.
 */
export const recordAiUsage: UsageRecorder = async (entry) => {
  try {
    const supabase = createAdminClient()

    const { error } = await supabase.from('ai_usage').insert({
      job_id: entry.jobId ?? null,
      provider: entry.provider,
      model: entry.model,
      prompt_tokens: entry.promptTokens,
      completion_tokens: entry.completionTokens,
      cache_hit_tokens: entry.cacheHitTokens,
      cost_usd_estimate: entry.costUsdEstimate,
    })

    if (error) {
      console.error('[ai_usage] insertion refusée', error.message)
    }
  } catch (e) {
    console.error(
      '[ai_usage] insertion impossible',
      e instanceof Error ? e.message : e,
    )
  }
}
