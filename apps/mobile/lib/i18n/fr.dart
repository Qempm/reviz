/// Textes d'interface.
///
/// Port de `lib/i18n/fr.ts`, **section par section, au fur et à mesure des
/// écrans**. Ce n'est pas de la paresse : le dépôt web compte déjà huit
/// composants que seul son kitchen-sink consomme et une couche IA de
/// 979 lignes que personne n'appelle. Porter quatre cents lignes de chaînes
/// qu'aucun écran n'affiche encore créerait la même dette, et elles
/// divergeraient en silence.
library;

abstract final class Fr {
  static const commun = _Commun();
  static const connexion = _Connexion();
  static const inscription = _Inscription();
  static const tableauDeBord = _TableauDeBord();
  static const reviser = _Reviser();
  static const cours = _Cours();
  static const session = _Session();
  static const fiches = _Fiches();
  static const boutique = _Boutique();
  static const gains = _Gains();
  static const classement = _Classement();
  static const profil = _Profil();
  static const correction = _Correction();
  static const suppression = _Suppression();
  static const miseAJour = _MiseAJour();
  static const avatar = _Avatar();
  static const carte = _Carte();
  static const aide = _Aide();
  static const mascotte = _Mascotte();
  static const depot = _Depot();
  static const erreurs = _Erreurs();
}

/// Ce que dit un lecteur d'écran à la place du panthéreau.
class _Mascotte {
  const _Mascotte();

  final String salut = 'Le panthéreau Reviz te fait signe';
  final String bravo = 'Le panthéreau Reviz saute de joie';
  final String courage = 'Le panthéreau Reviz t’encourage';
  final String champion = 'Le panthéreau Reviz porte une couronne';
  final String reflexion = 'Le panthéreau Reviz lit un livre';
  final String dodo = 'Le panthéreau Reviz dort';
  final String curieux = 'Le panthéreau Reviz regarde à la loupe';
}

class _Fiches {
  const _Fiches();

  final String titre = 'Les fiches';
  final String sousTitre = 'Touche une fiche pour voir la réponse.';
  final String aucune = 'Aucune fiche';
  final String aucuneDetail =
      'Les fiches arrivent en même temps que les questions.';

  String position(int i, int total) => 'Fiche $i sur $total';
  final String recto = 'Question';
  final String verso = 'Réponse';
  final String precedente = 'Précédente';
  final String suivante = 'Suivante';
  final String terminee = 'Tu as vu toutes les fiches';
  final String recommencer = 'Recommencer';
  final String voirFiches = 'Voir les fiches';
}

class _Boutique {
  const _Boutique();

  final String titre = 'Les packs';
  final String sousTitre =
      'Tu paies une fois, pour une durée précise. Rien ne se renouvelle.';
  final String recommande = 'Conseillé';
  final String gratuit = 'Gratuit';

  String duree(int j) => j <= 1 ? '$j jour d’accès' : '$j jours d’accès';

  String corrections(int n) => n == 0
      ? 'Aucune correction incluse'
      : n <= 1
      ? '$n correction de copie'
      : '$n corrections de copie';

  String matieres(int? n) => n == null
      ? 'Toutes tes matières'
      : n <= 1
      ? '$n matière'
      : '$n matières';

  final String choisir = 'Choisir ce pack';
  final String activerDecouverte = 'Activer gratuitement';
  final String decouverteUtilisee = 'Découverte déjà utilisée';
  final String paiementBientot = 'Paiement Mobile Money bientôt disponible';
  final String activationImpossible =
      'L’activation n’a pas abouti. Réessaie dans un instant.';

  String accesActif(int j) => j <= 1
      ? 'Ton accès finit aujourd’hui'
      : 'Accès actif encore $j jours';

  String correctionsRestantes(int n) => n == 0
      ? 'Plus de correction disponible'
      : n <= 1
      ? '$n correction restante'
      : '$n corrections restantes';

  final String accesExpire = 'Ton pack est arrivé à terme';
  final String accesExpireDetail =
      'Tes cours et ton historique restent consultables. Réactive pour '
      'générer de nouveau.';
  final String sansReconduction =
      'Aucun prélèvement automatique. À la fin de la période, l’accès '
      's’arrête, tout simplement.';
}

class _Gains {
  const _Gains();

