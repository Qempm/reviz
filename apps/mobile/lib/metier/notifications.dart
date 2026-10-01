/// Les notifications de l'étudiant : ce qu'elles disent, où elles mènent.
///
/// Les lignes naissent en base, dans des déclencheurs
/// (`supabase/migrations/20261001120000_notifications.sql`), avec une sorte
/// (`kind`) et quelques données. L'application rend leur texte ici, pour le
/// centre de notifications ; le serveur rend **le même** pour le push
/// (`lib/metier/notifications.ts`). Les deux sont vérifiés contre un même
/// fichier de cas, `lib/metier/notifications.cas.json`.
library;

import '../i18n/fr.dart';

enum CategorieNotification { cours, argent, compte, ligue }

const Map<String, CategorieNotification> categories = {
  'cours_pret': CategorieNotification.cours,
  'cours_echoue': CategorieNotification.cours,
  'correction_prete': CategorieNotification.cours,
  'correction_illisible': CategorieNotification.cours,
  'correction_echouee': CategorieNotification.cours,
  'paiement_reussi': CategorieNotification.argent,
  'paiement_echoue': CategorieNotification.argent,
  'commission_recue': CategorieNotification.argent,
  'retrait_paye': CategorieNotification.argent,
  'retrait_refuse': CategorieNotification.argent,
  'carte_verifiee': CategorieNotification.compte,
  'carte_refusee': CategorieNotification.compte,
  'ligue_cloturee': CategorieNotification.ligue,
};

/// Une notification du centre.
class NotificationReviz {
  const NotificationReviz({
    required this.id,
    required this.kind,
    required this.referenceId,
    required this.data,
    required this.lue,
    required this.creeLe,
  });

  final String id;
  final String kind;
  final String? referenceId;
  final Map<String, dynamic> data;
  final bool lue;
  final DateTime creeLe;

  CategorieNotification? get categorie => categories[kind];
  ({String titre, String corps}) get texte => texteDe(kind, data);
  String get lien => lienDe(kind, referenceId);

  NotificationReviz marqueeLue() => NotificationReviz(
    id: id,
    kind: kind,
    referenceId: referenceId,
    data: data,
    lue: true,
    creeLe: creeLe,
  );

