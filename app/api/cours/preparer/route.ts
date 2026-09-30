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
    return Response.json({ ok: false, error: 'Ton cours n’a pas pu partir. Réessaie.' }, { status: 400 })
  }

  const resultat = await preparerDepot(appelant.supabase, appelant.user.id, corps as never)

  if (!resultat.ok) {
    // Le refus porte un motif que le client sait traduire ; le statut dit
    // seulement de quel genre de refus il s'agit.
    //
    // Le code allait dans `error`, et l'application l'affichait tel quel :
    // l'étudiant lisait « aucun-acces » dans un encadré rouge, sans bouton,
    // au moment précis où il fallait lui proposer un pack. Il part
    // maintenant dans `motif`, et `error` porte une phrase.
    const { error: motif, ...reste } = resultat
    const statut =
      resultat.error === 'invalide'
        ? 400
        : resultat.error === 'serveur'
          ? 500
          : resultat.error === 'deja-depose'
            ? 409
            : 402 // droits d'accès insuffisants : pack absent, expiré, plafond
    // `courseId` et `plafond` suivent, pour que l'écran propose la suite.
    return Response.json(
      { ...reste, ok: false, motif, error: messageRefus(motif, resultat) },
      { status: statut },
    )
  }

  return Response.json({ ok: true, data: resultat })
}

/** Ce que l'étudiant lit, pour chaque refus. Tutoiement, pas de jargon. */
function messageRefus(motif: string, r: { plafond?: number }): string {
  switch (motif) {
    case 'aucun-acces':
      return 'Pour ajouter un cours, il te faut un pack. Le premier est gratuit.'
    case 'acces-expire':
      return 'Ton pack est terminé. Reprends-en un pour ajouter ce cours.'
    case 'deja-depose':
      return 'Tu as déjà ajouté ce cours.'
    case 'plafond-matieres':
      return r.plafond
        ? `Ton pack couvre ${r.plafond} matière${r.plafond > 1 ? 's' : ''}. Passe à un pack plus grand pour en ajouter.`
        : 'Ton pack ne couvre pas une matière de plus.'
    case 'invalide':
      return 'Il manque une information sur ce cours. Vérifie le titre et la matière.'
    default:
      return 'Ton cours n’a pas pu partir. Réessaie dans un instant.'
  }
}
