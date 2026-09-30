/**
 * La maîtrise d'un chapitre : de « à découvrir » à trois couronnes.
 *
 * Port de `apps/mobile/lib/metier/maitrise.dart` — l'écran dessine le chemin
 * sans aller-retour, le serveur reste l'autorité (classements, ligues).
 * Mêmes cas de test des deux côtés.
 *
 * Sur les seuls QCM et la dernière réponse à chacun :
 *  - pas tous tentés : « à découvrir », ou « à revoir » si la moitié est
 *    tentée et moins de la moitié juste ;
 *  - tous tentés : 1 couronne à 50 % de justes, 2 à 80 %, 3 à 100 % et
 *    chaque question juste deux jours différents ;
 *  - une couronne se perd si la dernière réponse devient fausse.
 */

export type EtatChapitre =
  | 'verrouille'
  | 'a_decouvrir'
  | 'a_revoir'
  | 'couronne'
  | 'sans_qcm'

export interface Tentative {
  questionId: string
  juste: boolean
  le: Date
}

export interface Maitrise {
  etat: EtatChapitre
  couronnes: 0 | 1 | 2 | 3
  total: number
  tentees: number
  justes: number
}

/** Le jour calendaire en UTC : le même pour le serveur et le téléphone. */
function jour(d: Date): string {
  return d.toISOString().slice(0, 10)
}

export function maitriseChapitre(
  qcm: readonly string[],
  tentatives: readonly Tentative[],
): Maitrise {
  const total = qcm.length
  if (total === 0) {
    return { etat: 'sans_qcm', couronnes: 0, total: 0, tentees: 0, justes: 0 }
  }

  const ids = new Set(qcm)
  const derniere = new Map<string, Tentative>()
  const joursJustes = new Map<string, Set<string>>()
  for (const t of tentatives) {
    if (!ids.has(t.questionId)) continue
    const d = derniere.get(t.questionId)
    if (!d || t.le.getTime() > d.le.getTime()) derniere.set(t.questionId, t)
    if (t.juste) {
      const jours = joursJustes.get(t.questionId) ?? new Set<string>()
      jours.add(jour(t.le))
      joursJustes.set(t.questionId, jours)
    }
  }

  const tentees = derniere.size
  const justes = [...derniere.values()].filter((t) => t.juste).length
  const avec = (etat: EtatChapitre, couronnes: 0 | 1 | 2 | 3 = 0): Maitrise => ({
    etat,
    couronnes,
    total,
    tentees,
    justes,
  })

  if (tentees < total) {
    const aRevoir = tentees * 2 >= total && justes * 2 < tentees
    return avec(aRevoir ? 'a_revoir' : 'a_decouvrir')
  }

  if (justes * 2 < total) return avec('a_revoir')
  if (justes === total && qcm.every((id) => (joursJustes.get(id)?.size ?? 0) >= 2)) {
    return avec('couronne', 3)
  }
  if (justes * 5 >= total * 4) return avec('couronne', 2)
  return avec('couronne', 1)
}

/**
 * Le chemin d'un cours : chaque chapitre s'ouvre quand le précédent a au
 * moins une couronne ; le premier est toujours ouvert, un chapitre sans QCM
 * ne bloque pas la suite, et un chapitre déjà commencé ne se referme jamais.
 */
export function cheminDuCours(chapitres: readonly Maitrise[]): Maitrise[] {
  let precedentCouronne = true
  return chapitres.map((m) => {
    if (m.etat === 'sans_qcm') return m
    const ouvert = precedentCouronne || m.tentees > 0
    precedentCouronne = m.couronnes >= 1
    return ouvert ? m : { ...m, etat: 'verrouille', couronnes: 0 }
  })
}