  final String titre = 'Mes gains';
  final String solde = 'Solde disponible';
  final String retraitPossible = 'Tu peux demander un retrait.';

  String resteAvantRetrait(int n) =>
      'Encore $n F avant de pouvoir retirer.';

  final String tonCode = 'Ton code parrain';
  final String aideCode =
      'Partage-le : tu touches 25 % de chaque paiement de tes filleuls '
      'pendant 12 mois.';
  final String copier = 'Copier';
  final String copie = 'Code copié';
  final String partager = 'Partager sur WhatsApp';

  String messagePartage(String code) =>
      'Rejoins-moi sur Reviz pour réviser : utilise mon code $code.';

  final String aucunFilleul = 'Aucun filleul pour l’instant';
  final String aucunFilleulDetail =
      'Un filleul compte dès qu’il est vérifié et qu’il a payé une première '
      'fois.';

  String filleulsPayants(int n) =>
      n <= 1 ? '$n filleul actif' : '$n filleuls actifs';

  String filleulsTotal(int n) =>
      n <= 1 ? '$n filleul inscrit' : '$n filleuls inscrits';

  final String demanderRetrait = 'Demander un retrait';
  final String voirClassement = 'Voir le classement';

  // --- Demande de retrait
  //
  // Les messages sont en français et disent quoi faire : l'écran web affiche
  // aujourd'hui `insufficient_balance` tel quel à l'étudiant (rapport
  // § 4.14).

  final String titreRetrait = 'Retirer mes gains';
  final String montant = 'Montant à retirer';

  String aideMontant(int seuil) =>
      'Minimum $seuil F. Le versement arrive sur ton Mobile Money.';

  final String operateur = 'Opérateur';
  final String choisirOperateur = 'Choisis ton opérateur';
  final String telephone = 'Numéro Mobile Money';
  final String aideTelephone = 'Le numéro qui recevra l’argent.';
  final String envoyerDemande = 'Envoyer la demande';
  final String demandeEnvoyee =
      'Demande envoyée. Le versement arrive sous 48 h ouvrées.';
  final String demandeImpossible =
      'La demande n’a pas abouti. Réessaie dans un instant.';
  final String montantInvalide = 'Indique un montant en chiffres.';
  final String telephoneInvalide = 'Ce numéro ne ressemble pas à un numéro.';

  String soldeInsuffisant(int solde) => 'Ton solde est de $solde F.';

  String sousLeSeuil(int seuil) => 'Le retrait minimum est de $seuil F.';
}

class _Classement {
  const _Classement();

  final String titre = 'Le classement';
  final String sousTitre = 'Ta faculté, par expérience gagnée.';
  final String toi = 'Toi';

  String monRang(int r) => 'Tu es $rᵉ de ta faculté';
  final String premier =
      'Tu es n° 1 de ta faculté. Personne ne fait mieux !';
  final String nonClasse = 'Réponds à une question pour entrer au classement';
  final String aucun = 'Personne n’est encore classé';
  final String aucunDetail =
      'Sois le premier de ta faculté à marquer des points.';

  String xp(int n) => '$n XP';
}

class _Profil {
  const _Profil();

  final String titre = 'Mon profil';
  final String verifie = 'Compte vérifié';
  final String verifieDetail = 'Ta carte étudiante a été validée.';
  final String nonVerifie = 'Compte non vérifié';
  final String nonVerifieDetail =
      'Ajoute ta carte étudiante pour débloquer le parrainage et les cours '
      'partagés.';
  final String voirLesPacks = 'Les packs et mon accès';
  final String deconnexion = 'Me déconnecter';
  final String animationsReduites = 'Réduire les animations';
  final String animationsReduitesAide =
      'Moins de mouvement, un peu moins de batterie.';

  final String verificationEnCours = 'Vérification en cours';
  final String verificationEnCoursDetail =
      'On regarde ta carte étudiante. Ça prend quelques heures.';
  final String ajouterCarte = 'Ajouter ma carte étudiante';

  String annee(int n) => n <= 1 ? '${n}re année' : '${n}e année';

  final String mesChiffres = 'Mes chiffres';

  String xp(int n) => '$n XP gagnés';

  String serie(int n) =>
      n <= 1 ? 'Meilleure série : $n jour' : 'Meilleure série : $n jours';

