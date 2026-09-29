// Accès aux données.
//
// Deux canaux, et la règle qui les sépare (docs/API.md § 1) : toute lecture
// que la RLS sait filtrer passe en direct par PostgREST, toute écriture qui
// exige un privilège passe par une route Next.js. Les quatre vues sont en
// `security_invoker`, donc consommables telles quelles.

import 'package:crypto/crypto.dart';
import '../metier/acces.dart';
import 'api.dart';
import 'modeles.dart';
import 'supabase.dart';

/// Petite aide : PostgREST renvoie des `Map<String, dynamic>` déjà typées,
/// mais les fabriques qui peuvent refuser une ligne renvoient `null`.
List<T> _garder<T>(
  List<dynamic> lignes,
  T? Function(Map<String, dynamic>) fabrique,
) {
  final gardees = <T>[];
  for (final l in lignes) {
    if (l is! Map) continue;
    final objet = fabrique(Map<String, dynamic>.from(l));
    if (objet != null) gardees.add(objet);
  }
  return gardees;
}

// ---------------------------------------------------------------- Profil

class DepotProfil {
  const DepotProfil();

  /// Le profil de l'utilisateur connecté, ou `null` s'il n'a pas encore
  /// terminé son inscription.
  Future<Profil?> mien() async {
    final id = supabase.auth.currentUser?.id;
    if (id == null) return null;

    final ligne = await supabase
        .from('profiles')
        .select(
          'id, first_name, xp_total, current_streak, last_validated_on, '
          'faculty_id, referral_code, avatar_key, verification_status, '
          'study_year, universities(name), faculties(name)',
        )
        .eq('id', id)
        .maybeSingle();

    if (ligne == null) return null;
    return Profil.depuis(ligne);
  }

  Future<List<Universite>> universites() async {
    final lignes = await supabase.from('universities').select('id, name').order('name');
    return _garder(lignes, Universite.depuis);
  }

  Future<List<Faculte>> facultes(String universiteId) async {
    final lignes = await supabase
        .from('faculties')
        .select('id, name, university_id')
        .eq('university_id', universiteId)
        .order('name');
    return _garder(lignes, Faculte.depuis);
  }

  /// Choisit son avatar — par la route, pour la liste blanche.
  ///
  /// `avatar_key` est une colonne `text` libre que le trigger
  /// `protect_profile_columns` ne gèle pas : une écriture directe passerait,
  /// avec n'importe quelle valeur. La route vérifie que la clé fait partie
  /// des douze.
  Future<Reponse<String>> choisirAvatar(ApiReviz api, String cle) {
    return api.mettreAJour<String>(
      '/api/profile/avatar',
      corps: {'avatar_key': cle},
      depuis: (data) => data['avatarKey'] as String,
    );
  }

  /// Supprime le compte — par anonymisation.
  ///
  /// La base refuse la suppression : trois clés étrangères en
  /// `on delete restrict` et le trigger `xp_events_no_delete` arrêtent la
  /// cascade, même pour le rôle de service. La route vide donc l'identité et
  /// retire le contenu personnel, en laissant les lignes financières sans nom
  /// dessus (voir `docs/API.md`).
  Future<Reponse<bool>> supprimer(ApiReviz api) {
    return api.poster<bool>(
      '/api/profile/delete',
      depuis: (data) => data['anonymise'] as bool? ?? true,
    );
  }