  /// Une ligne de `notifications` ; `null` pour une sorte que cette version
  /// de l'application ne connaît pas encore (ajoutée côté serveur depuis).
  static NotificationReviz? depuis(Map<String, dynamic> l) {
    final id = l['id'] as String?;
    final kind = l['kind'] as String?;
    if (id == null || kind == null || !categories.containsKey(kind)) {
      return null;
    }
    final data = l['data'];
    return NotificationReviz(
      id: id,
      kind: kind,
      referenceId: l['reference_id'] as String?,
      data: data is Map ? Map<String, dynamic>.from(data) : const {},
      lue: l['read_at'] != null,
      creeLe:
          DateTime.tryParse(l['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

String? _texte(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : null;

num? _nombre(Object? v) => switch (v) {
  num n => n,
  String s => num.tryParse(s),
  _ => null,
};

/// « 1 500 », « 27,5 » : la façon française, comme le serveur.
String nombreLisible(num n) {
  if (n == n.roundToDouble()) return milliers(n.round());
  final arrondi = (n * 100).round() / 100;
  final entier = arrondi.truncate();
  final decimales = arrondi
      .toString()
      .split('.')
      .last
      .replaceFirst(RegExp(r'0+$'), '');
  return '${milliers(entier)},$decimales';
}

const _packs = {
  'decouverte': 'Découverte',
  'controle': 'Contrôle',
  'partiel': 'Partiel',
  'rattrapage': 'Rattrapage',
  'semestre': 'Semestre',
};

/// Le titre et le corps d'une notification.
({String titre, String corps}) texteDe(String kind, Map<String, dynamic> d) {
  final f = Fr.notifications;
  final titre = _texte(d['titre']);
  final montant = _nombre(d['montant']);
  final montantLisible = montant == null ? null : nombreLisible(montant);

  switch (kind) {
    case 'cours_pret':
      return (titre: f.coursPretTitre, corps: f.coursPretCorps(titre));
    case 'cours_echoue':
      return (titre: f.coursEchoueTitre, corps: f.coursEchoueCorps(titre));
    case 'correction_prete':
      final note = _nombre(d['note']);
      final bareme = _nombre(d['bareme']);
      return (
        titre: f.correctionPreteTitre,
        corps: f.correctionPreteCorps(
          note == null ? null : nombreLisible(note),
          bareme == null ? null : nombreLisible(bareme),
        ),
      );
    case 'correction_illisible':
      return (
        titre: f.correctionIllisibleTitre,
        corps: f.correctionIllisibleCorps,
      );
    case 'correction_echouee':
      return (titre: f.correctionEchoueeTitre, corps: f.correctionEchoueeCorps);
    case 'paiement_reussi':
      return (
        titre: f.paiementReussiTitre,
        corps: f.paiementReussiCorps(_packs[d['pack']]),
      );
    case 'paiement_echoue':
      return (titre: f.paiementEchoueTitre, corps: f.paiementEchoueCorps);
    case 'commission_recue':
      return (
        titre: f.commissionTitre(montantLisible),
        corps: f.commissionCorps,
      );
    case 'retrait_paye':
      return (
        titre: f.retraitPayeTitre,
        corps: f.retraitPayeCorps(montantLisible),
      );
    case 'retrait_refuse':
      return (
        titre: f.retraitRefuseTitre,
        corps: f.retraitRefuseCorps(_texte(d['motif'])),
      );
    case 'carte_verifiee':
      return (titre: f.carteVerifieeTitre, corps: f.carteVerifieeCorps);
    case 'carte_refusee':
      return (titre: f.carteRefuseeTitre, corps: f.carteRefuseeCorps);
    case 'ligue_cloturee':
      final division = (_nombre(d['division'])?.toInt() ?? 1).clamp(1, 6);
      final nom = Fr.ligue.nom(division);
      final rang = _nombre(d['rang'])?.toInt();
      return switch (d['issue']) {
        'monte' => (
          titre: f.ligueMonteTitre(nom),
          corps: f.ligueMonteCorps(rang),
        ),
        'descend' => (
          titre: f.ligueDescendTitre(nom),
          corps: f.ligueDescendCorps,
        ),
        _ => (titre: f.ligueResteTitre(nom), corps: f.ligueResteCorps),
      };
    default:
      return (titre: f.titre, corps: '');
  }
}

/// L'écran que la notification ouvre (`routage.dart`).
String lienDe(String kind, String? ref) => switch (kind) {
  'cours_pret' => ref == null ? '/reviser' : '/cours/$ref',
  'cours_echoue' => '/reviser',
  'correction_prete' ||
  'correction_illisible' ||
  'correction_echouee' => ref == null ? '/corriger' : '/corrections/$ref',
  'paiement_reussi' => '/',
  'paiement_echoue' => '/boutique',
  'commission_recue' || 'retrait_paye' || 'retrait_refuse' => '/gains',
  'carte_verifiee' || 'carte_refusee' => '/profil/carte-etudiante',
  'ligue_cloturee' => '/ligue',
  _ => '/',
};

final _cheminsConnus = [
  RegExp(r'^/$'),
  RegExp(r'^/reviser$'),
  RegExp(r'^/corriger$'),
  RegExp(r'^/gains$'),
  RegExp(r'^/ligue$'),
  RegExp(r'^/boutique$'),
  RegExp(r'^/profil/carte-etudiante$'),
  RegExp(r'^/notifications$'),
  RegExp(r'^/cours/[A-Za-z0-9-]{1,64}$'),
  RegExp(r'^/corrections/[A-Za-z0-9-]{1,64}$'),
];

/// Le lien d'une notification touchée, s'il mène à un écran connu ; sinon
/// l'accueil. Un push vient du réseau : on ne suit pas n'importe quel
/// chemin qu'il contiendrait.
String cheminDe(String? lien) {
  if (lien == null) return '/';
  return _cheminsConnus.any((r) => r.hasMatch(lien)) ? lien : '/';
}

/// Les catégories de push que l'étudiant veut recevoir. Une catégorie
/// absente vaut « oui », comme côté serveur (`pushAutorise`).
class PrefsPush {
  const PrefsPush({
    this.cours = true,
    this.argent = true,
    this.compte = true,
    this.ligue = true,
  });

  final bool cours;
  final bool argent;
  final bool compte;
  final bool ligue;

  bool pour(CategorieNotification c) => switch (c) {
    CategorieNotification.cours => cours,
    CategorieNotification.argent => argent,
    CategorieNotification.compte => compte,
    CategorieNotification.ligue => ligue,
  };

  PrefsPush avec(CategorieNotification c, bool oui) => PrefsPush(
    cours: c == CategorieNotification.cours ? oui : cours,
    argent: c == CategorieNotification.argent ? oui : argent,
    compte: c == CategorieNotification.compte ? oui : compte,
    ligue: c == CategorieNotification.ligue ? oui : ligue,
  );

  Map<String, bool> versJson() => {
    'cours': cours,
    'argent': argent,
    'compte': compte,
    'ligue': ligue,
  };

  static PrefsPush depuis(Object? v) {
    if (v is! Map) return const PrefsPush();
    bool lire(String cle) => v[cle] != false;
    return PrefsPush(
      cours: lire('cours'),
      argent: lire('argent'),
      compte: lire('compte'),
      ligue: lire('ligue'),
    );
  }
}
