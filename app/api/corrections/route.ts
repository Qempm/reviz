import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { deposerCorrection } from '@/lib/metier/corrections'

/**
 * POST /api/corrections
 *
 * Dépôt d'une copie à corriger. Corps en `multipart/form-data` :
 * `copie` (obligatoire) et `sujet` (facultatif).
 *
 * ATTENTION — les fichiers traversent cette fonction, dont la charge utile
 * est plafonnée à 4,5 Mo sur Vercel, alors que le bucket `copies` accepte
 * 10 Mo par image. Deux photos prises avec un téléphone récent ne passeront
 * pas. Le dépôt de cours a résolu cela par une URL signée et un PUT direct
 * vers le stockage ; la correction devra suivre le même chemin. La route
 * existe pour que le parcours soit appelable dès maintenant, pas pour rester
 * sous cette forme.
 */

/** Deux images de 4 Mo passent ; c'est la marge que laisse la plateforme. */
const TAILLE_MAX_CHAMP = 4 * 1024 * 1024

const TYPES = ['image/jpeg', 'image/png', 'image/webp']

export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  let formulaire: FormData
  try {
    formulaire = await request.formData()
  } catch {
    return Response.json(
      { ok: false, error: 'Envoie la copie en multipart/form-data.' },
      { status: 400 },
    )
  }

  const copie = formulaire.get('copie')
  const sujet = formulaire.get('sujet')

  if (!(copie instanceof File)) {
    return Response.json(
      { ok: false, error: 'Le champ « copie » est obligatoire.' },
      { status: 400 },
    )
  }

  for (const [nom, fichier] of [
    ['copie', copie],
    ['sujet', sujet],
  ] as const) {
    if (!(fichier instanceof File)) continue

    if (!TYPES.includes(fichier.type)) {
      return Response.json(
        { ok: false, error: `Le champ « ${nom} » doit être une image JPEG, PNG ou WebP.` },
        { status: 415 },
      )
    }
    if (fichier.size > TAILLE_MAX_CHAMP) {
      return Response.json(
        { ok: false, error: `L’image « ${nom} » dépasse 4 Mo. Réduis-la et réessaie.` },
        { status: 413 },
      )
    }
  }

  const resultat = await deposerCorrection(
    appelant.supabase,
    appelant.user.id,
    copie,
    sujet instanceof File ? sujet : undefined,
  )

  if (!resultat.ok) {
    const messages = {
      session: 'Ta session a expiré. Reconnecte-toi.',
      pack: 'Il te faut un pack avec des corrections disponibles.',
      storage: 'On n’a pas pu enregistrer ta copie. Réessaie.',
      serveur: 'Quelque chose a coincé de notre côté. Réessaie.',
    }
    const statut =
      resultat.error === 'session' ? 401 : resultat.error === 'pack' ? 402 : 500

    return Response.json(
      { ok: false, error: messages[resultat.error], motif: resultat.error },
      { status: statut },
    )
  }

  return Response.json({ ok: true, data: { correctionId: resultat.correctionId } })
}
