# Les écrans de Reviz

`CLAUDE.md` annonçait ce fichier comme « la liste complète des 55 écrans ». Il
n'existait pas. Voici la liste réelle — celle des écrans qui tournent, et de
ceux qui manquent, avec ce qui les bloque.

Les écrans sont en Flutter (`apps/mobile/lib/ecrans/`). Le web ne garde que
deux pages publiques : l'accueil et le téléchargement (lot D).

---

## Les dix-sept qui tournent

Chemins définis dans `apps/mobile/lib/routage.dart`. Ils reprennent ceux du
web : un lien partagé par WhatsApp doit pouvoir ouvrir l'application comme il
ouvrait le site.

| Chemin | Écran | Ce qu'il fait |
| --- | --- | --- |
| `/connexion` | `connexion.dart` | Code à chiffres par e-mail, en deux temps. Le bouton Google est désactivé faute d'identifiants OAuth. |
| `/inscription` | `inscription.dart` | Prénom, université, filière (cherchées, ou ajoutées si absentes), année, numéro Mobile Money facultatif, code parrain. Passe par `POST /api/profil` — jamais d'insertion directe. |
| `/` | `accueil.dart` | Série de sept jours, objectif du jour, pack gratuit à un appui, carte « ta ligue », quatre matières. Reprogramme les rappels du téléphone. |
| `/reviser` | `reviser.dart` | Liste des cours, démonstration épinglée. |
| `/reviser/ajouter` | `ajouter_cours.dart` | Dépôt d'un PDF, d'un .docx ou d'une photo, par URL signée. Empreinte SHA-256 calculée sur l'appareil. |
| `/matiere/:id` | `matiere.dart` | Ouvert depuis « Mes matières » : illustration de la famille, maîtrise, chapitres à retravailler de tous les cours (« Reprendre »), cours de la matière, « Réviser cette matière ». |
| `/cours/:id` | `cours.dart` | Progression, puis le chemin des chapitres en zigzag : couronnes, verrous, panthéreau sur le chapitre en cours. |
| `/cours/:id/session` | `session.dart` | Dix questions (jamais vues, puis ratées, puis chapitres faibles), `?chapitre=` et `?mode=erreurs`. Barre de niveau, « Niveau supérieur ! », série gardée hors ligne. |
| `/cours/:id/fiches` | `fiches.dart` | Paquet retournable, une fiche à l'écran. |
| `/corriger` | `corriger.dart` | Jusqu'à quatre pages, cours pré-choisi, type d'épreuve, barème ; envoi par URL signée, historique. |
| `/corrections/:id` | `correction.dart` | Attente, note, barème ligne par ligne, notions manquées, « Réviser : chapitre », copie illisible, échec. |
| `/boutique` | `boutique.dart` | « Tu prépares quoi ? » : le pack conseillé en carte héros jaune (prix par jour, « Conseillé »), les autres en cartes compactes, Découverte à part, l'accès en cours. |
| `/gains` | `gains.dart` | Commissions suspendues (3 octobre 2026) : carte « gains en pause », code parrain à 500 XP, filleuls ; le solde et la feuille de retrait n'apparaissent que s'il reste un solde. Commissions actives : carte de déblocage sous 3 000 XP (hors ambassadeur), solde, code, filleuls, retrait. |
| `/classement` | `classement.dart` | Podium 2·1·3 et tableau, pour sa faculté. |
| `/ligue` | `ligue.dart` | Ligue de la semaine : division, compte à rebours, zones de montée et de descente, bilan de la semaine passée. Attend la migration `20260930130000_ligues.sql`. |
| `/profil` | `profil.dart` | Identité, vérification de carte, niveau, XP des sept jours en barres, meilleure série, réglages, déconnexion. |
| `/profil/avatar` | `avatar.dart` | Douze bustes d'animaux en peluche 3D, chacun sur son disque de couleur. |
| `/profil/supprimer-compte` | `suppression.dart` | Ce qui part, ce qui reste, confirmation par le prénom. |
| `/profil/carte-etudiante` | `carte.dart` | Photo de la carte, attente du verdict, issue. La seule barrière « un compte par personne ». |
| `/profil/aide` | `aide.dart` | Sept questions, l'argent en premier. Le contact WhatsApp n'apparaît que si `CONTACT_WHATSAPP` est passé au build. |
| `/galerie` | `galerie.dart` | Le kitchen-sink du design system. Public, sans compte. |

Plus un écran sans chemin : `mise_a_jour.dart`, monté par-dessus le routeur
quand la version installée est trop ancienne ou le serveur en entretien
(`main.dart`).

---

## Ce qui manque, et ce qui le bloque

| Écran | Bloqué par |
| --- | --- |
| Paiement Mobile Money | `FEDAPAY_SECRET_KEY` manque. La boutique le dit à l'écran. |
| Connexion Google | **Le code est en place** (`donnees/google.dart`, `metier/google.dart`) ; le bouton s'active dès que `GOOGLE_WEB_CLIENT_ID` est passé au build. Restent les deux identifiants OAuth à créer — voir `docs/GUIDE-APK-REVIZ.md` § 3 bis. |

---

## Les états transversaux

Montés dans le `builder:` de `MaterialApp.router`, au-dessus du routeur : c'est
le seul endroit qui voit tous les écrans.

- **Configuration absente** — bandeau rouge en bas, pour qu'un oubli de
  `--dart-define` se lise au lieu de donner un écran noir.
- **Hors ligne** — bandeau orange en haut. Un bandeau et non une page : les
  QCM déjà chargés restent jouables.
- **Mise à jour conseillée** — bandeau jaune avec un lien de téléchargement.
- **Mise à jour exigée ou entretien** — écran bloquant.

Chaque écran garde en plus son propre état vide, son état d'erreur et son
bouton « Réessayer » : `connectivity_plus` rapporte l'état des interfaces, pas
la présence réelle d'Internet.

---

## Le web, ce qu'il en reste

| Chemin | Rôle |
| --- | --- |
| `/` | Ce qu'est Reviz, et un lien vers l'application. |
| `/app` | Comment installer l'application. |
| `/api/*` | Les routes que l'application appelle (`docs/API.md`). |

Les vingt écrans connectés ont été retirés au lot D : ils étaient doublés par
Flutter, et les tenir à jour deux fois revenait à écrire chaque écran deux
fois. `tailwind.config.ts` et `docs/DESIGN.md` restent, eux : ils sont la
source de vérité des jetons, que le thème Flutter reprend.