  /// Dépose la photo de sa carte étudiante, et lance la vérification.
  ///
  /// Même chemin que les cours et les copies : URL signée, `PUT` direct au
  /// stockage, confirmation. Le retour n'est pas le verdict — c'est
  /// l'identifiant du traitement. Le verdict arrive dans
  /// `profiles.verification_status`, que l'écran relit.
  ///
  /// Aucune annulation à prévoir ici : contrairement au dépôt d'un cours,
  /// rien n'est réservé avant l'envoi, donc un envoi interrompu ne consomme
  /// rien et ne bloque aucun redépôt.
  Future<Reponse<String>> deposerCarte({
    required ApiReviz api,
    required List<int> octets,
    required String typeMime,
    void Function(double part)? progression,
  }) async {
    final prepare = await api.poster<CartePreparee>(
      '/api/carte/preparer',
      corps: {'mime': typeMime, 'taille': octets.length},
      depuis: CartePreparee.depuis,
    );

    if (prepare case ReponseEchec(:final erreur, :final motif)) {
      return Reponse.echec(erreur, motif: motif);
    }

    final depot = (prepare as ReponseSucces<CartePreparee>).data;

    final echec = await api.televerser(
      url: depot.urlEnvoi,
      octets: octets,
      typeMime: typeMime,
      progression: (envoyes, total) =>
          progression?.call(total <= 0 ? 0 : envoyes / total),
    );

    if (echec != null) return Reponse.echec(echec, motif: 'envoi');

    return api.poster<String>(
      '/api/carte/confirmer',
      corps: {'chemin': depot.chemin},
      depuis: (data) => data['jobId'] as String,
    );
  }

  /// Création du profil — par la route, pas en direct.
  ///
  /// Le code parrain désigne un profil dont la RLS ne laisse rien lire : la
  /// recherche exige le rôle de service. Et depuis la phase 0, les colonnes
  /// privilégiées de `profiles` sont verrouillées par trigger, donc une
  /// insertion cliente ne pourrait de toute façon plus rien s'octroyer.
  Future<Reponse<String>> creer({
    required ApiReviz api,
    required String prenom,
    required String universiteId,
    required String faculteId,
    required int annee,
    String? codeParrain,
  }) {
    return api.poster<String>(
      '/api/profil',
      corps: {
        'prenom': prenom,
        'universiteId': universiteId,
        'faculteId': faculteId,
        'annee': annee,
        if (codeParrain != null && codeParrain.isNotEmpty)
          'codeParrain': codeParrain,
      },
      depuis: (data) => data['id'] as String,
    );
  }
}

// --------------------------------------------------------------- Accueil

class DonneesAccueil {
  const DonneesAccueil({
    required this.profil,
    required this.semaine,
    required this.objectif,
    required this.matieres,
    this.dernierCours,
    this.prochainExamen,
  });

  final Profil profil;
  final List<JourSerie> semaine;
  final int objectif;
  final List<StatMatiere> matieres;

  /// Le cours que « Continuer » rouvre : le dernier prêt, les siens avant la
  /// démonstration. `null` tant qu'aucun cours n'a de questions.
  final ApercuCours? dernierCours;

  /// Le cours dont l'examen tombe le plus tôt, aujourd'hui compris.
  final ApercuCours? prochainExamen;

  JourSerie? get aujourdhui {
    for (final j in semaine) {
      if (j.aujourdhui) return j;
    }
    return null;
  }
}

class DepotAccueil {
  const DepotAccueil();

  /// Tout ce que le tableau de bord affiche, en une salve.
  ///
  /// `Future.wait` et non quatre attentes en file : l'étudiant est sur une
  /// connexion instable, et quatre allers-retours en série se voient.
  Future<DonneesAccueil?> charger() async {
    final profil = await const DepotProfil().mien();
    if (profil == null) return null;

    // Les constructeurs de requête de supabase_flutter sont des `Future` par
    // `Thenable`, mais pas des `Future` au sens du type : on les enveloppe
    // explicitement pour que `Future.wait` les accepte.
    final resultats = await Future.wait<dynamic>([
      Future<dynamic>.value(supabase.rpc('streak_week')),
      Future<dynamic>.value(supabase.rpc('daily_goal')),
      Future<dynamic>.value(
        supabase
            .from('subject_stats')
            .select(
              'subject_id, subject_name, questions_answered, average_score, '
              'is_weak',
            )
            .order('questions_answered', ascending: false)
            .limit(4),
      ),
      Future<dynamic>.value(
        supabase
            .from('course_overview')
            .select(_colonnesCours)
            .eq('status', 'ready')
            .order('is_demo', ascending: true)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle(),
      ),
      Future<dynamic>.value(
        supabase
            .from('course_overview')
            .select(_colonnesCours)
            .gte('exam_date', _aujourdhuiIso())
            .order('exam_date', ascending: true)
            .limit(1)
            .maybeSingle(),
      ),
    ]);

    return DonneesAccueil(
      profil: profil,
      semaine: _garder(resultats[0] as List? ?? const [], JourSerie.depuis),
      objectif: (resultats[1] as num?)?.toInt() ?? 10,
      matieres: _garder(resultats[2] as List? ?? const [], StatMatiere.depuis),
      dernierCours: _un(resultats[3], ApercuCours.depuis),
      prochainExamen: _un(resultats[4], ApercuCours.depuis),
    );
  }