  final String reglages = 'Réglages';
  final String changerAvatar = 'Changer mon avatar';
  final String aide = 'Aide et contact';
  final String confirmerDeconnexion = 'Te déconnecter de Reviz ?';
  final String confirmerDeconnexionDetail =
      'Tes cours et ta progression restent en place.';
}

class _Correction {
  const _Correction();

  final String titre = 'Corriger ma copie';
  final String sousTitre =
      'Photographie ta copie. On te rend une note, un barème détaillé et ce '
      'qu’il faut retravailler.';

  // --- Choix de la photo
  final String prendrePhoto = 'Prendre ma copie en photo';
  final String choisirGalerie = 'Choisir dans mes photos';
  final String reprendrePhoto = 'Reprendre la photo';
  final String copie = 'Ta copie';
  final String sujet = 'Le sujet';
  final String sujetFacultatif = 'Ajouter le sujet (facultatif)';
  final String aideSujet =
      'Avec le sujet, la correction sait ce qui était demandé.';
  final String retirerSujet = 'Retirer le sujet';
  final String envoyer = 'Envoyer pour correction';
  final String conseilPhoto =
      'Une photo bien éclairée, à plat, sans ombre sur le texte.';

  // --- Ce qui reste
  String restantes(int n) => n <= 1
      ? '$n correction restante dans ton pack'
      : '$n corrections restantes dans ton pack';

  String duJour(int faites, int max) => 'Aujourd’hui : $faites sur $max';

  final String aucunPack =
      'Il te faut un pack actif pour faire corriger une copie.';
  final String packExpire =
      'Ton pack est arrivé à terme. Réactive-le pour continuer.';
  final String creditEpuise = 'Tu n’as plus de correction dans ton pack.';
  final String plafondJournalier =
      'Tu as atteint les 5 corrections du jour. Reviens demain.';
  final String voirLesPacks = 'Voir les packs';

  // --- Envoi
  final String envoiEnCours = 'Envoi de ta copie…';
  String envoiPourcent(int p) => 'Envoi de ta copie… $p %';
  final String envoiEchoue = 'L’envoi n’a pas abouti. Réessaie.';

  // --- Attente
  final String enCours = 'On corrige ta copie';
  final String enCoursDetail =
      'Compte une à deux minutes. Tu peux fermer l’application, on garde le '
      'résultat.';
  final String plusLongQuePrevu = 'C’est plus long que prévu';
  final String plusLongQuePrevuDetail =
      'La correction est toujours en cours. Reviens dans un instant.';
  final String actualiser = 'Actualiser';

  // --- Résultat
  String note(String note, String bareme) => '$note / $bareme';
  final String leBareme = 'Le barème';
  final String pointsForts = 'Ce qui va';
  final String aTravailler = 'À retravailler';
  final String bravo = 'Beau travail';
  final String presque = 'Tu y es presque';
  final String aRevoir = 'Il faut reprendre ça';

  String lignePoints(String points, String maximum) => '$points / $maximum';

  final String corrigePar = 'Corrigé par';

  // --- Illisible et échec
  final String illisible = 'On n’arrive pas à lire ta copie';
  final String echec = 'La correction n’a pas abouti';
  final String echecDetail =
      'Rien ne t’a été décompté. Reprends la photo, ou réessaie plus tard.';

  // --- Historique
  final String historique = 'Mes corrections';
  final String aucune = 'Aucune copie corrigée';
  final String aucuneDetail =
      'Photographie ta première copie : la correction arrive en une à deux '
      'minutes.';
  final String voirLaCorrection = 'Voir la correction';
  final String enAttente = 'En cours de correction';
}

class _Suppression {
  const _Suppression();

  final String titre = 'Supprimer mon compte';
  final String entree = 'Supprimer mon compte';

  final String avertissement =
      'C’est définitif. On ne pourra pas revenir en arrière.';

  final String cePartTitre = 'Ce qui est effacé';
  final List<String> cePart = const [
    'Ton prénom, ton numéro et ta photo de carte étudiante',
    'Ton université, ta filière et ton année',
    'Tes cours déposés, avec leurs questions et leurs fiches',
    'Tes réponses et ta progression',
    'Tes copies corrigées',
    'Ton code de parrainage et tes filleuls',
  ];

  final String celaResteTitre = 'Ce qui reste, sans ton nom';
  final List<String> celaReste = const [
    'Tes paiements et les lignes de ton portefeuille',
    'Tes demandes de retrait',
  ];

