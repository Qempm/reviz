import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { creerProfil } from '@/lib/metier/profil'

/**
 * POST /api/profil
 *
 * Crée le profil après la première connexion : prénom, université, filière,
 * année, téléphone facultatif, code parrain facultatif.
 *
 * La création passe par le serveur et non par une insertion directe du
 * client : les colonnes privilégiées de `profiles` sont certes verrouillées
 * par trigger depuis la phase 0, mais le parrainage a besoin du rôle de
 * service — le code parrain désigne un profil dont la RLS ne laisse rien lire.
 */
export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const corps = await request.json().catch(() => null)
  if (corps === null) {
    return Response.json({ ok: false, error: 'Corps de requête illisible.' }, { status: 400 })
  }

  const resultat = await creerProfil(appelant.supabase, appelant.user.id, corps as never)

  if (!resultat.ok) {
    return Response.json(
      { ok: false, error: resultat.error, champ: resultat.champ },
      { status: 400 },
    )
  }

  return Response.json({ ok: true, data: resultat.data })
}