  static const _colonnesCours =
      'id, title, status, is_demo, subject_name, exam_date, '
      'nb_chapitres, nb_questions, nb_fiches, nb_tentees';

  /// La date du téléphone, pas celle d'UTC : entre minuit et une heure à
  /// Cotonou, UTC est encore la veille, et l'examen d'hier compterait encore
  /// — à l'heure précise où l'étudiant révise.
  static String _aujourdhuiIso() {
    final m = DateTime.now();
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${m.year}-${deux(m.month)}-${deux(m.day)}';
  }

  static T? _un<T>(Object? ligne, T? Function(Map<String, dynamic>) lire) =>
      ligne is Map<String, dynamic> ? lire(ligne) : null;
}

// ----------------------------------------------------------------- Cours

class DepotCours {
  const DepotCours();

  /// Les cours visibles, démonstration épinglée en tête.
  ///
  /// La RLS filtre : mes cours, ceux partagés dans ma faculté, et les
  /// démonstrations. Aucun filtre à écrire ici.
  Future<List<ApercuCours>> liste() async {
    final lignes = await supabase
        .from('course_overview')
        .select(
          'id, title, status, is_demo, subject_name, exam_date, '
          'nb_chapitres, nb_questions, nb_fiches, nb_tentees, created_at',
        )
        .order('is_demo', ascending: false)
        .order('created_at', ascending: false);

    return _garder(lignes, ApercuCours.depuis);
  }

  Future<ApercuCours?> un(String id) async {
    final ligne = await supabase
        .from('course_overview')
        .select(
          'id, title, status, is_demo, subject_name, exam_date, '
          'nb_chapitres, nb_questions, nb_fiches, nb_tentees',
        )
        .eq('id', id)
        .maybeSingle();

    if (ligne == null) return null;
    return ApercuCours.depuis(ligne);
  }

  /// L'état d'un cours **par la route**, et non par PostgREST.
  ///
  /// La différence n'est pas cosmétique : cet appel **relance le traitement**.
  /// La chaîne d'un dépôt traite un chapitre par passage et se remet en file ;
  /// seul le premier job part depuis l'invocation du dépôt, les suivants
  /// attendaient le cron — planifié une fois par jour sur l'offre Hobby. Un
  /// cours de six chapitres aurait mis des jours à être prêt.
  ///
  /// C'est donc l'attente de l'étudiant qui fait avancer la chaîne, un
  /// chapitre par interrogation.
  Future<ApercuCours?> etat(ApiReviz api, String coursId) async {
    final reponse = await api.obtenir<ApercuCours?>(
      '/api/cours/$coursId',
      depuis: ApercuCours.depuis,
    );

    return switch (reponse) {
      ReponseSucces(:final data) => data,
      // Un échec de lecture ne doit pas vider l'écran : l'appelant garde ce
      // qu'il affichait déjà et réessaiera au tour suivant.
      ReponseEchec() => null,
    };
  }

  Future<List<ApercuChapitre>> chapitres(String coursId) async {
    final lignes = await supabase
        .from('chapter_stats')
        .select(
          'id, index, title, nb_questions, nb_fiches, nb_tentees, taux, '
          'is_weak',
        )
        .eq('course_id', coursId)
        .order('index');

    return _garder(lignes, ApercuChapitre.depuis);
  }

