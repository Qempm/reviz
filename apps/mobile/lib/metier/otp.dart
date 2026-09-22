/// Extraction d'un code à usage unique depuis un texte collé.
///
/// Port de `lib/auth/otp.ts`, **avec deux corrections**.
///
/// La première est une faute. La version TypeScript écrit :
///
/// ```ts
/// const exact = texte.match(new RegExp(`\d{${length}}`))
/// ```
///
/// Dans un littéral de gabarit, `\d` se réduit à `d` : la regex compilée est
/// `/d{6}/`, qui cherche six lettres « d ». La branche « correspondance
/// exacte » ne s'active donc jamais, tout passe par le repli qui recolle les
/// chiffres, et coller « Reviz 2026 : ton code 654321 » renvoie **202665**.
/// Dart a exactement le même piège — je l'ai réintroduit une fois avant de
/// m'en apercevoir, d'où le `r'…'` explicite plus bas.
///
/// La seconde est une hypothèse fausse : **ce projet Supabase émet des codes
/// de huit chiffres**, vérifié sur les types `magiclink` et `signup`. Le web
/// en attend six — son schéma Zod est `/^\d{6}$/` et son champ n'a que six
/// cases — et refuse donc le vrai code. Une règle qui dépend d'une longueur
/// connue d'avance ne tient pas : on prend donc **la plus longue suite de
/// chiffres**, ce qui marche pour six comme pour huit.
library;

/// Longueurs de code plausibles.
const int longueurCodeMin = 6;
const int longueurCodeMax = 10;

/// Le code contenu dans [texte].
///
/// L'étudiant copie rarement le code nu : il sélectionne une ligne entière du
/// mail, « Ton code Reviz : 12345678 ». La règle, dans l'ordre :
///
/// 1. la plus longue suite de chiffres, si elle atteint [longueurCodeMin] —
///    c'est ce qui permet d'ignorer une année ou une heure autour du code,
///    quelle que soit la longueur de celui-ci ;
/// 2. à défaut, tous les chiffres recollés, ce qui rattrape un code recopié
///    avec des espaces ou des tirets ;
/// 3. dans les deux cas, tronqué à [longueur].
String extraireCode(String texte, {int longueur = 6}) {
  // `r'…'` : dans une chaîne Dart non brute, `'\d'` vaut `d`.
  final suites = RegExp(r'\d+').allMatches(texte).map((m) => m.group(0)!);

  var plusLongue = '';
  for (final s in suites) {
    if (s.length > plusLongue.length) plusLongue = s;
  }

  final retenu = plusLongue.length >= longueurCodeMin
      ? plusLongue
      : texte.replaceAll(RegExp(r'\D'), '');

  return retenu.length <= longueur ? retenu : retenu.substring(0, longueur);
}

/// Les chiffres d'une saisie, dans l'ordre, au plus [max].
///
/// Sert au champ de saisie, pendant la frappe : tronquer à une longueur
/// supposée ferait refuser un code parfaitement valide. On garde ce que
/// l'étudiant a tapé et on laisse le serveur trancher.
String chiffresSeulement(String texte, {int max = longueurCodeMax}) {
  final tous = texte.replaceAll(RegExp(r'\D'), '');
  return tous.length <= max ? tous : tous.substring(0, max);
}

/// Le code a-t-il une longueur crédible ?
bool codePlausible(String code) =>
    code.length >= longueurCodeMin &&
    code.length <= longueurCodeMax &&
    RegExp(r'^\d+$').hasMatch(code);
