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
- **File de traitement** : table `jobs` dans Supabase + route `/api/jobs/run` déclenchée par Vercel Cron toutes les minutes. Pas de Redis au MVP.
- **Paiement Mobile Money** : abstraction `lib/payments/provider.ts` avec une première implémentation FedaPay (Bénin, Togo, Côte d'Ivoire) et un webhook `/api/payments/webhook`. Prévoir Moneroo ou KkiaPay comme seconde implémentation, même interface.
- **WhatsApp** : notifications via webhook n8n (`N8N_WHATSAPP_WEBHOOK_URL`). Reviz n'appelle jamais l'API WhatsApp directement.
- **Flutter 3.44 / Dart 3.12** dans `apps/mobile/` : `supabase_flutter`, `dio`, `go_router`, `flutter_riverpod`. Police Nunito Sans **embarquée** et non téléchargée : le public a un forfait data limité.

Variables d'environnement attendues dans `.env.local` (jamais commitées) : `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DEEPSEEK_API_KEY`, `DASHSCOPE_API_KEY`, `ZAI_API_KEY`, `FEDAPAY_SECRET_KEY`, `FEDAPAY_WEBHOOK_SECRET`, `N8N_WHATSAPP_WEBHOOK_URL`, `CRON_SECRET`.

## Design system

**Source de vérité : `docs/DESIGN.md`**, extrait des écrans Stitch réellement générés
(projet `4246361917454252874`) et aligné sur les arbitrages du 8 septembre 2026
(`docs/DESIGN.md` § 11). Le résumé ci-dessous en découle ; en cas de doute, ouvrir
`docs/DESIGN.md`, ne jamais réinventer une valeur.

- Fond `#fcf9f8` (blanc cassé chaud, **pas** un crème), cartes blanches `#ffffff`, ombre douce `0 4px 20px rgba(26,26,26,.06)`. Rayon dominant **12 px** (`rounded-xl`) ; 20 px réservé aux grandes cartes, 24 px à la carte héros, 28 px aux feuilles modales.
- Accent principal jaune `#FFC300` (CTA, progression, podium n°1, streak). Orange `#fe6a2b` pour l'urgence et les compte à rebours. Bleu doux `#bccdeb` pour le n°2 et les badges. Encre `#1c1b1b`, texte secondaire `#4f4632` (brun chaud, jamais un gris froid).
- ⚠️ Le jaune est le token `primary-container`. `primary` vaut `#785a00` et sert **au texte**, jamais à un fond de CTA.
- **Palette strictement chaude : aucun vert de succès.** Une bonne réponse se célèbre en jaune (`#FFC300` / `#ffdf9a`), une mauvaise en `#ba1a1a` sur `#ffdad6`. Ne pas introduire `#22C55E` ni `#EF4444`.
- Signature tactile : ombre pleine sans flou sous les éléments actionnables, réduite à l'appui — `shadow-[0_4px_0_#d9a400] active:translate-y-[2px] active:shadow-[0_2px_0_#d9a400]`. Arêtes : `#d9a400` sur jaune, `#d94e15` sur orange, `#d3c5ab` sur neutre, `#93000a` sur rouge.
- Typographie **Nunito Sans** : 800 pour les chiffres héros (44 px, 38 px en mobile) et les titres, 700 pour les labels, 500 pour le corps (15–16 px). Majuscules réservées au seul niveau `caption` (11 px, +0.04em). Icônes Material Symbols Outlined.
- Composants : podium 2/1/3 (blocs 128/96/80 px, n°3 en pêche `#ffdbcf`), carte streak à 7 carrés arrondis légèrement inclinés, carte héros orange avec avatars, barres de progression 10 px en pilule à remplissage plat, QCM une question par écran avec 4 boutons pleine largeur (fond blanc, sélection par fond `#ffdf9a`, **sans bordure**), barre de navigation basse plate de 80 px à 5 onglets (Accueil / Réviser / Corriger / Gains / Profil) dont l'actif est une pilule jaune — pas de bouton flottant central.
- CTA principal : 56 px de haut, rayon 12 px, texte `headline-md`, fond `#FFC300` — `h-cta bg-reviz-yellow text-reviz-on-yellow text-headline-md rounded-xl shadow-tactile`.
- Mascotte (`public/mascotte/*.png`) sur accueil, réussite, échec, chargement, pack expiré. 24 avatars dans `public/avatars/`. **À produire : Stitch n'a livré aucun asset local**, ses écrans pointent vers des images générées.
- Mobile d'abord (390 px), zones tactiles ≥ 48 px, un seul CTA principal par écran, tutoiement, textes courts. Header collant de 64 px, `pb-[96px]` au-dessus de la nav, safe areas via `.pt-safe` / `.pb-safe`.
- Pas de mode sombre au MVP (Stitch n'en a pas généré).
- Tokens dans `tailwind.config.ts` : les alias métier `reviz.cream`, `reviz.yellow`, `reviz.orange`, `reviz.blue`, `reviz.ink`, `reviz.muted` (+ `card`, `yellow-soft`, `orange-soft`, `blue-soft`, `on-yellow`, `danger`, `border`, `edge.*`) pour le code qu'on écrit ; les rôles Material 3 (`surface`, `primary-container`, `on-surface`…) sont conservés en parallèle pour coller le markup Stitch sans le réécrire.

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
6. Les traitements lourds (`ingest_course`) ne s'exécutent pas entre 01:00–04:00 et 06:00–10:00 UTC du lundi au vendredi (heures pleines DeepSeek), sauf si le job attend depuis plus de 20 minutes.
7. Toute sortie IA stockée en base est du JSON validé par un schéma Zod avant insertion. Un JSON invalide = retry avec le fournisseur suivant.
8. Jamais de correction « instantanée » les jours d'examen déclarés d'une faculté (table `exam_blackouts`, phase 2).

## Conventions de code

- Dossiers du serveur : `app/api/*` pour les routes, `app/app/` pour la page de téléchargement, `lib/ai`, `lib/metier`, `lib/payments`, `lib/jobs`, `lib/supabase`, `lib/profil`. Dossiers de l'application : `apps/mobile/lib/{ecrans,composants,donnees,metier,etat,theme,i18n}`.
- Toute logique métier pure va dans `lib/metier` ou `lib/{payments,xp,auth}` côté serveur, et dans `apps/mobile/lib/metier` côté application — les deux avec leurs tests. C'est la seule duplication justifiée du projet : l'écran doit pouvoir dire « 3 corrections restantes » sans aller-retour, mais le serveur reste l'autorité.
- Toute route API : validation Zod de l'entrée, vérification de session Supabase, réponse `{ ok, data | error }`.
- Pas de logique métier dans les composants ; les mutations passent par des Server Actions ou des routes API.
- Tests : Vitest pour `lib/*` côté serveur ; `flutter test` côté application, avec des tests de rendu qui mesurent le débordement horizontal à 375 px **puis 320 px**. La CI (`.github/workflows/ci.yml`) exécute les deux, plus `typecheck`, `lint` et `build`.
- Commits en français, un commit par écran ou par fonctionnalité, jamais de clé dans le dépôt.
- Textes d'interface en français, centralisés dans `apps/mobile/lib/i18n/fr.dart`. `lib/i18n/fr.ts` a été retiré avec les écrans web.
- Quand une décision n'est pas couverte ici, proposer deux options courtes et demander avant de coder.

## Écrans du MVP (ordre de construction)

> **État au 28 septembre 2026.** Les points 1 à 9 sont faits côté Flutter, à
> deux exceptions près : le **dépôt de cours** (point 4) attend les traitements
> IA `ingest_course` et `generate_questions`, qui n'existent pas, et la **photo
> de carte étudiante** attend `verify_card`. Le point 10 — la coquille — est
> remplacé par un APK Flutter signé, qui attend les licences Android et une clé
> de signature. Voir `docs/SCREENS.md`.

1. Design system : jetons dans `apps/mobile/lib/theme/`, composants dans `apps/mobile/lib/composants/`, et l'écran `/galerie` qui les affiche tous pour valider le rendu avant les écrans métier.
2. Auth : Google ou email (code à 6 chiffres), université / filière / année, code parrain, téléphone facultatif, photo carte (job `verify_card`), connexion.
3. Tableau de bord.
4. Ajout de cours → job `ingest_course` → `generate_questions` → page matière → session QCM → résultat.
5. Boutique → paiement FedaPay → webhook → activation → écran confirmation / échec / pack expiré.
6. Correction de copie (job `correct_copy`) → résultat.
7. Portefeuille, parrainage, classement, demande de retrait.
8. Profil, avatar, réglages, aide, suppression de compte.
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

1. **Les traitements IA** — `ingest_course` et `generate_questions` n'existent
   pas, donc un cours déposé ne produirait rien. C'est le plus gros manque :
   sans eux, l'application ne sait réviser que le cours de démonstration.
2. **Un APK signé** — attend les licences du SDK Android et une clé de
   signature (`docs/GUIDE-APK-REVIZ.md`).
3. **Le paiement réel** — attend `FEDAPAY_SECRET_KEY` et
   `FEDAPAY_WEBHOOK_SECRET`.
4. **La connexion Google** — attend un ID client OAuth Android et un ID client
   Web.
5. **Les assets** — icônes PWA, cinq états de la mascotte, 24 avatars en
   images. Les avatars sont contournés par douze couleurs en attendant.