  /// Les questions d'une session : QCM seulement, les plus probables d'abord.
  ///
  /// L'énumération `question_probability` est déclarée (high, medium, low),
  /// donc l'ordre croissant de Postgres est déjà celui de la promesse produit
  /// — « les questions qui vont probablement tomber ».
  ///
  /// Dix par session, comme `public.daily_goal()` : une session finie doit
  /// pouvoir valider la journée, sinon la série reste hors d'atteinte de qui
  /// révise une fois par jour.
  Future<List<QuestionQcm>> questionsDeSession(
    String coursId, {
    int combien = 10,
  }) async {
    final lignes = await supabase
        .from('questions')
        .select(
          'id, statement, options, answer, explanation, probability, '
          'chapters!inner(course_id)',
        )
        .eq('chapters.course_id', coursId)
        .eq('type', 'mcq')
        .order('probability')
        .limit(combien);

    return _garder(lignes, QuestionQcm.depuis);
  }

  /// Fin de session — par la route : le serveur recorrige depuis
  /// `questions.answer` avant d'écrire, et attribue les XP avec le rôle de
  /// service.
  /// Les matières de la faculté de l'étudiant, pour le choix au dépôt.
  ///
  /// « Matières lisibles par tous » : aucune route nécessaire. On les filtre
  /// sur la faculté, sinon la liste contiendrait celles de toutes les
  /// universités du pays.
  Future<List<Matiere>> matieres(String faculteId) async {
    final lignes = await supabase
        .from('subjects')
        .select('id, name, faculty_id')
        .eq('faculty_id', faculteId)
        .order('name');

    return _garder(lignes, Matiere.depuis);
  }

  /// Dépose un cours : préparation, envoi direct au stockage, confirmation.
  ///
  /// Le fichier ne traverse pas nos fonctions — 25 Mo dépasseraient la charge
  /// utile d'une fonction serverless. L'empreinte SHA-256 est calculée **ici**
  /// : c'est elle qui permet au serveur de retrouver un cours déjà traité par
  /// quelqu'un de la même faculté, et donc de ne rien repayer (règle 4).
  ///
  /// En cas d'échec d'envoi, la préparation est annulée : sans cela
  /// l'empreinte resterait prise par `unique (owner_id, file_hash)`, et le
  /// même document ne pourrait plus jamais être redéposé.
  Future<Reponse<String>> deposer({
    required ApiReviz api,
    required DocumentChoisi document,
    required String matiereId,
    required String titre,
    DateTime? dateExamen,
    void Function(double part)? progression,
  }) async {
    final empreinte = sha256.convert(document.octets).toString();

    final prepare = await api.poster<DepotCoursPrepare>(
      '/api/cours/preparer',
      corps: {
        'fileHash': empreinte,
        'subjectId': matiereId,
        'title': titre,
        'mime': document.typeMime,
        'taille': document.octets.length,
        'examDate': ?_jour(dateExamen),
      },
      depuis: DepotCoursPrepare.depuis,
    );

    if (prepare case ReponseEchec(:final erreur, :final motif)) {
      return Reponse.echec(erreur, motif: motif);
    }

    final depot = (prepare as ReponseSucces<DepotCoursPrepare>).data;

    final echec = await api.televerser(
      url: depot.urlEnvoi,
      octets: document.octets,
      typeMime: document.typeMime,
      progression: (envoyes, total) =>
          progression?.call(total <= 0 ? 0 : envoyes / total),
    );

    if (echec != null) {
      await annuler(api, depot.coursId);
      return Reponse.echec(echec, motif: 'envoi');
    }

    final confirme = await api.poster<String>(
      '/api/cours/confirmer',
      corps: {'courseId': depot.coursId},
      depuis: (data) => data['courseId'] as String,
    );

    if (confirme case ReponseEchec(:final erreur, :final motif)) {
      // Le fichier est arrivé : on ne supprime pas la ligne, le cours pourra
      // être relancé.
      return Reponse.echec(erreur, motif: motif);
    }

    return Reponse.succes(depot.coursId);
  }

  /// Renonce à une préparation. Silencieux : c'est un nettoyage.
  Future<void> annuler(ApiReviz api, String coursId) async {
    await api.poster<bool>(
      '/api/cours/annuler',
      corps: {'courseId': coursId},
      depuis: (_) => true,
    );
  }

