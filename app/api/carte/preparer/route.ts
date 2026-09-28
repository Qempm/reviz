import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { preparerCarte } from '@/lib/metier/depot-carte'

/**
 * POST /api/carte/preparer
 *
 * Signe une URL d'envoi pour la photo de carte étudiante. Le client dépose
 * ensuite par un simple `PUT`, puis appelle /api/carte/confirmer.
 *
 * Même chemin que les cours et les copies : la photo ne traverse pas la
 * fonction. Ici ce n'est pas une question de poids — une carte tient en
 * 300 ko — mais de ne pas entretenir deux chemins de dépôt.
 */
export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const resultat = await preparerCarte(
    appelant.supabase,
    appelant.user.id,
    (await request.json().catch(() => null)) as never,
  )

  if (!resultat.ok) {
    const messages: Record<typeof resultat.error, string> = {
      invalide: 'Envoie une photo JPEG, PNG ou WebP de moins de 10 Mo.',
      'deja-verifie': 'Ton compte est déjà vérifié.',
      'en-cours': 'On regarde déjà ta carte. Laisse-nous un moment.',
      serveur: 'On n’a pas pu préparer l’envoi. Réessaie dans un instant.',
    }

    const statut =
      resultat.error === 'invalide'
        ? 400
        : resultat.error === 'serveur'
          ? 500
          : // Déjà vérifié ou déjà en cours : la demande est sans objet.
            409

    return Response.json(
      { ok: false, error: messages[resultat.error], motif: resultat.error },
      { status: statut },
    )
  }

  return Response.json({ ok: true, data: resultat })
}