  final String pourquoiReste =
      'La comptabilité est un registre qu’on n’efface pas. Ces lignes '
      'gardent leurs montants, plus aucune ne porte ton identité.';

  final String soldeEnJeu = 'Tu as encore un solde';

  String soldeEnJeuDetail(int solde) =>
      'Il te reste $solde F dans ton portefeuille. Demande ton retrait '
      'avant de partir : après, on ne saura plus à qui verser.';

  final String demanderRetrait = 'Voir mes gains';

  final String confirmation = 'Pour confirmer, écris ton prénom';
  String aideConfirmation(String prenom) => 'Écris exactement « $prenom ».';
  final String prenomIncorrect = 'Ce n’est pas ton prénom.';
  final String prenomAbsent =
      'Ton compte n’a pas de prénom. Écris SUPPRIMER pour confirmer.';
  final String motSansPrenom = 'SUPPRIMER';

  final String supprimer = 'Supprimer définitivement';
  final String enCours = 'Suppression en cours…';
  final String echec =
      'La suppression n’a pas abouti. Réessaie dans un instant.';
  final String faite = 'Ton compte a été supprimé.';
}

class _MiseAJour {
  const _MiseAJour();

  // --- Réseau
  final String horsLigne = 'Pas de connexion';
  final String horsLigneDetail =
      'Tes QCM déjà chargés restent jouables. Le reste attendra le réseau.';

  // --- Mise à jour conseillée
  final String conseillee = 'Une nouvelle version est là';
  final String telecharger = 'Télécharger';
  final String plusTard = 'Plus tard';

  // --- Mise à jour exigée
  final String exigee = 'Il faut mettre Reviz à jour';
  final String exigeeDetail =
      'Cette version ne peut plus fonctionner avec nos serveurs. La mise à '
      'jour prend moins d’une minute.';

  // --- Maintenance
  final String maintenance = 'Reviz est en entretien';
  final String maintenanceDetail =
      'On répare quelque chose. Reviens dans quelques minutes — rien de ce '
      'que tu as fait n’est perdu.';

  String versionInstallee(String v) => 'Version installée : $v';
  final String reessayer = 'Réessayer';
  final String lienIndisponible =
      'Le lien de téléchargement n’est pas disponible. Demande-le sur '
      'WhatsApp.';
}

class _Aide {
  const _Aide();

  final String titre = 'Aide et contact';
  final String sousTitre =
      'Les questions qu’on nous pose le plus. Si la tienne n’y est pas, '
      'écris-nous.';

  /// Les questions, dans l'ordre où elles se posent vraiment : l'argent
  /// d'abord, parce que c'est ce qui inquiète avant de payer.
  final List<(String, String)> questions = const [
    (
      'Est-ce que je serai prélevé chaque mois ?',
      'Non. Jamais. Tu paies un pack une fois, il dure le nombre de jours '
          'annoncé, et il s’arrête. Il n’y a aucun abonnement automatique et '
          'rien à résilier. À la fin, tes cours et ton historique restent '
          'lisibles ; pour refaire des QCM, tu reprends un pack.',
    ),
    (
      'Pourquoi vous demandez ma carte étudiante ?',
      'Pour qu’un compte corresponde à une personne. Sans elle, quelqu’un '
          'pourrait ouvrir dix comptes, se parrainer lui-même et encaisser la '
          'commission sur ses propres paiements. La photo sert à lire ton '
          'numéro d’étudiant, et une carte ne vaut que pour un seul compte.',
    ),
    (
      'Comment marche le parrainage ?',
      'Tu donnes ton code. Quand ton filleul paie un pack, 25 % du montant '
          'vont dans ton portefeuille — 35 % si tu es ambassadeur —, et cela '
          'pendant douze mois à chacun de ses paiements. Un filleul ne compte '
          'que s’il est vérifié et qu’il a payé au moins une fois. Le retrait '
          'part en Mobile Money dès 3 000 F.',
    ),
    (
      'Ça marche sans réseau ?',
      'Les QCM déjà chargés, oui : tu peux réviser dans un endroit sans 3G. '
          'Il faut du réseau pour déposer un cours, faire corriger une copie '
          'et enregistrer tes réponses — un bandeau te prévient quand la '
          'connexion tombe.',
    ),
    (
      'Mon cours reste « en préparation », c’est normal ?',
      'Reste sur la page du cours : c’est en restant là que la préparation '
          'avance, chapitre par chapitre. Un document de cent pages demande '
          'quelques minutes. Si tu fermes l’application, le reste se fera '
          'plus tard dans la nuit.',
    ),
    (
      'Ma note de correction me paraît fausse.',
      'Elle est donnée par une IA qui lit ta photo : une écriture serrée ou '
          'une page mal éclairée peuvent lui faire manquer des lignes. '
          'Reprends la photo à plat et bien éclairée. Et écris-nous : une '
          'note clairement à côté nous sert à corriger le barème.',
    ),
    (
      'Je veux supprimer mon compte.',
      'Profil → Supprimer mon compte. Ton nom, ton numéro et tes cours '
          'partent ; tes paiements restent en comptabilité, sans ton nom '
          'dessus, parce qu’un registre financier ne se réécrit pas. '
          'L’écran te dit exactement ce qui part et ce qui reste.',
    ),
  ];