  /// `AAAA-MM-JJ`, ce que le schéma du serveur attend.
  static String? _jour(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';

  Future<Reponse<ResultatSession>> terminerSession({
    required ApiReviz api,
    required String coursId,
    required List<({String questionId, String? choix})> reponses,
  }) {
    return api.poster<ResultatSession>(
      '/api/session/terminer',
      corps: {
        'courseId': coursId,
        'reponses': [
          for (final r in reponses)
            {'questionId': r.questionId, 'choix': r.choix},
        ],
      },
      depuis: ResultatSession.depuis,
    );
  }
}

// ---------------------------------------------------------------- Fiches

class DepotFiches {
  const DepotFiches();

  /// Les fiches d'un cours, chapitre par chapitre.
  ///
  /// Le paquet entier arrive d'un coup : quelques dizaines de fiches pèsent
  /// moins qu'un aller-retour par fiche, et l'étudiant qui révise dans un
  /// amphi sans réseau peut finir son paquet.
  Future<List<Fiche>> duCours(String coursId) async {
    final lignes = await supabase
        .from('flashcards')
        .select('id, front, back, chapters!inner(title, index, course_id)')
        .eq('chapters.course_id', coursId)
        .order('id');

    return _garder(lignes, Fiche.depuis);
  }
}

// -------------------------------------------------------------- Boutique

class DonneesBoutique {
  const DonneesBoutique({required this.packs, required this.abonnements});

  final List<PackBoutique> packs;
  final List<LigneAbonnement> abonnements;

  /// L'état d'accès, calculé par la logique portée et testée.
  EtatAcces get acces => etatAcces([
    for (final a in abonnements)
      Abonnement(
        code: CodePack.depuisSql(a.code) ?? CodePack.decouverte,
        debut: a.debut,
        fin: a.fin,
        correctionsRestantes: a.correctionsRestantes,
        plafondMatieres: a.plafondMatieres,
      ),
  ]);

  /// Découverte est une fois pour toutes : le bouton doit le dire avant le
  /// clic, pas après le refus du serveur.
  bool get decouverteUtilisee =>
      abonnements.any((a) => a.code == CodePack.decouverte.sql);
}

class DepotBoutique {
  const DepotBoutique();

  Future<DonneesBoutique> charger() async {
    final resultats = await Future.wait<dynamic>([
      Future<dynamic>.value(
        supabase
            .from('packs')
            .select(
              'code, label, description, price_fcfa, duration_days, '
              'corrections_included, subjects_limit',
            )
            .order('price_fcfa'),
      ),
      Future<dynamic>.value(
        supabase
            .from('subscriptions')
            .select(
              'pack_code, starts_at, ends_at, corrections_left, '
              'packs(subjects_limit)',
            ),
      ),
    ]);

    return DonneesBoutique(
      packs: _garder(resultats[0] as List? ?? const [], PackBoutique.depuis),
      abonnements: _garder(
        resultats[1] as List? ?? const [],
        LigneAbonnement.depuis,
      ),
    );
  }

  /// Le seul pack à 0 F : pas de fournisseur de paiement, donc activable
  /// tout de suite. Les packs payants attendent FedaPay.
  Future<Reponse<bool>> activerDecouverte(ApiReviz api) {
    return api.poster<bool>(
      '/api/packs/decouverte',
      depuis: (data) => data['active'] as bool? ?? true,
    );
  }

  /// Ouvre un paiement FedaPay pour un pack. Le prix vient de la base, côté
  /// serveur : l'application n'envoie que le code.
  Future<Reponse<PaiementOuvert>> ouvrirPaiement(
    ApiReviz api,
    String codePack,
  ) {
    return api.poster<PaiementOuvert>(
      '/api/payments/init',
      corps: {'packCode': codePack},
      depuis: (data) => PaiementOuvert(
        id: data['paiementId'] as String,
        url: data['redirectUrl'] as String,
      ),
    );
  }

