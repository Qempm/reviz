import { authentifier, refusSession } from '@/lib/supabase/jeton'
import { createAdminClient } from '@/lib/supabase/admin'

/**
 * POST /api/profile/delete
 *
 * Supprime le compte — par anonymisation, parce que la base refuse la
 * suppression. `admin.auth.admin.deleteUser()` échouait pour tout étudiant
 * ayant gagné un point ou effleuré un pack : trois clés étrangères en
 * `on delete restrict` et le trigger `xp_events_no_delete` arrêtent la
 * cascade, y compris pour le rôle de service. L'étudiant n'obtenait qu'un 500
 * opaque, et ses fichiers restaient dans le stockage.
 *
 * Le raisonnement complet est dans
 * `supabase/migrations/20260928110000_anonymiser_compte.sql`.
 *
 * Deux moitiés, dans cet ordre :
 *
 *  1. les **fichiers**, retirés par l'API de stockage — supprimer une ligne
 *     de `storage.objects` en SQL ôterait la référence mais laisserait le
 *     binaire sur S3 ;
 *  2. la **base**, par `anonymiser_compte()`, en une transaction.
 *
 * Si le stockage résiste, on anonymise quand même et on journalise : un
 * compte qu'on ne peut plus supprimer parce qu'un seau a hoqueté serait pire
 * que des fichiers orphelins devenus inatteignables. L'écart est consigné
 * pour être rattrapé.
 */

/** Les seaux qui portent des fichiers rangés par étudiant. */
const SEAUX = ['cours', 'copies', 'cartes'] as const

type Admin = ReturnType<typeof createAdminClient>

/**
 * Chemins des fichiers d'un étudiant dans un seau.
 *
 * Deux niveaux : `list()` ne descend pas tout seul, et nos chemins sont de la
 * forme `<userId>/<id>/<nom>`.
 */
async function cheminsDe(
  admin: Admin,
  seau: string,
  userId: string,
): Promise<string[]> {
  const { data: dossiers, error } = await admin.storage
    .from(seau)
    .list(userId, { limit: 1000 })

  if (error || !dossiers) return []

  const chemins: string[] = []

  for (const entree of dossiers) {
    // Un fichier posé directement à la racine du dossier de l'étudiant.
    if (entree.id !== null) {
      chemins.push(`${userId}/${entree.name}`)
      continue
    }

    const { data: fichiers } = await admin.storage
      .from(seau)
      .list(`${userId}/${entree.name}`, { limit: 1000 })

    for (const fichier of fichiers ?? []) {
      chemins.push(`${userId}/${entree.name}/${fichier.name}`)
    }
  }

  return chemins
}

export async function POST(request: Request) {
  const appelant = await authentifier(request)
  if (!appelant) return refusSession()

  const userId = appelant.user.id
  const admin = createAdminClient()

  let fichiersRetires = 0
  const seauxEnEchec: string[] = []

  for (const seau of SEAUX) {
    try {
      const chemins = await cheminsDe(admin, seau, userId)
      if (chemins.length === 0) continue

      const { error } = await admin.storage.from(seau).remove(chemins)
      if (error) {
        seauxEnEchec.push(seau)
        console.error(`[compte] fichiers non retirés de ${seau}`, error.message)
      } else {
        fichiersRetires += chemins.length
      }
    } catch (e) {
      seauxEnEchec.push(seau)
      console.error(`[compte] parcours de ${seau} impossible`, e)
    }
  }

  const { data: resultat, error } = await admin.rpc('anonymiser_compte', {
    p_user: userId,
  })

  if (error) {
    console.error('[compte] anonymisation refusée', error.message)
    return Response.json(
      {
        ok: false,
        error: 'On n’a pas pu supprimer ton compte. Réessaie dans un instant.',
        motif: 'serveur',
      },
      { status: 500 },
    )
  }

  const issue = (resultat as { resultat?: string } | null)?.resultat

  if (issue === 'inconnu') {
    return Response.json(
      {
        ok: false,
        error: 'On ne retrouve pas ce compte.',
        motif: 'introuvable',
      },
      { status: 404 },
    )
  }

  if (seauxEnEchec.length > 0) {
    // Le compte est bien inutilisable ; seuls des fichiers devenus
    // inatteignables subsistent. À voir dans les journaux.
    console.error('[compte] anonymisé avec des fichiers restants', {
      userId,
      seaux: seauxEnEchec,
    })
  }

  return Response.json({
    ok: true,
    data: {
      anonymise: true,
      dejaFait: issue === 'deja-anonymise',
      fichiersRetires,
    },
  })
}