  final String contactTitre = 'Nous écrire';
  final String contactDetail =
      'On répond sur WhatsApp, en français, dans la journée.';
  final String contactBouton = 'Écrire sur WhatsApp';
  final String contactMessage =
      'Bonjour, j’ai une question sur Reviz : ';
  final String contactAbsent =
      'Le numéro du support n’est pas encore dans cette version de '
      'l’application. En attendant, passe par la personne qui t’a partagé '
      'Reviz.';

  final String versionTitre = 'Cette version';
}

class _Carte {
  const _Carte();

  final String titre = 'Ma carte étudiante';
  final String sousTitre =
      'Une photo de ta carte, et ton compte est vérifié. C’est ce qui ouvre '
      'le parrainage et les cours partagés de ta faculté.';

  final String prendrePhoto = 'Prendre la photo';
  final String choisirGalerie = 'Choisir dans mes photos';
  final String reprendre = 'Reprendre la photo';
  final String envoyer = 'Envoyer ma carte';

  final String conseil =
      'À plat, bien éclairée, sans reflet sur le plastique. Le numéro '
      'd’étudiant doit être net : c’est lui qu’on lit.';

  String envoiPourcent(int p) => 'Envoi de ta carte… $p %';
  final String lecture = 'On lit ta carte…';
  final String lectureDetail =
      'Ça prend moins d’une minute. Tu peux rester là.';

  final String verifie = 'C’est vérifié';
  final String verifieDetail =
      'Ton compte est vérifié. Le parrainage et les cours partagés sont '
      'ouverts.';

  final String enAttente = 'On regarde ta carte';
  final String enAttenteDetail =
      'La lecture automatique n’a pas suffi. Quelqu’un va la regarder — tu '
      'n’as rien à refaire.';

  final String refusee = 'Carte non validée';
  final String refuseeDetail =
      'Reprends la photo à plat et bien éclairée, ou écris-nous si ta carte '
      'est déjà utilisée sur un autre compte.';

  final String uneSeuleFois =
      'Une carte ne vaut que pour un seul compte : c’est ce qui empêche '
      'quelqu’un de se parrainer lui-même.';

  final String echec =
      'On n’a pas pu envoyer ta carte. Réessaie dans un instant.';
  final String retour = 'Revenir à mon profil';
}

class _Avatar {
  const _Avatar();

  final String titre = 'Mon avatar';
  final String sousTitre =
      'Choisis ton animal. C’est lui que voit ta faculté au classement.';
  final String apercu = 'Aperçu';
  final String enregistrer = 'Garder celui-là';
  final String enregistre = 'C’est enregistré';
  final String echec =
      'On n’a pas pu enregistrer ton avatar. Réessaie dans un instant.';
  final String desImages =
      'Douze animaux, 74 ko en tout : ils sont dans l’application, donc ils '
      's’affichent même sans réseau.';
}

class _Depot {
  const _Depot();

  final String titre = 'Ajouter un cours';
  final String sousTitre =
      'Dépose un PDF, un Word ou une photo. Reviz le découpe en chapitres et '
      'en tire des questions.';

