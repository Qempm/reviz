/**
 * Écoles, filières et matières saisies par les étudiants.
 *
 * Le catalogue d'origine tenait en une migration : trois universités, quinze
 * filières, quatre matières par filière. Hors de ces listes, on ne pouvait
 * ni s'inscrire, ni déposer un cours. L'étudiant tape désormais ce qui
 * manque, et ce qu'il tape devient une vraie ligne — pour que le classement,
 * le partage entre camarades et le cache des cours marchent aussi pour lui.
 *
 * Le piège est le doublon : « FSEG », « fseg », « F.S.E.G » et « F S E G »
 * doivent être la même filière, sinon deux camarades de promotion ne se
 * verraient jamais. D'où `normaliserNom`, qui ne garde que les lettres et
 * les chiffres, sans accents ni casse, et à laquelle on compare tout ajout.
 *
 * Porté en Dart (`apps/mobile/lib/metier/referentiel.dart`) pour que la
 * recherche de l'écran trouve ce que le serveur jugera identique.
 */

/** Ce qui rend deux noms « le même » : lettres et chiffres, sans accents. */
export function normaliserNom(nom: string): string {
  return nom
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ')
    // « F S E G » et « FSEG » : une suite de lettres isolées est un sigle.
    .replace(/\b([a-z0-9])(?: (?=[a-z0-9]\b))/g, '$1')
}

/** Le nom tel qu'on le range : espaces resserrés, sans bords. */
export function nettoyerNom(nom: string): string {
  return nom.trim().replace(/\s+/g, ' ')
}

/** Un nom acceptable : 2 à 80 caractères, dont au moins deux lettres. */
export function nomValide(nom: string): boolean {
  const n = nettoyerNom(nom)
  if (n.length < 2 || n.length > 80) return false
  return (normaliserNom(n).match(/[a-z]/g) ?? []).length >= 2
}

/**
 * Un code court pour les tables qui en exigent un (`universities.code`,
 * `faculties.code`) : le sigle si le nom en est un, sinon les initiales des
 * mots significatifs. « Université d'Abomey-Calavi » → « UAC ».
 */
export function codeDepuisNom(nom: string): string {
  const n = normaliserNom(nom)
  const mots = n.split(' ').filter((m) => m.length > 0)
  if (mots.length === 1) return mots[0].slice(0, 12).toUpperCase()
  const vides = new Set(['de', 'des', 'du', 'la', 'le', 'les', 'et', 'd', 'l', 'en', 'a', 'au', 'aux'])
  const initiales = mots
    .filter((m) => !vides.has(m))
    .map((m) => m[0])
    .join('')
  return (initiales || mots.map((m) => m[0]).join('')).slice(0, 12).toUpperCase()
}

/**
 * Le sigle rangé en fin de nom, entre parenthèses : « Université Cheikh Anta
 * Diop de Dakar (UCAD) » → « ucad ». `null` sans parenthèses.
 *
 * Le catalogue écrit les écoles et les filières ainsi depuis le 7 octobre
 * 2026 : l'étudiant tape « UCAD » ou « FASEG », pas le nom officiel.
 */
export function sigleDe(nom: string): string | null {
  const m = /\(([^()]+)\)\s*$/.exec(nom)
  if (!m) return null
  const sigle = normaliserNom(m[1])
  return sigle.length > 0 ? sigle : null
}

/**
 * La saisie désigne-t-elle ce nom rangé ? Le nom entier, le nom sans son
 * sigle, ou le sigle seul : « UCAD », « Université Cheikh Anta Diop de
 * Dakar » et « Université Cheikh Anta Diop de Dakar (UCAD) » sont la même
 * école.
 */
export function memeNom(saisie: string, range: string): boolean {
  const cible = normaliserNom(saisie)
  if (cible.length === 0) return false
  if (normaliserNom(range) === cible) return true
  const sigle = sigleDe(range)
  if (sigle === null) return false
  return sigle === cible || normaliserNom(range.replace(/\([^()]+\)\s*$/, '')) === cible
}

/** Le premier élément dont le nom est « le même » que `nom`, ou `null`. */
export function trouverParNom<T extends { name: string }>(
  lignes: T[],
  nom: string,
): T | null {
  return lignes.find((l) => memeNom(nom, l.name)) ?? null
}
