'use server'

import { createClient } from '@/lib/supabase/server'
import {
  enregistrerSession as enregistrerSessionMetier,
  type EntreeSession,
  type ResultatEnregistrement,
} from '@/lib/metier/session'

/**
 * Fin de session — porte web.
 *
 * La logique est dans `lib/metier/session.ts`, partagée avec
 * `/api/session/terminer`. Le client n'envoie que ce qu'il a **choisi**,
 * jamais s'il avait juste : le serveur recorrige depuis `questions.answer`.
 */

export type { EntreeSession, ResultatEnregistrement } from '@/lib/metier/session'

export async function enregistrerSession(
  brut: EntreeSession,
): Promise<ResultatEnregistrement> {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return { ok: false, error: 'Session expirée.' }

  return enregistrerSessionMetier(supabase, user.id, brut)
}
