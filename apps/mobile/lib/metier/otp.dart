/// Extraction d'un code à usage unique depuis un texte collé.
///
/// Port de `lib/auth/otp.ts`, **avec sa faute corrigée**. La version
/// TypeScript écrit :
///
/// ```ts
/// const exact = texte.match(new RegExp(`\d{${length}}`))
/// ```
///
/// Dans un littéral de gabarit, `\d` se réduit à `d` : la regex compilée est
/// `/d{6}/`, qui cherche six lettres « d ». La branche « correspondance
/// exacte » ne s'active donc jamais, tout passe par le repli, et coller
/// « Reviz 2026 : ton code 654321 » renvoie **202665**. Les huit tests
/// passaient parce qu'aucune de leurs fixtures n'avait de chiffre avant le
/// code.
///
/// Ici la première suite de chiffres de la bonne longueur est bien cherchée
/// d'abord.
library;

/// L'étudiant copie rarement six chiffres nus : il sélectionne une ligne
/// entière du mail, « Ton code Reviz : 123456 ». On prend la première suite de
/// chiffres de la bonne longueur ; à défaut, tous les chiffres trouvés, ce qui
/// rattrape les codes recopiés avec des espaces.
String extraireCode(String texte, {int longueur = 6}) {
  // `r'…'` plus concaténation : dans une chaîne Dart non brute, `'\d'` vaut
  // `d` — exactement le piège qui a produit `/d{6}/` côté TypeScript.
  final exact = RegExp('${r'\d'}{$longueur}').firstMatch(texte);
  if (exact != null) return exact.group(0)!;

  final tous = texte.replaceAll(RegExp(r'\D'), '');
  return tous.length <= longueur ? tous : tous.substring(0, longueur);
}
