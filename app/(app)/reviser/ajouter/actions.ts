'use server'

import { revalidatePath } from 'next/cache'
import { createClient } from '@/lib/supabase/server'
import {
  preparerDepot as preparerDepotMetier,
  confirmerDepot as confirmerDepotMetier,
  annulerDepot as annulerDepotMetier,
  type EntreeDepot,
  type PreparationDepot,
} from '@/lib/metier/cours'

/**
 * Écran D1 — dépôt d'un cours, porte web.
 *
 * La logique est dans `lib/metier/cours.ts` : la route REST
 * `/api/cours/*` l'appelle aussi, pour que Flutter y accède sans passer par
 * le protocole des Server Actions. Ici on ne fait que la session et le cache.
 */

export type { EntreeDepot, PreparationDepot } from '@/lib/metier/cours'

export async function preparerDepot(brut: EntreeDepot): Promise<PreparationDepot> {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return { ok: false, error: 'session' }

  return preparerDepotMetier(supabase, user.id, brut)
}

export async function confirmerDepot(courseId: string): Promise<{ ok: boolean }> {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return { ok: false }

  const resultat = await confirmerDepotMetier(supabase, user.id, courseId)

  if (resultat.ok) {
    revalidatePath('/reviser')
    revalidatePath(`/cours/${courseId}`)
  }

  return resultat
}

export async function annulerDepot(courseId: string): Promise<void> {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) return

  await annulerDepotMetier(supabase, user.id, courseId)
}
