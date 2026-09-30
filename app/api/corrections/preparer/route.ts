import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { preparerCorrection } from '@/lib/metier/corrections'

/**
 * POST /api/corrections/preparer
 *
 * Vérifie les droits, réserve la ligne `corrections` et signe une URL d'envoi
 * par fichier. Le client dépose ensuite les photos par un simple PUT, puis
 * appelle /api/corrections/confirmer.
 *
 * La photo ne passe jamais par ici : une copie de téléphone récent pèse 3 à
 * 8 Mo, et la charge utile d'une fonction serverless est plafonnée à 4,5 Mo
 * chez Vercel. C'est le chemin qu'avait déjà pris le dépôt de cours.
 *
 * La ligne est réservée **avant** l'envoi, pour que le plafond de cinq
 * corrections par jour tranche en 200 ms au lieu d'après quarante secondes
 * d'envoi sur une 3G.
 */
export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  let corps: unknown
  try {
    corps = await request.json()
  } catch {
    return Response.json(
      { ok: false, error: 'Ta demande n’a pas pu partir. Réessaie.', motif: 'invalide' },
      { status: 400 },
    )
  }

  const resultat = await preparerCorrection(
    appelant.supabase,
    appelant.user.id,
    corps as never,
  )

  if (!resultat.ok) {
    // Quatre refus distincts, quatre phrases : l'écran web affichait
    // `insufficient_balance` et consorts tels quels à l'étudiant.
    const messages: Record<typeof resultat.error, string> = {
      invalide: 'Vérifie le format et la taille de la photo.',
      serveur: 'On n’a pas pu préparer la correction. Réessaie dans un instant.',
      aucun_pack: 'Il te faut un pack actif pour faire corriger une copie.',
      pack_expire: 'Ton pack est arrivé à terme. Réactive-le pour continuer.',
      credit_epuise: 'Tu n’as plus de correction dans ton pack.',
      plafond_journalier:
        'Tu as atteint les 5 corrections du jour. Reviens demain.',
    }

    const statut =
      resultat.error === 'invalide'
        ? 400
        : resultat.error === 'serveur'
          ? 500
          : // Droits insuffisants : pack absent, expiré, crédit ou plafond.
            402

    return Response.json(
      {
        ok: false,
        error: messages[resultat.error],
        motif: resultat.error,
        restantes: resultat.restantes,
      },
      { status: statut },
    )
  }

  return Response.json({ ok: true, data: resultat })
}
