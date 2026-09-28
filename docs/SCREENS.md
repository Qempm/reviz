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
| `/inscription` | `inscription.dart` | Prénom, université, filière, année, code parrain. Passe par `POST /api/profil` — jamais d'insertion directe. |
| `/` | `accueil.dart` | Série de sept jours, objectif du jour, quatre matières. |
| `/reviser` | `reviser.dart` | Liste des cours, démonstration épinglée. |
| `/reviser/ajouter` | `ajouter_cours.dart` | Dépôt d'un PDF, d'un .docx ou d'une photo, par URL signée. Empreinte SHA-256 calculée sur l'appareil. |
| `/cours/:id` | `cours.dart` | Progression, chapitres, trois états de traitement. |
| `/cours/:id/session` | `session.dart` | Dix questions, une par écran, correction immédiate, confettis au-delà de 60 %. |
| `/cours/:id/fiches` | `fiches.dart` | Paquet retournable, une fiche à l'écran. |
| `/corriger` | `corriger.dart` | Photo de copie, envoi par URL signée, historique. |
| `/corrections/:id` | `correction.dart` | Attente, note, barème ligne par ligne, copie illisible, échec. |
| `/boutique` | `boutique.dart` | Les cinq packs, l'accès en cours, activation de Découverte. |
| `/gains` | `gains.dart` | Solde, code parrain copiable, filleuls, feuille de retrait. |
| `/classement` | `classement.dart` | Podium 2·1·3 et tableau, pour sa faculté. |
| `/profil` | `profil.dart` | Identité, vérification de carte, chiffres, réglages, déconnexion. |
| `/profil/avatar` | `avatar.dart` | Douze couleurs, initiale dessus. |
| `/profil/supprimer-compte` | `suppression.dart` | Ce qui part, ce qui reste, confirmation par le prénom. |
| `/galerie` | `galerie.dart` | Le kitchen-sink du design system. Public, sans compte. |

Plus un écran sans chemin : `mise_a_jour.dart`, monté par-dessus le routeur
quand la version installée est trop ancienne ou le serveur en entretien
(`main.dart`).

---

## Ce qui manque, et ce qui le bloque

| Écran | Bloqué par |
| --- | --- |
| Photo de carte étudiante | Le traitement `verify_card` n'existe pas. C'est pourtant la seule barrière « un compte par personne » depuis que le téléphone est facultatif. |
| Page d'un chapitre | `Chemins.chapitre(id)` est déclaré et n'a ni route ni appelant. La page de cours suffit pour l'instant. |
| Paiement Mobile Money | `FEDAPAY_SECRET_KEY` manque. La boutique le dit à l'écran. |
| Connexion Google | Un ID client OAuth Android et un ID client Web à créer. |
| Aide et contact | Le contenu reste à écrire, et un vrai numéro WhatsApp à fournir. L'ancienne page web en portait un factice. |

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
