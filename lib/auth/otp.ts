/**
 * Extraction d'un code à usage unique depuis un texte collé.
 *
 * Logique pure, tenue hors du composant pour être testable : l'interface
 * n'est pas testée au MVP, cette règle-là doit l'être.
 */

/**
 * L'étudiant copie rarement le code nu : il sélectionne une ligne entière du
 * mail, « Ton code Reviz : 12345678 ». On prend la plus longue suite de
 * chiffres dès qu'elle atteint six — ce qui écarte une année ou une heure
 * autour du code — et à défaut tous les chiffres recollés, ce qui rattrape un
 * code recopié avec des espaces.
 */
export function extraireCode(texte: string, length = 8): string {
  // La plus longue suite de chiffres, et non « la première de longueur N » :
  // la longueur du code dépend de la configuration Supabase — ce projet en
  // émet **huit**, un autre en émettrait six. Et la version précédente
  // écrivait `new RegExp(`\d{${length}}`)`, où le `\d` d'un littéral de
  // gabarit se réduit à `d` : la regex compilée était `/d{6}/`, qui cherche
  // six lettres « d ». Rien ne passait donc par cette branche, et coller
  // « Reviz 2026 : ton code 654321 » renvoyait 202665.
  const suites = texte.match(/\d+/g) ?? []
  const plusLongue = suites.reduce((a, b) => (b.length > a.length ? b : a), '')

  const retenu =
    plusLongue.length >= 6 ? plusLongue : texte.replace(/\D/g, '')

  return retenu.slice(0, length)
}
