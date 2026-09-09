/**
 * Extraction d'un code à usage unique depuis un texte collé.
 *
 * Logique pure, tenue hors du composant pour être testable : l'interface
 * n'est pas testée au MVP, cette règle-là doit l'être.
 */

/**
 * L'étudiant copie rarement six chiffres nus : il sélectionne une ligne
 * entière du mail, « Ton code Reviz : 123456 ». On prend la première suite de
 * chiffres de la bonne longueur ; à défaut, tous les chiffres trouvés, ce qui
 * rattrape les codes recopiés avec des espaces.
 */
export function extraireCode(texte: string, length = 6): string {
  const exact = texte.match(new RegExp(`\d{${length}}`))
  if (exact) return exact[0]
  return texte.replace(/\D/g, '').slice(0, length)
}