  /// Où en est ce paiement : `pending`, `success` ou `failed`.
  ///
  /// Le serveur, tant que c'est `pending`, relit la transaction chez FedaPay :
  /// interroger ici suffit à activer le pack même si le webhook s'est perdu.
  Future<Reponse<String>> suivrePaiement(ApiReviz api, String id) {
    return api.obtenir<String>(
      '/api/payments/status?id=${Uri.encodeQueryComponent(id)}',
      depuis: (data) => data['status'] as String? ?? 'pending',
    );
  }
}

/// Un paiement ouvert : son identifiant chez Reviz, et la page FedaPay.
class PaiementOuvert {
  const PaiementOuvert({required this.id, required this.url});

  final String id;
  final String url;
}

// ----------------------------------------------------------------- Gains

class DepotGains {
  const DepotGains();

  Future<DonneesGains> charger() async {
    final profil = await const DepotProfil().mien();

    final resultats = await Future.wait<dynamic>([
      Future<dynamic>.value(supabase.rpc('wallet_balance')),
      Future<dynamic>.value(
        supabase.from('referrals').select('referred_id, first_payment_at'),
      ),
    ]);

    final parrainages = (resultats[1] as List? ?? const [])
        .whereType<Map>()
        .toList();

    return DonneesGains(
      soldeFcfa: (resultats[0] as num?)?.toInt() ?? 0,
      codeParrain: profil?.codeParrain,
      filleuls: parrainages.length,
      filleulsPayants: parrainages
          .where((p) => p['first_payment_at'] != null)
          .length,
    );
  }

  /// Demande de retrait — par la route : `withdrawals` n'a aucune politique
  /// d'insertion, et le solde est revérifié côté serveur.
  Future<Reponse<String>> demanderRetrait({
    required ApiReviz api,
    required int montantFcfa,
    required String operateur,
    required String telephone,
  }) {
    return api.poster<String>(
      '/api/wallet/withdrawal',
      corps: {
        'amount_fcfa': montantFcfa,
        'operator': operateur,
        'phone': telephone,
      },
      // Cette route était antérieure à la phase 1 : elle ne lisait pas
      // l'en-tête `Authorization`, rendait `{ ok, withdrawal_id }` au lieu de
      // l'enveloppe commune, et renvoyait `insufficient_balance` en anglais
      // à l'étudiant. Les trois ont été corrigés avec cet écran ; le message
      // d'erreur arrive donc prêt à afficher.
      depuis: (data) => (data['id'] as String?) ?? '',
    );
  }
}

// ------------------------------------------------------------ Classement

class DonneesClassement {
  const DonneesClassement({required this.lignes, required this.monRang});

  final List<LigneClassement> lignes;

  /// `null` si l'étudiant n'a pas encore marqué de point.
  final int? monRang;
}

class DepotClassement {
  const DepotClassement();

  /// Le classement de sa faculté.
  ///
  /// Par une fonction `SECURITY DEFINER` étroite, et non en lisant
  /// `profiles` : la politique n'autorise que sa propre ligne, et les profils
  /// portent le téléphone et l'empreinte de carte étudiante. La fonction ne
  /// rend aucun identifiant — « c'est toi » se lit sur `est_moi`.
  Future<DonneesClassement> charger({int limite = 20}) async {
    final resultats = await Future.wait<dynamic>([
      Future<dynamic>.value(
        supabase.rpc('classement_faculte', params: {'limite': limite}),
      ),
      Future<dynamic>.value(supabase.rpc('mon_rang_faculte')),
    ]);

    return DonneesClassement(
      lignes: _garder(
        resultats[0] as List? ?? const [],
        LigneClassement.depuis,
      ),
      monRang: (resultats[1] as num?)?.toInt(),
    );
  }
}


// ------------------------------------------------------------ Corrections

/// Ce que le dépôt d'une copie peut refuser, traduit côté écran.
typedef EchecDepot = ({String message, String? motif});

class DepotCorrections {
  const DepotCorrections();