  // --- Le fichier
  final String choisirFichier = 'Choisir un fichier';
  final String prendrePhoto = 'Prendre en photo';
  final String changerFichier = 'Changer de fichier';
  final String formatsAcceptes = 'PDF, Word (.docx) ou photo, 25 Mo au plus.';
  final String docRefuse =
      'Les anciens fichiers Word (.doc) ne sont pas lisibles. Enregistre-le '
      'en PDF et réessaie.';
  final String tropGros = 'Ce fichier dépasse 25 Mo.';
  final String formatRefuse = 'On ne sait pas lire ce type de fichier.';

  // --- Les champs
  final String titreDuCours = 'Le titre du cours';
  final String aideTitre = 'C’est ce que tu verras dans ta liste.';
  final String matiere = 'La matière';
  final String choisirMatiere = 'Choisis la matière';
  final String aucuneMatiere =
      'Aucune matière pour ta faculté. Préviens-nous, on l’ajoute.';
  final String dateExamen = 'Date de l’examen (facultatif)';
  final String aideDateExamen =
      'Reviz s’en sert pour te dire ce qui va probablement tomber.';
  final String choisirDate = 'Choisir une date';
  final String retirerDate = 'Retirer la date';

  final String titreManquant = 'Donne un titre à ton cours.';
  final String matiereManquante = 'Choisis une matière.';

  // --- Envoi
  final String envoyer = 'Déposer ce cours';
  String envoiPourcent(int p) => 'Envoi… $p %';
  final String preparation = 'Préparation…';
  final String enTraitement = 'Reviz lit ton cours';
  final String enTraitementDetail =
      'Le découpage et les questions prennent une à deux minutes. Tu peux '
      'fermer, on garde tout.';

  // --- Refus du serveur
  final String aucunAcces =
      'Il te faut un pack actif pour déposer un cours.';
  final String accesExpire =
      'Ton pack est arrivé à terme. Réactive-le pour déposer.';

  String plafondMatieres(int? n) => n == null
      ? 'Tu as atteint le nombre de matières de ton pack.'
      : 'Ton pack couvre $n matière${n > 1 ? 's' : ''}. Choisis-en une que tu '
            'utilises déjà, ou passe à un pack plus large.';

  final String dejaDepose = 'Tu as déjà déposé ce document.';
  final String voirLeCours = 'Voir le cours';
  final String echec =
      'Le dépôt n’a pas abouti. Réessaie dans un instant.';
  final String voirLesPacks = 'Voir les packs';
}

class _Commun {
  const _Commun();

  final String continuer = 'Continuer';
  final String annuler = 'Annuler';
  final String reessayer = 'Réessayer';
  final String chargement = 'Un instant…';
  final String retour = 'Retour';
  final String voirTout = 'Tout voir';
  final String bientot = 'Bientôt disponible';
}

class _Connexion {
  const _Connexion();

  final String titre = 'Bienvenue sur Reviz';
  final String sousTitre =
      'Connecte-toi pour retrouver tes cours, tes QCM et tes corrections.';

  final String avecGoogle = 'Continuer avec Google';
  final String googleIndisponible =
      'La connexion Google n’est pas configurée dans cette version.';
  final String ou = 'ou';

  final String labelEmail = 'Ton email';
  final String aideEmail =
      'On t’envoie un code par mail. Pas de mot de passe à retenir.';
  final String recevoirCode = 'Recevoir mon code';

  final String titreCode = 'Le code';
  String sousTitreCode(String email) => 'On vient d’envoyer un code à $email.';
  final String codeAstuce =
      'Recopie ici les chiffres du mail. Si tu ne vois rien, regarde dans les '
      'indésirables.';
  final String valider = 'Valider';
  final String renvoyer = 'Renvoyer le code';
  String renvoyerDans(int s) => 'Nouveau code dans $s s';
  final String changerEmail = 'Ce n’est pas mon email';

  final String emailInvalide = 'Cette adresse ne ressemble pas à un email.';
  final String codeIncomplet = 'Il manque des chiffres du code.';
  final String codeInvalide =
      'Ce code ne marche pas. Vérifie, ou demandes-en un nouveau.';
  final String envoiImpossible =
      'On n’a pas pu envoyer le code. Vérifie ta connexion et réessaie.';

