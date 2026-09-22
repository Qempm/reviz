import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { preparerDepot } from '@/lib/metier/cours'

/**
 * POST /api/cours/preparer
 *
 * Vérifie les droits, crée la ligne `courses` et signe une URL d'envoi. Le
 * client y dépose ensuite le fichier par un simple PUT, puis appelle
 * /api/cours/confirmer. Le fichier ne passe jamais par ici : 25 Mo
 * dépasseraient la limite de charge utile d'une fonction serverless.
 *
 * Même logique que la Server Action de l'écran web — `lib/metier/cours.ts`.
 */
export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  let corps: unknown
  try {
    corps = await request.json()
  } catch {
    return Response.json({ ok: false, error: 'Corps de requête illisible.' }, { status: 400 })
  }

  const resultat = await preparerDepot(appelant.supabase, appelant.user.id, corps as never)

  if (!resultat.ok) {
    // Le refus porte un motif que le client sait traduire ; le statut dit
    // seulement de quel genre de refus il s'agit.
    const statut =
      resultat.error === 'invalide'
        ? 400
        : resultat.error === 'serveur'
          ? 500
          : resultat.error === 'deja-depose'
            ? 409
            : 402 // droits d'accès insuffisants : pack absent, expiré, plafond
    // `resultat` porte déjà `ok: false` : on le renvoie tel quel plutôt que
    // de le réécrire, pour que `courseId` et `plafond` parviennent au client.
    return Response.json(resultat, { status: statut })
  }

  return Response.json({ ok: true, data: resultat })
}