  /// L'historique des corrections, lecture directe.
  ///
  /// La politique « Je lis mes corrections » filtre déjà sur `auth.uid()` :
  /// aucune route n'est nécessaire pour lire sa propre liste.
  Future<List<Correction>> mes({int limite = 20}) async {
    final lignes = await supabase
        .from('corrections')
        .select(
          'id, course_id, status, grade, max_grade, rubric, feedback, '
          'model_used, created_at',
        )
        .order('created_at', ascending: false)
        .limit(limite);

    return _garder(lignes, Correction.depuis);
  }

  /// Une correction, **par la route**.
  ///
  /// Et non en direct, bien que la RLS l'autoriserait : la route relance le
  /// traitement quand un réessai attend, si bien que l'attente de l'étudiant
  /// devient le moteur des reprises (voir `lib/jobs/immediat.ts`).
  Future<Reponse<Correction>> une(ApiReviz api, String id) {
    return api.obtenir<Correction>(
      '/api/corrections/$id',
      depuis: (data) {
        final lue = Correction.depuis(data);
        if (lue == null) {
          throw StateError('Correction illisible dans la réponse.');
        }
        return lue;
      },
    );
  }

  /// Dépose une copie : préparation, envoi direct au stockage, confirmation.
  ///
  /// Trois étapes et non une, parce que le fichier ne traverse pas nos
  /// fonctions — une photo de copie dépasse les 4,5 Mo de charge utile d'une
  /// fonction serverless (docs/API.md). En cas d'échec d'envoi, la
  /// préparation est annulée : sans cela, une coupure consommerait une des
  /// cinq corrections du jour sans que rien ne soit corrigé.
  Future<Reponse<String>> deposer({
    required ApiReviz api,
    required List<FichierAEnvoyer> fichiers,
    String? coursId,
    void Function(double part)? progression,
  }) async {
    final copie = fichiers.firstWhere((f) => f.champ == 'copie');
    final sujet = fichiers.where((f) => f.champ == 'sujet').firstOrNull;

    final prepare = await api.poster<DepotPrepare>(
      '/api/corrections/preparer',
      corps: {
        'copie': copie.description,
        if (sujet != null) 'sujet': sujet.description,
        'courseId': ?coursId,
      },
      depuis: DepotPrepare.depuis,
    );

    if (prepare case ReponseEchec(:final erreur, :final motif)) {
      return Reponse.echec(erreur, motif: motif);
    }

    final depot = (prepare as ReponseSucces<DepotPrepare>).data;

    // Un seul compteur pour les deux fichiers : l'étudiant voit une barre,
    // pas deux.
    final total = fichiers.fold<int>(0, (t, f) => t + f.octets.length);
    var deja = 0;

    for (final envoi in depot.envois) {
      final fichier = fichiers.firstWhere((f) => f.champ == envoi.champ);
      final avant = deja;

      final echec = await api.televerser(
        url: envoi.url,
        octets: fichier.octets,
        typeMime: fichier.typeMime,
        progression: total == 0
            ? null
            : (envoyes, _) => progression?.call((avant + envoyes) / total),
      );

      if (echec != null) {
        await annuler(api, depot.correctionId);
        return Reponse.echec(echec, motif: 'envoi');
      }

      deja += fichier.octets.length;
      progression?.call(total == 0 ? 1 : deja / total);
    }

    final confirme = await api.poster<String>(
      '/api/corrections/confirmer',
      corps: {'correctionId': depot.correctionId},
      depuis: (data) => data['correctionId'] as String,
    );

    if (confirme case ReponseEchec(:final erreur, :final motif)) {
      // La copie est arrivée mais le traitement n'a pas démarré : on ne
      // supprime pas la ligne, l'étudiant pourra réessayer.
      return Reponse.echec(erreur, motif: motif);
    }

    return Reponse.succes(depot.correctionId);
  }

  /// Renonce à une préparation. Silencieux : c'est un nettoyage.
  Future<void> annuler(ApiReviz api, String correctionId) async {
    await api.poster<bool>(
      '/api/corrections/annuler',
      corps: {'correctionId': correctionId},
      depuis: (data) => data['annule'] as bool? ?? true,
    );
  }
}
