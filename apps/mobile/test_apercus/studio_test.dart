// Studio : chaque écran de Reviz en haute définition, pour une vidéo.
//
//   flutter test test_apercus/studio_test.dart --update-goldens
//
// Format téléphone 390 × 844 points rendu à ×3, soit **1170 × 2532 px**
// (iPhone 13/14, et l'ordre de grandeur d'un Android milieu de gamme), avec
// une barre d'état et l'indicateur d'accueil : les images se posent telles
// quelles dans un cadre de téléphone. Les écrans qui défilent ont en plus une
// version longue (`-long`), pour un mouvement de défilement au montage.
//
// Les données sont factices mais vraisemblables : une étudiante en L2 de
// droit à l'UAC, Awa. Les images sortent dans `test_apercus/studio/`,
// ignoré par git.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:reviz/composants/bandeau.dart';
import 'package:reviz/composants/coquille.dart';
import 'package:reviz/donnees/api.dart';
import 'package:reviz/donnees/depots.dart';
import 'package:reviz/donnees/modeles.dart';
import 'package:reviz/donnees/rappels.dart';
import 'package:reviz/donnees/version.dart';
import 'package:reviz/ecrans/accueil.dart';
import 'package:reviz/ecrans/aide.dart';
import 'package:reviz/ecrans/ajouter_cours.dart';
import 'package:reviz/ecrans/avatar.dart';
import 'package:reviz/ecrans/boutique.dart';
import 'package:reviz/ecrans/carte.dart';
import 'package:reviz/ecrans/classement.dart';
import 'package:reviz/ecrans/connexion.dart';
import 'package:reviz/ecrans/correction.dart';
import 'package:reviz/ecrans/corriger.dart';
import 'package:reviz/ecrans/cours.dart';
import 'package:reviz/ecrans/fiches.dart';
import 'package:reviz/ecrans/gains.dart';
import 'package:reviz/ecrans/inscription.dart';
import 'package:reviz/ecrans/ligue.dart';
import 'package:reviz/ecrans/mise_a_jour.dart';
import 'package:reviz/ecrans/notifications.dart';
import 'package:reviz/ecrans/notifications_reglages.dart';
import 'package:reviz/ecrans/paiement.dart';
import 'package:reviz/ecrans/payer.dart';
import 'package:reviz/ecrans/profil.dart';
import 'package:reviz/ecrans/reviser.dart';
import 'package:reviz/ecrans/session.dart';
import 'package:reviz/etat/fournisseurs.dart';
import 'package:reviz/metier/acces.dart';
import 'package:reviz/metier/maitrise.dart';
import 'package:reviz/metier/notifications.dart';
import 'package:reviz/metier/rappels.dart';
import 'package:reviz/metier/selection.dart';
import 'package:reviz/metier/version.dart';
import 'package:reviz/theme/jetons.dart';
import 'package:reviz/theme/theme.dart';

// ------------------------------------------------------------------ Polices

const _policeIcones =
    'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf';

Future<void> _chargerPolices() async {
  final nunito = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/polices/NunitoSans.ttf'));
  await nunito.load();
  final fichier = File(_policeIcones);
  if (fichier.existsSync()) {
    final icones = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(fichier.readAsBytesSync())));
    await icones.load();
  }
}

// ----------------------------------------------------------------- Données