  // --- Échecs de la connexion Google
  //
  // Un message par motif, et pas un « erreur de connexion » unique : la
  // cause change complètement ce que l'étudiant doit faire. Une annulation
  // n'a pas de message du tout — il a choisi de renoncer.
  final String googleConfiguration =
      'La connexion Google n’est pas encore prête de notre côté. Utilise ton '
      'email pour l’instant, ça marche.';
  final String googleRefuse =
      'Google a répondu, mais notre serveur n’a pas accepté. On est prévenus. '
      'Utilise ton email en attendant.';
  final String googleInterrompu =
      'La connexion Google a été interrompue. Réessaie.';
  final String googleIndisponibleAppareil =
      'Ce téléphone n’a pas les services Google nécessaires. La connexion par '
      'email marche quand même.';
  final String googleAutreCompte =
      'Ce compte Google n’est pas celui connecté sur le téléphone. Change de '
      'compte dans les réglages Android, ou passe par ton email.';
  final String googleInconnu =
      'La connexion Google n’a pas marché. Passe par ton email.';
}

class _Inscription {
  const _Inscription();

  final String titre = 'On fait connaissance';
  final String sousTitre =
      'Ces informations servent à te proposer les bons cours et à te situer '
      'dans ta faculté.';
  final String labelPrenom = 'Ton prénom';
  final String labelUniversite = 'Ton université';
  final String labelFiliere = 'Ta filière';
  final String labelAnnee = 'Ton année';

  /// L1, L2… puis M1, M2 au-delà de la licence.
  String annee(int n) => n <= 3 ? 'L$n' : 'M${n - 3}';

  final String labelParrain = 'Code parrain (facultatif)';
  final String aideParrain =
      'Si un camarade t’a donné son code, il touche une commission.';
  final String terminer = 'Terminer mon inscription';
  final String choisirUniversite = 'Choisis ton université';
  final String choisirFiliere = 'Choisis ta filière';
}

class _TableauDeBord {
  const _TableauDeBord();

  String salutation(String prenom) => 'Bonjour $prenom'.trim();
  final String sousTitre = 'Prêt à réviser aujourd’hui ?';
  final String mesMatieres = 'Mes matières';
  final String pointFaible = 'À revoir';

  String questionsFaites(int n) =>
      n <= 1 ? '$n question répondue' : '$n questions répondues';

  final String aucuneMatiere = 'Aucune matière pour l’instant';
  final String aucuneMatiereDetail =
      'Ajoute ton premier cours et Reviz en tire des QCM et des fiches.';
  final String ajouterCours = 'Ajouter un cours';

  final String serieRompue =
      'Ta série s’est arrêtée. Une session aujourd’hui suffit à en relancer '
      'une.';

  String serieEnJeu(int reste) => reste <= 1
      ? 'Encore une question et ta série tient un jour de plus.'
      : 'Encore $reste questions et ta série tient un jour de plus.';

  String flamme(int jours) =>
      jours > 1 ? '$jours jours de flamme !' : '$jours jour de flamme !';
  final String lanceTaSerie = 'Lance ta série';
  String xpAujourdhui(int n) => '+$n XP aujourd’hui';
  String objectifDuJour(int faites, int but) =>
      '$faites / $but questions aujourd’hui';
}

class _Reviser {
  const _Reviser();

  final String titre = 'Réviser';
  final String sousTitre = 'Tes cours, tes QCM et tes fiches, au même endroit.';
  final String aucunCours = 'Aucun cours déposé';
  final String aucunCoursDetail =
      'Envoie un PDF, un Word ou des photos de ton cours. Reviz s’occupe du '
      'reste.';
  final String ajouterCours = 'Ajouter un cours';
  final String exemple = 'Exemple';
  final String enTraitement = 'En préparation';
  final String seulementDemo =
      'Ce cours est là pour te montrer le principe. Dépose le tien pour de '
      'vrai.';

  String decompte(int chapitres, int questions, int fiches) => [
    chapitres <= 1 ? '$chapitres chapitre' : '$chapitres chapitres',
    questions <= 1 ? '$questions question' : '$questions questions',
    fiches <= 1 ? '$fiches fiche' : '$fiches fiches',
  ].join(' · ');
}

class _Cours {
  const _Cours();

