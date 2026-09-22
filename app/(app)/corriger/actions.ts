'use server'

import { createClient } from '@/lib/supabase/server'
import {
  deposerCorrection as deposerCorrectionMetier,
  type ResultatDepot,
} from '@/lib/metier/corrections'

/**
 * Dépôt d'une copie — porte web.
 *
 * La logique est dans `lib/metier/corrections.ts`, partagée avec
 * `/api/corrections`.
 */

export type { ResultatDepot } from '@/lib/metier/corrections'

export async function deposerCorrection(
  copie: File,
  sujet?: File,
): Promise<ResultatDepot> {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return { ok: false, error: 'session' }

  return deposerCorrectionMetier(supabase, user.id, copie, sujet)
}
