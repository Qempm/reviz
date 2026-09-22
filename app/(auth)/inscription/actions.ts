'use server'

import { createClient } from '@/lib/supabase/server'
import {
  creerProfil as creerProfilMetier,
  type EntreeProfil,
  type Reponse,
} from '@/lib/metier/profil'

/**
 * Création du profil — porte web.
 *
 * La logique est dans `lib/metier/profil.ts`, partagée avec `/api/profil`.
 */

export type { EntreeProfil } from '@/lib/metier/profil'

export async function creerProfil(
  entree: EntreeProfil,
): Promise<Reponse<{ id: string }>> {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    return { ok: false, error: 'Ta session a expiré. Reconnecte-toi.' }
  }

  return creerProfilMetier(supabase, user.id, entree)
}