String _jour(int decalage) {
  final d = DateTime.now().toUtc().add(Duration(days: decalage));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

Profil _profil({int xp = 1280, String statut = 'verified'}) => Profil(
  id: 'u1',
  prenom: 'Awa',
  xpTotal: xp,
  serieCourante: 6,
  dernierJourValide: _jour(-1),
  faculteId: 'f1',
  universiteNom: 'UAC',
  faculteNom: 'FADESP',
  codeParrain: 'AWA225',
  avatar: 'ton-01',
  statutVerification: statut,
  anneeEtude: 2,
);

const _semaine = [
  JourSerie(
    jourSemaine: 1,
    questions: 14,
    xp: 140,
    valide: true,
    aujourdhui: false,
  ),
  JourSerie(
    jourSemaine: 2,
    questions: 12,
    xp: 120,
    valide: true,
    aujourdhui: false,
  ),
  JourSerie(
    jourSemaine: 3,
    questions: 18,
    xp: 180,
    valide: true,
    aujourdhui: false,
  ),
  JourSerie(
    jourSemaine: 4,
    questions: 10,
    xp: 100,
    valide: true,
    aujourdhui: false,
  ),
  JourSerie(
    jourSemaine: 5,
    questions: 7,
    xp: 70,
    valide: false,
    aujourdhui: true,
  ),
  JourSerie(
    jourSemaine: 6,
    questions: 0,
    xp: 0,
    valide: false,
    aujourdhui: false,
  ),
  JourSerie(
    jourSemaine: 7,
    questions: 0,
    xp: 0,
    valide: false,
    aujourdhui: false,
  ),
];

const _matieres = [
  StatMatiere(
    matiereId: 'm1',
    matiereNom: 'Droit constitutionnel',
    questionsFaites: 48,
    scoreMoyen: 0.78,
    aRevoir: false,
  ),
  StatMatiere(
    matiereId: 'm2',
    matiereNom: 'Introduction à l’étude du droit',
    questionsFaites: 26,
    scoreMoyen: 0.42,
    aRevoir: true,
  ),
  StatMatiere(
    matiereId: 'm3',
    matiereNom: 'Économie politique',
    questionsFaites: 31,
    scoreMoyen: 0.84,
    aRevoir: false,
  ),
];

final _cours = [
  const ApercuCours(
    id: 'c1',
    titre: 'Droit constitutionnel — la Constitution du 11 décembre 1990',
    statut: 'ready',
    demo: false,
    matiereNom: 'Droit constitutionnel',
    dateExamen: null,
    nbChapitres: 7,
    nbQuestions: 42,
    nbFiches: 28,
    nbTentees: 24,
  ),
  const ApercuCours(
    id: 'c2',
    titre: 'Économie politique — chapitres 1 à 4',
    statut: 'ready',
    demo: false,
    matiereNom: 'Économie politique',
    dateExamen: null,
    nbChapitres: 4,
    nbQuestions: 24,
    nbFiches: 16,
    nbTentees: 13,
  ),
  ApercuCours(
    id: 'c4',
    titre: 'Droit des obligations',
    statut: 'ready',
    demo: false,
    matiereNom: 'Droit civil',
    dateExamen: DateTime.now().add(const Duration(days: 5)).toIso8601String(),
    nbChapitres: 5,
    nbQuestions: 30,
    nbFiches: 20,
    nbTentees: 4,
  ),
  const ApercuCours(
    id: 'c3',
    titre: 'Droit administratif',
    statut: 'processing',
    demo: false,
    matiereNom: 'Droit administratif',
    dateExamen: null,
    nbChapitres: 2,
    nbQuestions: 8,
    nbFiches: 0,
    nbTentees: 0,
  ),
];

DonneesAccueil _accueil() => DonneesAccueil(
  profil: _profil(),
  semaine: _semaine,
  objectif: 10,
  matieres: _matieres,
  dernierCours: _cours[0],
  prochainExamen: _cours[2],
);

ChapitreDuChemin _etape(
  int index,
  String titre,
  EtatChapitre etat, {
  int couronnes = 0,
  int total = 6,
  int tentees = 0,
  int justes = 0,
}) => ChapitreDuChemin(
  chapitre: ApercuChapitre(
    id: 'ch$index',
    index: index,
    titre: titre,
    nbQuestions: total,
    nbFiches: 4,
    nbTentees: tentees,
    taux: null,
    aRevoir: etat == EtatChapitre.aRevoir,
  ),
  maitrise: Maitrise(
    etat: etat,
    couronnes: couronnes,
    total: total,
    tentees: tentees,
    justes: justes,
  ),
);

final _chemin = [
  _etape(
    1,
    'Introduction au droit constitutionnel',
    EtatChapitre.couronne,
    couronnes: 3,
    tentees: 6,
    justes: 6,
  ),
  _etape(
    2,
    'La notion de Constitution',
    EtatChapitre.couronne,
    couronnes: 2,
    tentees: 6,
    justes: 5,
  ),
  _etape(
    3,
    'Le contrôle de constitutionnalité',
    EtatChapitre.aRevoir,
    tentees: 6,
    justes: 2,
  ),
  _etape(
    4,
    'La séparation des pouvoirs',
    EtatChapitre.aDecouvrir,
    tentees: 2,
    justes: 2,
  ),
  _etape(5, 'Le Parlement', EtatChapitre.verrouille),
  _etape(6, 'Le pouvoir exécutif', EtatChapitre.verrouille),
  _etape(7, 'La Cour constitutionnelle', EtatChapitre.verrouille),
];

const _questions = [
  QuestionQcm(
    id: 'q1',
    enonce:
        'Selon ton cours, qu’est-ce qui distingue le contrôle de '
        'constitutionnalité a priori du contrôle a posteriori ?',
    options: [
      'Le moment : avant ou après la promulgation de la loi',
      'L’organe qui contrôle : Parlement ou juge',
      'La procédure : écrite ou orale',
      'Le type de loi : organique ou ordinaire',
    ],
    reponse: 'Le moment : avant ou après la promulgation de la loi',
    explication:
        'Le chapitre 3 le dit : a priori, avant la promulgation ; a '
        'posteriori, à l’occasion d’un procès.',
    probabilite: 'high',
  ),
  QuestionQcm(
    id: 'q2',
    enonce:
        'À quelle date la Constitution béninoise actuellement en vigueur '
        'a-t-elle été promulguée ?',
    options: [
      'Le 2 décembre 1990',
      'Le 11 décembre 1990',
      'Le 28 février 1990',
      'Le 1er août 1960',
    ],
    reponse: 'Le 11 décembre 1990',
    explication:
        'Le référendum a eu lieu le 2 décembre 1990 ; la promulgation est du '
        '11 décembre.',
    probabilite: 'high',
  ),
  QuestionQcm(
    id: 'q3',
    enonce: 'Quel événement ouvre le Renouveau démocratique au Bénin ?',
    options: [
      'Le coup d’État de 1972',
      'La Conférence des Forces Vives de la Nation',
      'L’indépendance de 1960',
      'La révision de 2019',
    ],
    reponse: 'La Conférence des Forces Vives de la Nation',
    explication: null,
    probabilite: 'medium',
  ),
  QuestionQcm(
    id: 'q4',
    enonce: 'Qui peut saisir la Cour constitutionnelle au Bénin ?',
    options: [
      'Tout citoyen',
      'Le seul Président de la République',
      'Les seuls députés',
      'Personne, elle s’autosaisit',
    ],
    reponse: 'Tout citoyen',
    explication: 'L’article 122 ouvre la saisine à tout citoyen.',
    probabilite: 'medium',
  ),
  QuestionQcm(
    id: 'q5',
    enonce: 'Combien de temps dure le mandat présidentiel ?',
    options: ['Quatre ans', 'Cinq ans', 'Six ans', 'Sept ans'],
    reponse: 'Cinq ans',
    explication: null,
    probabilite: 'low',
  ),
  QuestionQcm(
    id: 'q6',
    enonce: 'Une Constitution « rigide » est une Constitution…',
    options: [
      'dont la révision suit une procédure plus lourde que la loi',
      'qui ne peut jamais être révisée',
      'écrite par un seul homme',
      'appliquée par l’armée',
    ],
    reponse: 'dont la révision suit une procédure plus lourde que la loi',
    explication: null,
    probabilite: 'high',
  ),
];

const _fiches = [
  Fiche(
    id: 'f1',
    recto: 'Qu’est-ce qu’une Constitution rigide ?',
    verso:
        'Une Constitution dont la révision suit une procédure plus lourde '
        'que celle des lois ordinaires. C’est le cas de celle du Bénin '
        '(articles 154 à 156).',
    chapitre: 'La notion de Constitution',
    indexChapitre: 2,
  ),
  Fiche(
    id: 'f2',
    recto: 'Qui contrôle la constitutionnalité des lois au Bénin ?',
    verso: 'La Cour constitutionnelle, saisie avant ou après la promulgation.',
    chapitre: 'Le contrôle de constitutionnalité',
    indexChapitre: 3,
  ),
];

const _packs = [
  PackBoutique(
    code: 'decouverte',
    libelle: 'Découverte',
    description: 'Pour voir ce que Reviz sait faire.',
    prixFcfa: 0,
    dureeJours: 3,
    correctionsIncluses: 1,
    plafondMatieres: 1,
  ),
  PackBoutique(
    code: 'controle',
    libelle: 'Contrôle',
    description: 'La semaine avant le devoir.',
    prixFcfa: 500,
    dureeJours: 7,
    correctionsIncluses: 3,
    plafondMatieres: 2,
  ),
  PackBoutique(
    code: 'partiel',
    libelle: 'Partiel',
    description: 'Tout le mois des partiels.',
    prixFcfa: 2000,
    dureeJours: 30,
    correctionsIncluses: 10,
    plafondMatieres: null,
  ),
  PackBoutique(
    code: 'semestre',
    libelle: 'Semestre',
    description: 'Du premier cours au dernier examen.',
    prixFcfa: 5000,
    dureeJours: 120,
    correctionsIncluses: 30,
    plafondMatieres: null,
  ),
];

List<LigneAbonnement> get _abonnementsActifs {
  final maintenant = DateTime.now().toUtc();
  return [
    LigneAbonnement(
      code: 'partiel',
      debut: maintenant.subtract(const Duration(days: 9)),
      fin: maintenant.add(const Duration(days: 21)),
      correctionsRestantes: 7,
      plafondMatieres: null,
    ),
  ];
}

DonneesBoutique _boutique() =>
    DonneesBoutique(packs: _packs, abonnements: _abonnementsActifs);

final EtatAcces _acces = AccesActif(
  fin: DateTime.now().toUtc().add(const Duration(days: 21)),
  joursRestants: 21,
  correctionsRestantes: 7,
  plafondMatieres: null,
  packs: const [CodePack.partiel],
);

DonneesLigue _ligue() {
  const prenoms = [
    'Koffi',
    'Aïcha',
    'Mawuli',
    'Awa',
    'Sèna',
    'Ibrahim',
    'Fifamè',
    'Yao',
    'Rokia',
    'Edem',
    'Nafi',
    'Kossi',
    'Adjoa',
    'Moussa',
  ];
  final fin = DateTime.now().add(const Duration(days: 3, hours: 4));
  return DonneesLigue(
    division: 2,
    fin: fin,
    derniere: BilanLigue(
      semaine: fin
          .subtract(const Duration(days: 14))
          .toUtc()
          .toIso8601String()
          .substring(0, 10),
      rang: 5,
      issue: 'monte',
      division: 1,
    ),
    membres: [
      for (var i = 0; i < prenoms.length; i++)
        LigneClassement(
          rang: i + 1,
          prenom: prenoms[i],
          // Awa garde sa panthère ; les autres prennent les onze animaux restants.
          avatar: i == 3
              ? 'ton-01'
              : 'ton-${((i % 11) + 2).toString().padLeft(2, '0')}',
          xp: 640 - i * 37,
          estMoi: i == 3,
        ),
    ],
  );
}

const _classement = DonneesClassement(
  monRang: 4,
  lignes: [
    LigneClassement(
      rang: 1,
      prenom: 'Koffi',
      avatar: 'ton-03',
      xp: 4820,
      estMoi: false,
    ),
    LigneClassement(
      rang: 2,
      prenom: 'Aïcha',
      avatar: 'ton-07',
      xp: 4310,
      estMoi: false,
    ),
    LigneClassement(
      rang: 3,
      prenom: 'Mahouénan',
      avatar: 'ton-05',
      xp: 3990,
      estMoi: false,
    ),
    LigneClassement(
      rang: 4,
      prenom: 'Awa',
      avatar: 'ton-01',
      xp: 3720,
      estMoi: true,
    ),
    LigneClassement(
      rang: 5,
      prenom: 'Sènankpon',
      avatar: 'ton-09',
      xp: 3120,
      estMoi: false,
    ),
    LigneClassement(
      rang: 6,
      prenom: 'Ibrahim',
      avatar: 'ton-11',
      xp: 2870,
      estMoi: false,
    ),
    LigneClassement(
      rang: 7,
      prenom: 'Fifamè',
      avatar: 'ton-02',
      xp: 2540,
      estMoi: false,
    ),
    LigneClassement(
      rang: 8,
      prenom: 'Yao',
      avatar: 'ton-06',
      xp: 2210,
      estMoi: false,
    ),
    LigneClassement(
      rang: 9,
      prenom: 'Rokia',
      avatar: 'ton-04',
      xp: 1980,
      estMoi: false,
    ),
    LigneClassement(
      rang: 10,
      prenom: 'Edem',
      avatar: 'ton-08',
      xp: 1650,
      estMoi: false,
    ),
  ],
);

final _correction = Correction(
  id: 'k1',
  coursId: 'c1',
  statut: 'ready',
  note: 27.5,
  bareme: 40,
  lignes: const [
    LigneBareme(
      critere: 'Compréhension du sujet',
      points: 9,
      maximum: 10,
      commentaire: 'Tu as bien situé la question dans le cours.',
    ),
    LigneBareme(
      critere: 'Maîtrise des notions du cours',
      points: 10.5,
      maximum: 16,
      commentaire:
          'Le contrôle a posteriori est confondu avec l’exception '
          'd’inconstitutionnalité : revois le chapitre 3.',
    ),
    LigneBareme(
      critere: 'Plan et argumentation',
      points: 8,
      maximum: 14,
      commentaire: 'Deux parties équilibrées, mais la transition manque.',
    ),
  ],
  retour: const RetourCorrection(
    resume:
        'Bonne copie de L2 : le plan tient, les définitions sont justes. Il '
        'manque les articles du cours pour convaincre.',
    pointsForts: ['Définitions exactes', 'Plan clair'],
    aTravailler: ['Citer les articles', 'Conclusion trop courte'],
    chapitres: [('ch3', 'Le contrôle de constitutionnalité')],
    notions: ['Contrôle a posteriori', 'Saisine citoyenne'],
  ),
  modele: null,
  creeLe: DateTime.now().subtract(const Duration(hours: 2)),
  motifIllisible: null,
);

final _correctionEnCours = Correction(
  id: 'k2',
  coursId: 'c2',
  statut: 'processing',
  note: null,
  bareme: null,
  lignes: const [],
  retour: null,
  modele: null,
  creeLe: DateTime.now(),
  motifIllisible: null,
);

// ---------------------------------------------------------- Notifications

final _ilYa = DateTime.now();

NotificationReviz _notif(
  String id,
  String kind,
  Map<String, dynamic> data, {
  bool lue = false,
  Duration il = const Duration(minutes: 3),
}) => NotificationReviz(
  id: id,
  kind: kind,
  referenceId: 'r$id',
  data: data,
  lue: lue,
  creeLe: _ilYa.subtract(il),
);

final _notifications = [
  _notif('1', 'cours_pret', {'titre': 'Droit des obligations'}),
  _notif('2', 'correction_prete', {
    'note': 27.5,
    'bareme': 40,
  }, il: const Duration(minutes: 42)),
  _notif('3', 'commission_recue', {
    'montant': 375,
  }, il: const Duration(hours: 2)),
  _notif(
    '4',
    'ligue_cloturee',
    {'issue': 'monte', 'rang': 2, 'division': 3},
    lue: true,
    il: const Duration(days: 1, hours: 2),
  ),
  _notif(
    '5',
    'paiement_reussi',
    {'montant': 1500, 'pack': 'partiel'},
    lue: true,
    il: const Duration(days: 9),
  ),
  _notif('6', 'carte_verifiee', {}, lue: true, il: const Duration(days: 12)),
];

// -------------------------------------------------------- Dépôts factices

class _DepotCoursFactice extends DepotCours {
  const _DepotCoursFactice();

  @override
  Future<Reponse<ResultatSession>> terminerSession({
    required ApiReviz api,
    required String coursId,
    required List<({String questionId, String? choix})> reponses,
    String? sessionId,
  }) async => const ReponseSucces(
    ResultatSession(
      bonnes: 5,
      total: 6,
      xp: 90,
      gains: [
        GainSession(motif: 'correct_answer', montant: 50),
        GainSession(motif: 'quiz_completed', montant: 20),
        GainSession(motif: 'daily_goal', montant: 20),
      ],
      objectifAtteint: true,
      serie: 7,
    ),
  );
}

class _DepotBoutiqueFactice extends DepotBoutique {
  const _DepotBoutiqueFactice(this.statut);
  final String statut;

  @override
  Future<Reponse<String>> suivrePaiement(ApiReviz api, String id) async =>
      ReponseSucces(statut);

  @override
  Future<String?> dernierTelephone() async => '0197000000';
}

class _RappelsFactices extends ServiceRappels {
  @override
  Future<void> programmer(List<Rappel> rappels) async {}

  @override
  Future<void> demanderPermissionUneFois() async {}
}

/// Ce que tout écran peut lire, pour qu'aucun ne parte sur le réseau.
List<Override> get _socle => [
  profilProvider.overrideWith((_) async => _profil()),
  accueilProvider.overrideWith((_) async => _accueil()),
  coursProvider.overrideWith((_) async => _cours),
  boutiqueProvider.overrideWith((_) async => _boutique()),
  ligueProvider.overrideWith((_) async => _ligue()),
  accesCorrectionProvider.overrideWith((_) async => _acces),
  serviceRappelsProvider.overrideWithValue(_RappelsFactices()),
  depotCoursProvider.overrideWithValue(const _DepotCoursFactice()),
  notificationsProvider.overrideWith((_) async => _notifications),
  pushDisponibleProvider.overrideWith((_) async => true),
  prefsPushProvider.overrideWith((_) async => const PrefsPush(ligue: false)),
];

// ---------------------------------------------------------------- Habillage

/// La barre d'état d'un téléphone, à 9:41, réseau et batterie pleins.
class _BarreEtat extends StatelessWidget {
  const _BarreEtat();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: _hautBarre,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            children: [
              Text(
                '9:41',
                style: TextStyle(
                  fontFamily: 'Nunito Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Couleurs.encre,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  // Hors de tout `Material` : sans cela, Flutter souligne
                  // le texte en jaune pour signaler l'absence de style.
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.signal_cellular_alt,
                size: 18,
                color: Couleurs.encre,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.wifi, size: 18, color: Couleurs.encre),
              const SizedBox(width: 4),
              const RotatedBox(
                quarterTurns: 1,
                child: Icon(
                  Icons.battery_full,
                  size: 20,
                  color: Couleurs.encre,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _hautBarre = 47.0;
const _basIndicateur = 34.0;
const _largeur = 390.0;
const _hauteur = 844.0;
const _echelle = 3.0;

class _Habillage extends StatelessWidget {
  const _Habillage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        const Positioned(top: 0, left: 0, right: 0, child: _BarreEtat()),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: 134,
                height: 5,
                decoration: BoxDecoration(
                  color: Couleurs.encre,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _surOnglet(Widget ecran, int onglet) => Scaffold(
  body: ecran,
  bottomNavigationBar: NavBasse(indexActif: onglet, onChoisir: (_) {}),
);

// -------------------------------------------------------------------- Banc

typedef _Geste =
    Future<void> Function(WidgetTester tester, ProviderContainer c);

Future<void> _attendreImages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Monte un écran, joue des gestes, puis le photographie.
///
/// `hauteur` au-delà de 844 donne une version longue, pour un défilement.
Future<void> _cliche(
  WidgetTester tester,
  String nom,
  Widget ecran, {
  List<Override> remplacements = const [],
  double hauteur = _hauteur,
  _Geste? geste,
}) async {
  tester.view.physicalSize = Size(_largeur, hauteur) * _echelle;
  tester.view.devicePixelRatio = _echelle;
  tester.view.padding = const FakeViewPadding(
    top: _hautBarre * _echelle,
    bottom: _basIndicateur * _echelle,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _hautBarre * _echelle,
    bottom: _basIndicateur * _echelle,
  );
  addTearDown(tester.view.reset);

  // Les remplacements propres à l'écran passent devant le socle.
  final noms = remplacements.map((o) => o.toString()).toSet();
  final container = ProviderContainer(
    overrides: [
      ...remplacements,
      ..._socle.where((o) => !noms.contains(o.toString())),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themeReviz,
        builder: (context, child) => _Habillage(child: child!),
        home: RepaintBoundary(key: const ValueKey('photo'), child: ecran),
      ),
    ),
  );

  await _attendreImages(tester);
  if (geste != null) {
    await geste(tester, container);
    await _attendreImages(tester);
  }

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('studio/$nom.png'),
  );

  // Les minuteurs (sondage du paiement, confettis) s'arrêtent avec l'écran.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
}

Future<void> _taper(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(cible.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 600));
}

/// Répond à la question en cours : `juste` choisit la bonne réponse.
Future<void> _repondre(
  WidgetTester tester,
  QuestionQcm q, {
  bool juste = true,
}) async {
  final choix = juste ? q.reponse : q.options.firstWhere((o) => o != q.reponse);
  await _taper(tester, find.text(choix));
  await _taper(tester, find.text('Valider'));
}

// ------------------------------------------------------------------ Écrans

void main() {
  setUpAll(_chargerPolices);

  final sessionCours = questionsProvider((
    cours: 'c1',
    chapitre: null,
    mode: ModeSession.normal,
  )).overrideWith((_) async => _questions);

  // ---- Entrée
  // Lancé avec `--dart-define=GOOGLE_WEB_CLIENT_ID=apercu` : le bouton Google
  // apparaît alors actif, comme dans l'APK publié.
  testWidgets(
    '01-connexion',
    (t) => _cliche(
      t,
      '01-connexion',
      const EcranConnexion(),
      geste: (t, _) async {
        await t.enterText(find.byType(TextField).first, 'awa.dossou@gmail.com');
        await t.pump(const Duration(milliseconds: 300));
        FocusManager.instance.primaryFocus?.unfocus();
      },
    ),
  );

  testWidgets(
    '02-inscription',
    (t) => _cliche(
      t,
      '02-inscription',
      const EcranInscription(),
      geste: (t, _) async {
        final champs = find.byType(TextField);
        final n = t.widgetList(champs).length;
        await t.enterText(champs.at(0), 'Awa');
        if (n >= 3) {
          await t.enterText(champs.at(n - 2), '01 97 00 00 00');
          await t.enterText(champs.at(n - 1), 'KOFFI7');
        }
        await t.pump(const Duration(milliseconds: 300));
        FocusManager.instance.primaryFocus?.unfocus();
      },
      remplacements: [
        universitesProvider.overrideWith(
          (_) async => const [
            Universite(id: 'u1', nom: 'Université d’Abomey-Calavi (UAC)'),
            Universite(id: 'u2', nom: 'Université de Parakou'),
            Universite(id: 'u3', nom: 'Université de Lomé'),
          ],
        ),
      ],
    ),
  );

  // ---- Onglets
  testWidgets(
    '03-accueil',
    (t) => _cliche(t, '03-accueil', _surOnglet(const EcranAccueil(), 0)),
  );
  testWidgets(
    '03-accueil-long',
    (t) => _cliche(
      t,
      '03-accueil-long',
      _surOnglet(const EcranAccueil(), 0),
      hauteur: 1700,
    ),
  );

  testWidgets(
    '04-reviser',
    (t) => _cliche(t, '04-reviser', _surOnglet(const EcranReviser(), 1)),
  );

  testWidgets(
    '05-ajouter-cours',
    (t) => _cliche(
      t,
      '05-ajouter-cours',
      const EcranAjouterCours(),
      remplacements: [
        matieresProvider.overrideWith(
          (_) async => const [
            Matiere(id: 'm1', nom: 'Droit constitutionnel'),
            Matiere(id: 'm2', nom: 'Introduction à l’étude du droit'),
            Matiere(id: 'm3', nom: 'Économie politique'),
          ],
        ),
      ],
    ),
  );

  final coursC1 = [
    unCoursProvider('c1').overrideWith((_) async => _cours[0]),
    cheminProvider('c1').overrideWith((_) async => _chemin),
  ];
  testWidgets(
    '06-chemin',
    (t) => _cliche(
      t,
      '06-chemin',
      const EcranCours(coursId: 'c1'),
      remplacements: coursC1,
    ),
  );
  testWidgets(
    '06-chemin-long',
    (t) => _cliche(
      t,
      '06-chemin-long',
      const EcranCours(coursId: 'c1'),
      remplacements: coursC1,
      hauteur: 2000,
    ),
  );

  // ---- Session de QCM
  testWidgets(
    '07-question',
    (t) => _cliche(
      t,
      '07-question',
      const EcranSession(coursId: 'c1'),
      remplacements: [sessionCours],
    ),
  );

  testWidgets(
    '08-question-choisie',
    (t) => _cliche(
      t,
      '08-question-choisie',
      const EcranSession(coursId: 'c1'),
      remplacements: [sessionCours],
      geste: (t, _) => _taper(t, find.text(_questions[0].reponse)),
    ),
  );

  testWidgets(
    '09-bonne-reponse',
    (t) => _cliche(
      t,
      '09-bonne-reponse',
      const EcranSession(coursId: 'c1'),
      remplacements: [sessionCours],
      geste: (t, _) => _repondre(t, _questions[0]),
    ),
  );

  testWidgets(
    '10-mauvaise-reponse',
    (t) => _cliche(
      t,
      '10-mauvaise-reponse',
      const EcranSession(coursId: 'c1'),
      remplacements: [sessionCours],
      geste: (t, _) => _repondre(t, _questions[0], juste: false),
    ),
  );

  // Le profil change entre le début et la fin de la série : 1 200 XP, puis
  // 1 290, ce qui franchit le niveau 6 et déclenche « Niveau supérieur ! ».
  Future<void> serieComplete(
    WidgetTester t,
    String nom, {
    bool fermer = false,
  }) {
    var lectures = 0;
    return _cliche(
      t,
      nom,
      const EcranSession(coursId: 'c1'),
      remplacements: [
        sessionCours,
        profilProvider.overrideWith(
          (_) async => _profil(xp: lectures++ == 0 ? 1200 : 1290),
        ),
      ],
      geste: (t, c) async {
        await t.runAsync(() => c.read(profilProvider.future));
        await t.pump();
        for (var i = 0; i < _questions.length; i++) {
          await _repondre(t, _questions[i], juste: i != 2);
          await _taper(
            t,
            find.text(
              i == _questions.length - 1
                  ? 'Voir mon résultat'
                  : 'Question suivante',
            ),
          );
        }
        for (var i = 0; i < 15; i++) {
          await t.pump(const Duration(milliseconds: 200));
        }
        if (fermer) {
          await _taper(t, find.text('Continuer').last);
          for (var i = 0; i < 10; i++) {
            await t.pump(const Duration(milliseconds: 200));
          }
        }
      },
    );
  }

  testWidgets(
    '11-niveau-superieur',
    (t) => serieComplete(t, '11-niveau-superieur'),
  );
  testWidgets(
    '12-resultat',
    (t) => serieComplete(t, '12-resultat', fermer: true),
  );

  // ---- Fiches
  final fichesC1 = [fichesProvider('c1').overrideWith((_) async => _fiches)];
  testWidgets(
    '13-fiche-recto',
    (t) => _cliche(
      t,
      '13-fiche-recto',
      const EcranFiches(coursId: 'c1'),
      remplacements: fichesC1,
    ),
  );
  testWidgets(
    '14-fiche-verso',
    (t) => _cliche(
      t,
      '14-fiche-verso',
      const EcranFiches(coursId: 'c1'),
      remplacements: fichesC1,
      geste: (t, _) async {
        await _taper(t, find.text(_fiches[0].recto));
        for (var i = 0; i < 6; i++) {
          await t.pump(const Duration(milliseconds: 200));
        }
      },
    ),
  );

  // ---- Correction
  final corrections = [
    correctionsProvider.overrideWith(
      (_) async => [_correctionEnCours, _correction],
    ),
  ];
  testWidgets(
    '15-corriger',
    (t) => _cliche(
      t,
      '15-corriger',
      _surOnglet(const EcranCorriger(), 2),
      remplacements: corrections,
    ),
  );
  testWidgets(
    '15-corriger-long',
    (t) => _cliche(
      t,
      '15-corriger-long',
      _surOnglet(const EcranCorriger(), 2),
      remplacements: corrections,
      hauteur: 1500,
    ),
  );

  final correctionK1 = [
    correctionProvider('k1').overrideWith((_) async => _correction),
  ];
  testWidgets(
    '16-correction',
    (t) => _cliche(
      t,
      '16-correction',
      const EcranCorrection(correctionId: 'k1'),
      remplacements: correctionK1,
    ),
  );
  testWidgets(
    '16-correction-long',
    (t) => _cliche(
      t,
      '16-correction-long',
      const EcranCorrection(correctionId: 'k1'),
      remplacements: correctionK1,
      hauteur: 1700,
    ),
  );

  // ---- Compétition
  testWidgets('17-ligue', (t) => _cliche(t, '17-ligue', const EcranLigue()));
  testWidgets(
    '17-ligue-long',
    (t) => _cliche(t, '17-ligue-long', const EcranLigue(), hauteur: 1500),
  );

  testWidgets(
    '18-classement',
    (t) => _cliche(
      t,
      '18-classement',
      const EcranClassement(),
      remplacements: [
        classementProvider.overrideWith((_) async => _classement),
      ],
    ),
  );

  // ---- Argent
  final gains = [
    gainsProvider.overrideWith(
      (_) async => const DonneesGains(
        soldeFcfa: 4250,
        codeParrain: 'AWA225',
        filleuls: 6,
        filleulsPayants: 4,
      ),
    ),
  ];
  testWidgets(
    '19-gains',
    (t) => _cliche(
      t,
      '19-gains',
      _surOnglet(const EcranGains(), 3),
      remplacements: gains,
    ),
  );
  testWidgets(
    '19-gains-long',
    (t) => _cliche(
      t,
      '19-gains-long',
      _surOnglet(const EcranGains(), 3),
      remplacements: gains,
      hauteur: 1400,
    ),
  );

  testWidgets(
    '20-boutique',
    (t) => _cliche(t, '20-boutique', const EcranBoutique()),
  );
  testWidgets(
    '20-boutique-long',
    (t) => _cliche(t, '20-boutique-long', const EcranBoutique(), hauteur: 2000),
  );

  testWidgets(
    '21-payer',
    (t) => _cliche(
      t,
      '21-payer',
      const EcranPayer(
        pack: PackBoutique(
          code: 'partiel',
          libelle: 'Partiel',
          description: 'Tout le mois des partiels.',
          prixFcfa: 2000,
          dureeJours: 30,
          correctionsIncluses: 10,
          plafondMatieres: null,
        ),
        emailCompte: 'awa.dossou@gmail.com',
      ),
      remplacements: [
        depotBoutiqueProvider.overrideWithValue(
          const _DepotBoutiqueFactice('pending'),
        ),
      ],
    ),
  );

  testWidgets(
    '22-paiement-attente',
    (t) => _cliche(
      t,
      '22-paiement-attente',
      const EcranPaiement(paiementId: 'p1'),
      remplacements: [
        depotBoutiqueProvider.overrideWithValue(
          const _DepotBoutiqueFactice('pending'),
        ),
      ],
    ),
  );

  testWidgets(
    '23-paiement-reussi',
    (t) => _cliche(
      t,
      '23-paiement-reussi',
      const EcranPaiement(paiementId: 'p1'),
      remplacements: [
        depotBoutiqueProvider.overrideWithValue(
          const _DepotBoutiqueFactice('success'),
        ),
      ],
    ),
  );

  // ---- Profil
  testWidgets(
    '24-profil',
    (t) => _cliche(t, '24-profil', _surOnglet(const EcranProfil(), 4)),
  );
  testWidgets(
    '24-profil-long',
    (t) => _cliche(
      t,
      '24-profil-long',
      _surOnglet(const EcranProfil(), 4),
      hauteur: 1600,
    ),
  );

  testWidgets('25-avatar', (t) => _cliche(t, '25-avatar', const EcranAvatar()));

  testWidgets(
    '26-carte-etudiante',
    (t) => _cliche(
      t,
      '26-carte-etudiante',
      const EcranCarte(),
      remplacements: [
        profilProvider.overrideWith((_) async => _profil(statut: 'none')),
      ],
    ),
  );

  testWidgets('27-aide', (t) => _cliche(t, '27-aide', const EcranAide()));

  // ---- États
  testWidgets(
    '28-hors-ligne',
    (t) => _cliche(
      t,
      '28-hors-ligne',
      // Comme dans l'application (`main.dart`) : le bandeau se pose par-dessus
      // l'écran, en haut.
      Stack(
        children: [
          _surOnglet(const EcranAccueil(), 0),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: BandeauHorsLigne(),
          ),
        ],
      ),
    ),
  );

  testWidgets(
    '29-mise-a-jour',
    (t) => _cliche(
      t,
      '29-mise-a-jour',
      const EcranMiseAJour(
        etat: EtatMiseAJour(
          exigence: ExigenceVersion.exigee,
          locale: '2.4.0',
          distante: VersionDistante(
            minimum: '2.5.0',
            derniere: '2.5.2',
            notes: 'Les ligues de la semaine, et les rappels du soir.',
            lien: 'https://reviz-eight.vercel.app/app',
          ),
        ),
      ),
    ),
  );

  testWidgets(
    '30-notifications',
    (t) => _cliche(t, '30-notifications', const EcranNotifications()),
  );

  testWidgets(
    '31-reglages-notifications',
    (t) => _cliche(
      t,
      '31-reglages-notifications',
      const EcranReglagesNotifications(),
    ),
  );
}
