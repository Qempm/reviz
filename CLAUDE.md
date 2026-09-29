# CLAUDE.md — Projet Reviz

> Copier ce fichier à la racine du projet sous le nom `CLAUDE.md`. Claude Code le lit
> automatiquement à chaque session. Le premier message à lui envoyer est en fin de
> document.

---

## Qu'est-ce que Reviz

App mobile-first de révision pour étudiants d'universités d'Afrique francophone (Bénin, Togo, Côte d'Ivoire, Sénégal, Burkina). L'étudiant envoie son cours (PDF, Word, photos), Reviz génère des QCM, des fiches et « les questions qui vont probablement tomber », puis corrige ses copies photographiées. Paiement par packs à durée limitée en Mobile Money, sans abonnement automatique. Parrainage avec commission et retrait Mobile Money. Marketplace de corrections en phase 3.

L'utilisateur cible a un Android milieu de gamme, une connexion instable, un forfait data limité, et ouvre l'app la nuit avant un contrôle. Tout doit être léger, rapide, rassurant et en français. Tous les montants en FCFA.

Distribution : **APK Flutter** partagé par lien et WhatsApp. Le Play Store viendra plus tard. La coquille Capacitor et la coquille Kotlin ont été retirées : l'application est un vrai client, plus un site emballé (voir `docs/GUIDE-APK-REVIZ.md`).

## Stack (ne pas dévier sans en discuter)

- **L'écran est en Flutter** (`apps/mobile/`), **le serveur reste Next.js 15** (App Router, TypeScript) déployé sur Vercel. Next.js ne sert plus d'interface : il garde `app/api/*`, deux pages publiques (`/` et `/app`), et les clés qui ne doivent jamais descendre dans un téléphone. Flutter lit Supabase en direct là où la RLS suffit, et appelle les routes en HTTPS pour tout ce qui exige un privilège — le contrat est dans `docs/API.md`.
- **Tailwind CSS** reste dans le dépôt pour les deux pages publiques, et `tailwind.config.ts` reste la source de vérité des jetons, que le thème Flutter reprend.
- **Supabase** : Postgres, Auth (**Google et email**, code à 6 chiffres par email — l'OTP téléphone est abandonné depuis le 9 septembre 2026), Storage (cours, copies, cartes étudiantes, avatars), Edge Functions si besoin, `pgvector` pour les embeddings des chapitres.
- **IA** : appels directs depuis les routes serveur Next.js, jamais depuis le client. Fournisseurs (format OpenAI Chat Completions) :
  - DeepSeek `deepseek-v4-flash` (base `https://api.deepseek.com`) pour QCM, fiches, questions probables.
  - DeepSeek `deepseek-v4-flash-vision-exp` pour lire les photos (copies, cartes).
  - DeepSeek `deepseek-v4-pro` (thinking activé) pour les corrections notées difficiles.
  - Secours automatique : Qwen `qwen3.8-flash` (`https://dashscope-intl.aliyuncs.com/compatible-mode/v1`) puis GLM `glm-5.3-flash` (`https://api.z.ai/api/paas/v4`).
  - Détails d'appel dans `docs/STACK-IA.md`.
- **File de traitement** : table `jobs` dans Supabase + route `/api/jobs/run`. Pas de Redis au MVP. Un cours se prépare **par lots de 5 chapitres en parallèle**, et la chaîne **s'enchaîne d'elle-même** (`lancerJobMaintenant` → `/api/jobs/run?cours=`), sans attendre le sondage de l'écran. **Le cron ne tourne qu'une fois par jour** (22:00 UTC) : c'est la seule cadence de l'offre Hobby. Les traitements que l'étudiant attend ne l'utilisent donc pas — ils partent de l'invocation déjà authentifiée du dépôt (`lib/jobs/immediat.ts`), et `generate_questions` avance à chaque interrogation de `GET /api/cours/:id`. Le cron est le filet pour qui a fermé l'application.
- **Paiement Mobile Money** : abstraction `lib/payments/provider.ts` avec une première implémentation FedaPay (Bénin, Togo, Côte d'Ivoire) et un webhook `/api/payments/webhook`. Prévoir Moneroo ou KkiaPay comme seconde implémentation, même interface.
- **WhatsApp** : notifications via webhook n8n (`N8N_WHATSAPP_WEBHOOK_URL`). Reviz n'appelle jamais l'API WhatsApp directement.
- **Flutter 3.44 / Dart 3.12** dans `apps/mobile/` : `supabase_flutter`, `dio`, `go_router`, `flutter_riverpod`. Police Nunito Sans **embarquée** et non téléchargée : le public a un forfait data limité.

Variables d'environnement attendues dans `.env.local` (jamais commitées) : `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DEEPSEEK_API_KEY`, `DASHSCOPE_API_KEY`, `ZAI_API_KEY`, `FEDAPAY_SECRET_KEY`, `FEDAPAY_WEBHOOK_SECRET`, `N8N_WHATSAPP_WEBHOOK_URL`, `CRON_SECRET`.

## Design system

**Deuxième version, arbitrée le 29 septembre 2026** (`docs/DESIGN.md` § 11 bis,
qui prime sur le reste de ce fichier). La première, figée depuis Stitch, donnait
un air de « vieux papier » que le propriétaire a jugé amateur. Les valeurs de
référence vivent dans `apps/mobile/lib/theme/jetons.dart`, qui commente chaque
choix ; en cas de doute, c'est lui qu'on ouvre, et on ne réinvente pas une valeur.

- **Neutres clairs, géométrie inspirée d'Apple** (la forme et le rendu, pas la texture) : fond `#F5F5F7`, cartes blanches `#FFFFFF`, texte `#1D1D1F`, secondaire gris neutre `#6E6E73`, séparateurs `#D1D1D6`. Le brun et le blanc cassé ont disparu.
- **Le jaune `#FFC300` reste la marque** (CTA, progression, série, pilule de navigation), avec du **noir** dessus. Orange `#FE6A2B` pour l'urgence, bleu doux `#BCCDEB` pour le n° 2 et les badges.
- **Toujours aucun vert.** Une bonne réponse se célèbre en jaune (`#FFC300` / `#FFEDB0`), une mauvaise en `#D92D20` sur `#FEE4E2`.
- **Relief doux, plus d'arête tactile** : ombres en deux couches (`Ombres.carte`), halo teinté de jaune sous le bouton principal, **coins continus** (`formeContinue`, superellipse) — 14 px dominant, 22 px cartes, 28 px héros.
- **Mouvement réduit : un seul point.** `MouvementReduit`, à la racine, verse le réglage du profil dans `MediaQuery.disableAnimations` ; un composant animé ne lit que `MediaQuery.disableAnimationsOf(context)`. Pas de roue de chargement : `Chargement.liste()` / `.bloc()` (silhouettes à reflet), et le panthéreau `reflexion` pour une attente longue.
- **Mouvement**, et il sert : le bouton se contracte à l'appui puis revient sur un ressort à léger dépassement (`CourbeRessort`, `Mouvement.courbeGlisse`) ; la pilule de navigation glisse d'onglet en onglet ; les barres et jauges se remplissent ; une mauvaise réponse secoue l'option ; les pages s'ouvrent en glissant depuis la droite. Tout respecte le mouvement réduit.
- Typographie **Nunito Sans**, embarquée : 800 pour les chiffres héros et les titres, 700 pour les labels, 500 pour le corps. Chiffres tabulaires dans les compteurs.
- Barre de navigation basse de 80 px à 5 onglets (Accueil / Réviser / Corriger / Gains / Profil), blanc translucide flouté, **une seule** pilule jaune qui glisse ; construite une fois par le shell de navigation, elle ne change jamais avec la page.
- CTA principal : 54 px, forme continue, texte noir 17 px, fond jaune — le composant `Bouton`.
- Mascotte : un panthéreau en **dix états** (`EtatMascotte` : salut, bravo, courage, champion, reflexion, dodo, curieux, oups, horsLigne, chantier), composant `Mascotte` (entrée sur ressort, respiration qui s'arrête d'elle-même sauf en `reflexion`) et `TeteMascotte` (la tête seule, pour un bandeau). **Plus aucune icône par défaut en illustration** (arbitrage du 29 septembre 2026) : `EtatVide` exige une pose (`oups` pour une panne, `curieux` pour un vide), `Chargement.liste()` montre le panthéreau qui lit, les bandeaux portent sa tête. Seul `Chargement.bloc()` (un morceau de page) reste une silhouette. Sources Flow dans `assets-source/mascotte/`, WebP 512 px produits par `node scripts/mascotte.mjs --apercu=planche.png`. Avatars : **douze animaux en pochoir** (`apps/mobile/assets/avatars/`, 74 ko), teintés à l'affichage par les couleurs de `metier/avatars.dart` ; produits par `scripts/avatars.mjs`. Icône : une pile de fiches cochée sur le jaune, produite par `scripts/icones.mjs` (`--apercu` pour voir le rendu des lanceurs).
- Mobile d'abord (390 px), zones tactiles ≥ 48 px, un seul CTA principal par écran, tutoiement, textes courts.
- Pas de mode sombre au MVP.
- **Voir avant de conclure** : `flutter test test_apercus --update-goldens` rend les écrans en PNG avec des données factices, la vraie police et les vraies icônes, dans `apps/mobile/test_apercus/goldens/` (ignoré par git). C'est ainsi que se juge un changement visuel sans téléphone ni compte.
- Web : `tailwind.config.ts` porte les mêmes valeurs pour les deux pages publiques (`/` et `/app`).

## Modèle de données (Supabase, schéma `public`)

- `profiles` : id (= auth.users.id), phone (**facultatif et non vérifié** : sert aux notifications WhatsApp, pas d'identité ; unique quand renseigné), first_name, university_id, faculty_id, study_year, avatar_key, verification_status (`none` | `pending` | `verified` | `rejected`), verified_until, referral_code (unique), referred_by, is_ambassador, xp_total, current_streak, longest_streak, last_validated_on, created_at.
- `universities`, `faculties` (university_id, name), `subjects` (faculty_id, name).
- `courses` : id, owner_id, subject_id, title, file_hash (unique par owner), storage_path, page_count, status (`uploaded` | `processing` | `ready` | `failed`), shared_with_faculty (bool), exam_date, created_at.
- `chapters` : course_id, index, title, text, token_count, embedding (vector).
- `questions` : chapter_id, type (`mcq` | `open`), statement, options (jsonb), answer, explanation, probability (`high` | `medium` | `low`), created_at.
- `flashcards` : chapter_id, front, back.
- `attempts` : user_id, question_id, is_correct, answered_at ; vue `subject_stats` (score moyen, questions faites, points faibles).
- `xp_events` : user_id, reason (`correct_answer` | `quiz_completed` | `daily_goal` | `streak_bonus` | `course_added` | `correction_done` | `referral` | `adjustment`), amount, reference_id, created_at. **Journal en ajout seul**, comme `wallet_ledger` : une erreur se corrige par une ligne `adjustment`. `profiles.xp_total` en est un cache tenu par trigger, nécessaire au classement.
- `daily_activity` : user_id, day, questions_answered, correct_answers, xp_earned, is_validated, clé primaire (user_id, day). Alimente la carte des 7 jours et le calcul des séries. Un jour est validé au-delà de `public.daily_goal()` questions (10 au départ) ; la série est le nombre de jours validés consécutifs. Fonction `streak_week()` pour l'affichage.
- `corrections` : id, user_id, course_id, storage_paths (jsonb), status, grade, max_grade, rubric (jsonb), feedback (jsonb), model_used, created_at.
- `packs` : code (`decouverte` | `controle` | `partiel` | `semestre` | `rattrapage`), price_fcfa, duration_days, corrections_included, subjects_limit, active_from, active_to.
- `subscriptions` : user_id, pack_code, starts_at, ends_at, corrections_left, source (`payment` | `class_purchase` | `bonus`), payment_id. **Pas de renouvellement automatique** : à `ends_at`, l'accès s'arrête, point.
- `payments` : id, user_id, provider, provider_ref, amount_fcfa, operator, phone, status (`pending` | `success` | `failed`), pack_code, raw (jsonb), created_at.
- `wallet_ledger` : id, user_id, type (`referral_commission` | `sale` | `withdrawal` | `adjustment`), amount_fcfa (positif ou négatif), reference_id, created_at. **Grand livre immuable** : jamais d'UPDATE, le solde est une somme.
- `withdrawals` : user_id, amount_fcfa, operator, phone, status, requested_at, paid_at.
- `referrals` : referrer_id, referred_id, first_payment_at, commission_rate (0.25 ou 0.35), expires_at (12 mois après first_payment_at).
- `jobs` : id, type (`ingest_course` | `generate_questions` | `correct_copy` | `verify_card` | `notify`), payload (jsonb), status, attempts, last_error, run_after, created_at.
- `ai_usage` : job_id, provider, model, prompt_tokens, completion_tokens, cache_hit_tokens, cost_usd_estimate, created_at.

RLS activée sur toutes les tables : un utilisateur ne lit et n'écrit que ses propres lignes ; les cours `shared_with_faculty` sont lisibles par la faculté ; les tables financières ne sont écrites que par le rôle service.

## Règles métier non négociables

1. Paiement unique par pack. Aucun prélèvement récurrent. À l'expiration : lecture seule des cours et de l'historique, écran « pack expiré » avec réactivation.
2. Commission parrain 25 % (35 % ambassadeur) sur chaque paiement du filleul pendant 12 mois, créditée dans `wallet_ledger` au webhook de paiement réussi. Seuil de retrait 3 000 F. Un filleul ne compte que s'il est vérifié et a payé au moins une fois.
3. Anti-fraude : **la carte étudiante est la seule barrière « un compte par personne »** depuis que le téléphone est facultatif — une même carte ne peut créer qu'un compte. Un numéro renseigné reste unique, mais comme il n'est ni obligatoire ni vérifié, il ne constitue plus une preuve. Un parrain ne peut pas être son propre filleul.
4. Cache IA par `file_hash` : un document déjà traité par quelqu'un dans la même faculté n'est jamais re-traité.
5. Plafonds : 150 pages par cours, 200 questions générées par cours, 300 questions répondues par jour et par étudiant, 5 corrections par jour même en pack illimité.
6. La lecture d'un cours **en photo** (`ingest_course` avec `vision: true`, seule à appeler un modèle) ne s'exécute pas entre 01:00–04:00 et 06:00–10:00 UTC du lundi au vendredi (heures pleines DeepSeek), sauf si le job attend depuis plus de 20 minutes. PDF et Word, lus sans modèle, partent à toute heure (arbitrage du 29 septembre 2026 ; `job_peut_demarrer` à 4 arguments, `lib/ai/peak-hours.ts`).
7. Toute sortie IA stockée en base est du JSON validé par un schéma Zod avant insertion. Un JSON invalide = retry avec le fournisseur suivant.
8. Jamais de correction « instantanée » les jours d'examen déclarés d'une faculté (table `exam_blackouts`, phase 2).

## Conventions de code

- Dossiers du serveur : `app/api/*` pour les routes, `app/app/` pour la page de téléchargement, `lib/ai`, `lib/metier`, `lib/payments`, `lib/jobs`, `lib/supabase`, `lib/profil`. Dossiers de l'application : `apps/mobile/lib/{ecrans,composants,donnees,metier,etat,theme,i18n}`.
- Toute logique métier pure va dans `lib/metier` ou `lib/{payments,xp,auth}` côté serveur, et dans `apps/mobile/lib/metier` côté application — les deux avec leurs tests. C'est la seule duplication justifiée du projet : l'écran doit pouvoir dire « 3 corrections restantes » sans aller-retour, mais le serveur reste l'autorité.
- Toute route API : validation Zod de l'entrée, vérification de session Supabase, réponse `{ ok, data | error }`.
- Pas de logique métier dans les composants ; les mutations passent par des Server Actions ou des routes API.
- **Navigation Flutter : jamais `context.go` pour aller plus loin.** `go` remplace la pile, et c'est ce qui faisait sortir le bouton retour d'Android de l'application depuis n'importe quel écran. Deux verbes, définis dans `apps/mobile/lib/routage.dart` : `context.descendre(chemin)` pour ouvrir un écran plus profond (la page d'où l'on vient reste dessous), `context.remonter(repli)` pour revenir (on dépile, ou on va au parent logique si l'écran a été ouvert par un lien). `go` ne sert qu'à changer d'onglet ou à repartir de zéro (connexion, inscription). Les cinq onglets vivent dans un `StatefulShellRoute` : la barre du bas (`CoquilleOnglets`) est construite une fois, et `test/navigation_test.dart` simule le bouton retour pour le vérifier.
- Tests : Vitest pour `lib/*` côté serveur ; `flutter test` côté application, avec des tests de rendu qui mesurent le débordement horizontal à 375 px **puis 320 px**. La CI (`.github/workflows/ci.yml`) exécute les deux, plus `typecheck`, `lint` et `build`.
- Commits en français, un commit par écran ou par fonctionnalité, jamais de clé dans le dépôt.
- Textes d'interface en français, centralisés dans `apps/mobile/lib/i18n/fr.dart`. `lib/i18n/fr.ts` a été retiré avec les écrans web.
- Quand une décision n'est pas couverte ici, proposer deux options courtes et demander avant de coder.

## Écrans du MVP (ordre de construction)

> **État au 29 septembre 2026.** Les points 1 à 9 sont faits côté Flutter,
> photo de carte étudiante et écran d'aide compris. Le point 10 — la coquille
> — est remplacé par un APK Flutter signé, **publié** en
> [release v2.0.0](https://github.com/Qempm/reviz/releases/tag/v2.0.0). Ce qui
> reste à l'écran attend des identifiants, pas du code : paiement (FedaPay) et
> connexion Google. Voir `docs/SCREENS.md`.

1. Design system : jetons dans `apps/mobile/lib/theme/`, composants dans `apps/mobile/lib/composants/`, et l'écran `/galerie` qui les affiche tous pour valider le rendu avant les écrans métier.
2. Auth : Google ou email (code à 6 chiffres), université / filière / année, code parrain, téléphone facultatif, photo carte (job `verify_card`), connexion.
3. Tableau de bord.
4. Ajout de cours → job `ingest_course` → `generate_questions` → page matière → session QCM → résultat.
5. Boutique → paiement FedaPay → webhook → activation → écran confirmation / échec / pack expiré.
6. Correction de copie (job `correct_copy`) → résultat.
7. Portefeuille, parrainage, classement, demande de retrait.
8. Profil, avatar, réglages, aide (sept questions, l'argent en premier), suppression de compte.
9. États transversaux : hors ligne, vides, chargement, écran « mise à jour requise » lisant `/version.json`.
10. APK Flutter signé + pages publiques `/` et `/app`.

Liste réelle des écrans — ceux qui tournent, ceux qui manquent et ce qui les bloque — dans `docs/SCREENS.md`. Le registre de l'audit de septembre 2026 est dans `docs/AUDIT-2026-09.md`.

---

## Où en est le projet, et par où reprendre

Le portage est fait. Ce qu'il faut savoir avant de toucher quoi que ce soit :

- **Lire `docs/API.md`** pour le contrat entre l'application et le serveur, et
  `docs/AUDIT-2026-09.md` pour ce qui a été réparé et ce qui reste. Les deux
  évitent de refaire des erreurs déjà payées.
- **Vérifier avant de conclure.** Les défauts les plus coûteux de ce dépôt
  n'étaient pas visibles à la lecture : une migration qui ne s'appliquait pas,
  une fonction appelée seulement par ses tests, une comparaison de version
  auto-référentielle, un webhook qui payait deux fois. Les méthodes qui les ont
  trouvés sont listées à la fin de `docs/AUDIT-2026-09.md`.
- **Ne pas régénérer `tailwind.config.ts` ni `docs/DESIGN.md`** : ils portent
  les jetons figés depuis Stitch, et le thème Flutter les reprend.
- **Ne jamais mettre de secret dans le dépôt.** `SUPABASE_SERVICE_ROLE_KEY` ne
  prend jamais le préfixe `NEXT_PUBLIC_` et ne descend jamais dans l'APK : un
  APK se décompile, tout ce qu'il embarque est public.

Vérification, à chaque changement :

```bash
npm run typecheck && npm run lint && npm test && npm run build
cd apps/mobile && flutter analyze && flutter test
```

Ce qui reste à faire, par ordre de valeur :

1. **La CI est rouge pour une raison hors du code.** Les trois jobs meurent en
   une seconde : « The job was not started because your account is locked due
   to a billing issue. » C'est la facturation du compte GitHub, pas le
   workflow. Tant que ce n'est pas réglé, aucune vérification automatique ne
   tourne — seules les commandes locales ci-dessus font foi.
2. ~~**Publier l'APK.**~~ Fait : clé de signature créée hors du dépôt,
   `npm run apk` rend un APK signé, et la **2.0.0 est publiée** en release
   GitHub — la page `/app` affiche le bouton, la taille et l'empreinte. Reste
   à l'**essayer sur un vrai téléphone** : c'est la seule chose qu'aucune
   vérification d'ici ne remplace.
3. **Le paiement réel** — branché le 29 septembre 2026, **réécrit d'après la
   doc FedaPay et le SDK officiel** (la première version ne parlait pas la
   langue de l'API : voir `lib/payments/provider.ts`). **Tout se fait dans
   l'application** : `EcranPayer` (numéro pré-rempli, opérateur, nom et
   e-mail du compte), la demande part sur le téléphone (`POST /v1/{mode}`),
   `EcranPaiement` suit l'issue, et `/api/payments/status` relit FedaPay si
   le webhook tarde. Seuls les opérateurs « sans redirection »
   (`lib/metier/operateurs.ts`) ; Wave, Orange et le Burkina plus tard. Clé **secrète** (`sk_live_` ou
   `sk_sandbox_`, l'environnement s'en déduit) dans `FEDAPAY_SECRET_KEY` ;
   secret du webhook (`wh_…`, créé dans le tableau de bord FedaPay sur
   `/api/payments/webhook`) dans `FEDAPAY_WEBHOOK_SECRET` — **les deux aussi
   sur Vercel**. Reste un vrai paiement, de préférence en sandbox d'abord.
4. **La connexion Google** — configurée le 29 septembre 2026 : ID client
   **Web** dans `.env.local` (`GOOGLE_WEB_CLIENT_ID`, compilé dans l'APK depuis
   la 2.1.1), client **Android** créé côté Google Cloud (paquet
   `com.reviz.app`, SHA-1 de la clé de release `AF:A1:F6:E8:…:8A:4A`). Reste à
   l'**essayer sur un téléphone** : un `DEVELOPER_ERROR` voudrait dire que le
   SHA-1 ou le paquet déclaré ne correspond pas. `docs/GUIDE-APK-REVIZ.md`
   § 3 bis.
5. **La mascotte** — faite le 29 septembre 2026 : sept états, branchés
   (résultats, n° 1, pack expiré, vides, accueil, attentes longues). L'icône et les douze avatars sont dans la 2.0.1 ; les icônes
   PWA ne sont plus attendues.
