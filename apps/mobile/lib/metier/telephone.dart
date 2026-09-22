/// Numéros de téléphone d'Afrique de l'Ouest francophone.
///
/// Port de `lib/auth/phone.ts`. Reviz vise le Bénin, le Togo, la Côte
/// d'Ivoire, le Sénégal et le Burkina. L'étudiant saisit son numéro comme il
/// le dit à l'oral — « 97 12 34 56 » — et non au format international. C'est à
/// nous de normaliser, pas à lui d'apprendre le E.164.
///
/// La normalisation doit donner **exactement** le même résultat que la version
/// TypeScript : elle sert à l'affichage côté client et à l'unicité côté
/// serveur.
library;

class Pays {
  const Pays({
    required this.code,
    required this.indicatif,
    required this.nom,
    required this.longueurs,
    required this.exemple,
    required this.emoji,
  });

  final String code;

  /// Indicatif international, sans le `+`.
  final String indicatif;
  final String nom;

  /// Longueurs admises pour le numéro national, sans indicatif.
  final List<int> longueurs;

  /// Exemple affiché en aide de saisie.
  final String exemple;
  final String emoji;
}

/// Le Bénin, marché de départ — extrait en constante nommée pour pouvoir
/// servir de valeur par défaut de paramètre, ce qu'un `pays[0]` ne peut pas
/// faire : indexer une liste n'est pas une expression constante en Dart.
const Pays paysParDefaut = Pays(
  code: 'BJ',
  indicatif: '229',
  nom: 'Bénin',
  longueurs: [8, 10],
  exemple: '97 12 34 56',
  emoji: '🇧🇯',
);

/// Ordre d'affichage : le Bénin d'abord.
const List<Pays> pays = [
  paysParDefaut,
  Pays(
    code: 'TG',
    indicatif: '228',
    nom: 'Togo',
    longueurs: [8],
    exemple: '90 12 34 56',
    emoji: '🇹🇬',
  ),
  Pays(
    code: 'CI',
    indicatif: '225',
    nom: "Côte d'Ivoire",
    longueurs: [10],
    exemple: '07 12 34 56 78',
    emoji: '🇨🇮',
  ),
  Pays(
    code: 'SN',
    indicatif: '221',
    nom: 'Sénégal',
    longueurs: [9],
    exemple: '77 123 45 67',
    emoji: '🇸🇳',
  ),
  Pays(
    code: 'BF',
    indicatif: '226',
    nom: 'Burkina Faso',
    longueurs: [8],
    exemple: '70 12 34 56',
    emoji: '🇧🇫',
  ),
];

Pays? paysParCode(String code) {
  for (final p in pays) {
    if (p.code == code) return p;
  }
  return null;
}

Pays? paysParIndicatif(String indicatif) {
  for (final p in pays) {
    if (p.indicatif == indicatif) return p;
  }
  return null;
}

/// Ne garde que les chiffres.
String _chiffres(String saisie) => saisie.replaceAll(RegExp(r'\D'), '');

enum RaisonRefusNumero { vide, paysInconnu, longueur }

sealed class ResultatNormalisation {
  const ResultatNormalisation();
}

class NumeroNormalise extends ResultatNormalisation {
  const NumeroNormalise({
    required this.e164,
    required this.pays,
    required this.national,
  });

  final String e164;
  final Pays pays;
  final String national;
}

class NumeroRefuse extends ResultatNormalisation {
  const NumeroRefuse(this.raison);
  final RaisonRefusNumero raison;
}

/// Met un numéro au format E.164 (`+22997123456`), celui qu'attend Supabase.
///
/// Accepte les formes réellement tapées par les étudiants : avec espaces,
/// tirets ou points, avec ou sans indicatif, avec `+`, avec `00`, ou avec un
/// zéro initial hérité des habitudes françaises.
ResultatNormalisation normaliserTelephone(
  String saisie, [
  Pays defaut = paysParDefaut,
]) {
  var n = _chiffres(saisie);
  if (n.isEmpty) return const NumeroRefuse(RaisonRefusNumero.vide);

  // `00229…` est la forme composée depuis un fixe.
  if (n.startsWith('00')) n = n.substring(2);

  // Le numéro porte-t-il déjà un indicatif connu ?
  for (final p in pays) {
    if (!n.startsWith(p.indicatif)) continue;

    final national = n.substring(p.indicatif.length);
    if (!p.longueurs.contains(national.length)) {
      return const NumeroRefuse(RaisonRefusNumero.longueur);
    }
    return NumeroNormalise(
      e164: '+${p.indicatif}$national',
      pays: p,
      national: national,
    );
  }

  // Sinon on applique le pays choisi dans l'interface. Un zéro initial est un
  // réflexe hérité : on le retire s'il rend la longueur valide, sans le
  // retirer aveuglément.
  var national = n;
  if (national.startsWith('0') &&
      !defaut.longueurs.contains(national.length) &&
      defaut.longueurs.contains(national.length - 1)) {
    national = national.substring(1);
  }

  if (!defaut.longueurs.contains(national.length)) {
    return const NumeroRefuse(RaisonRefusNumero.longueur);
  }

  return NumeroNormalise(
    e164: '+${defaut.indicatif}$national',
    pays: defaut,
    national: national,
  );
}

/// Découpe un numéro national pour l'affichage, selon l'usage de chaque pays.
///
/// Le découpage doit correspondre à [Pays.exemple] : un formatage qui
/// s'écarterait de l'aide à la saisie affichée juste au-dessus ferait douter
/// l'étudiant de ce qu'il a tapé.
String formaterNational(String national, Pays p) {
  final n = _chiffres(national);
  if (n.isEmpty) return '';

  // Sénégal : 9 chiffres en 2-3-2-2, soit « 77 123 45 67 ».
  if (p.code == 'SN') {
    final bornes = [
      [0, 2],
      [2, 5],
      [5, 7],
      [7, 9],
    ];
    return bornes
        .map((b) => n.substring(
              b[0] > n.length ? n.length : b[0],
              b[1] > n.length ? n.length : b[1],
            ))
        .where((g) => g.isNotEmpty)
        .join(' ');
  }

  // Partout ailleurs : groupes de deux.
  final groupes = <String>[];
  for (var i = 0; i < n.length; i += 2) {
    groupes.add(n.substring(i, i + 2 > n.length ? n.length : i + 2));
  }
  return groupes.join(' ');
}

/// Masque un numéro pour l'affichage : `+229 97 •• •• 56`.
String masquerTelephone(String e164) {
  for (final p in pays) {
    if (!e164.startsWith('+${p.indicatif}')) continue;

    final national = e164.substring(p.indicatif.length + 1);
    if (national.length < 4) return e164;

    final debut = national.substring(0, 2);
    final fin = national.substring(national.length - 2);
    final milieu = '•' * (national.length - 4);

    return '+${p.indicatif} $debut $milieu $fin'.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }
  return e164;
}