  final String traitementTitre = 'Ton cours est en préparation';
  final String traitementDetail =
      'Reviz lit ton document, le découpe en chapitres et en tire des '
      'questions.';
  // L'ancien texte disait « Tu peux fermer l'application : on te prévient
  // dès que c'est prêt. » — faux deux fois. Il n'y a pas de notification, et
  // surtout **c'est le fait de rester ici qui fait avancer la préparation** :
  // chaque interrogation de l'écran traite un chapitre. Fermer l'application
  // renvoie le reste au traitement de nuit.
  final String traitementAstuce =
      'Reste sur cet écran : la préparation avance pendant que tu attends. Si '
      'tu fermes, elle reprendra plus tard dans la nuit.';

  String traitementAvance(int chapitres, int questions) => chapitres == 0
      ? 'Lecture du document…'
      : '$chapitres ${chapitres == 1 ? 'chapitre' : 'chapitres'} · '
            '$questions ${questions == 1 ? 'question' : 'questions'}';
  final String echecTitre = 'On n’a pas réussi à lire ce cours';
  final String echecDetail =
      'Le document est peut-être trop flou ou protégé. Réessaie avec un autre '
      'fichier.';

  String progression(int faites, int total) => total == 0
      ? 'Aucune question pour l’instant'
      : '$faites question${faites <= 1 ? '' : 's'} sur $total';

  final String reviser = 'Lancer une session';
  final String chapitres = 'Les chapitres';
  final String aucunChapitre = 'Aucun chapitre';
  final String aucunChapitreDetail = 'Ce cours n’a pas encore été découpé.';

  String decompteChapitre(int questions, int fiches) =>
      '$questions question${questions <= 1 ? '' : 's'} · '
      '$fiches fiche${fiches <= 1 ? '' : 's'}';

  String jMoins(int j) => j == 0
      ? 'Examen aujourd’hui'
      : j == 1
      ? 'Examen demain'
      : 'J−$j';
  final String examenPasse = 'Examen passé';
}

class _Session {
  const _Session();

  final String valider = 'Valider';
  final String suivante = 'Question suivante';
  final String voirResultat = 'Voir mon résultat';
  final String juste = 'C’est juste';
  final String faux = 'Ce n’est pas ça';
  final String bonneReponse = 'La bonne réponse';
  final String probable = 'Souvent posée';

  String question(int i, int total) => 'Question $i sur $total';

  final String aucuneQuestion = 'Aucune question à réviser';
  final String aucuneQuestionDetail =
      'Ce cours n’a pas encore de QCM. Reviens quand la préparation est '
      'finie.';

  final String resultatTitre = 'Session terminée';
  String score(int bonnes, int total) => '$bonnes / $total';
  String precision(int pct) => '$pct % de réussite';
  String xpGagnes(int n) => '+$n XP';
  final String objectifAtteint = 'Objectif du jour atteint';
  String serie(int j) => j <= 1 ? 'Série lancée' : '$j jours de série';
  final String refaire = 'Refaire une session';
  final String retourCours = 'Retour au cours';

  final String echecEnregistrement =
      'On n’a pas pu enregistrer cette session. Ton score s’affiche quand '
      'même.';

  /// Libellés des motifs de `xp_events.reason`.
  final Map<String, String> detailXp = const {
    'correct_answer': 'Bonnes réponses',
    'quiz_completed': 'Session terminée',
    'daily_goal': 'Objectif du jour',
    'streak_bonus': 'Bonus de série',
    'course_added': 'Cours ajouté',
    'correction_done': 'Correction faite',
    'referral': 'Parrainage',
    'adjustment': 'Ajustement',
  };
}

/// Messages d'erreur destinés à l'étudiant.
///
/// Les routes REST renvoient déjà leur message en français : ceux-ci ne
/// servent qu'aux pannes que le client constate lui-même.
class _Erreurs {
  const _Erreurs();

  final String horsLigne =
      'Pas de connexion. Tes cours déjà chargés restent consultables.';
  final String sessionExpiree = 'Ta session a expiré. Reconnecte-toi.';
  final String inconnue = 'Quelque chose a coincé de notre côté. Réessaie.';
  final String chargementImpossible =
      'On n’a pas pu charger cette page. Réessaie.';

  /// Configuration absente au build — une erreur de développeur, pas
  /// d'étudiant, mais qui doit se lire quand elle arrive.
  String configurationManquante(List<String> variables) =>
      'Configuration incomplète : ${variables.join(', ')}. '
      'Voir apps/mobile/lib/donnees/config.dart.';
}
