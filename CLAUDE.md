# CLAUDE.md — Projet Reviz

> Copier ce fichier à la racine du projet sous le nom `CLAUDE.md`. Claude Code le lit
> automatiquement à chaque session. Le premier message à lui envoyer est en fin de
> document.

---

## Qu'est-ce que Reviz

App mobile-first de révision pour étudiants d'universités d'Afrique francophone (Bénin, Togo, Côte d'Ivoire, Sénégal, Burkina). L'étudiant envoie son cours (PDF, Word, photos), Reviz génère des QCM, des fiches et « les questions qui vont probablement tomber », puis corrige ses copies photographiées. Paiement par packs à durée limitée en Mobile Money, sans abonnement automatique. Parrainage avec commission et retrait Mobile Money. Marketplace de corrections en phase 3.

L'utilisateur cible a un Android milieu de gamme, une connexion instable, un forfait data limité, et ouvre l'app la nuit avant un contrôle. Tout doit être léger, rapide, rassurant et en français. Tous les montants en FCFA.

Distribution : web app hébergée + APK Capacitor (coquille WebView) partagé par lien et WhatsApp. Le Play Store viendra plus tard.

## Stack (ne pas dévier sans en discuter)

- **Next.js 15 (App Router) + TypeScript + Tailwind CSS**, déployé sur Vercel. PWA (manifest + service worker via `next-pwa` ou équivalent) pour le mode hors ligne des QCM déjà chargés.
- **Supabase** : Postgres, Auth (OTP par téléphone), Storage (cours, copies, cartes étudiantes, avatars), Edge Functions si besoin, `pgvector` pour les embeddings des chapitres.
- **IA** : appels directs depuis les routes serveur Next.js, jamais depuis le client. Fournisseurs (format OpenAI Chat Completions) :
  - DeepSeek `deepseek-v4-flash` (base `https://api.deepseek.com`) pour QCM, fiches, questions probables.
  - DeepSeek `deepseek-v4-flash-vision-exp` pour lire les photos (copies, cartes).
  - DeepSeek `deepseek-v4-pro` (thinking activé) pour les corrections notées difficiles.
  - Secours automatique : Qwen `qwen3.8-flash` (`https://dashscope-intl.aliyuncs.com/compatible-mode/v1`) puis GLM `glm-5.3-flash` (`https://api.z.ai/api/paas/v4`).
  - Détails d'appel dans `docs/STACK-IA.md`.
- **File de traitement** : table `jobs` dans Supabase + route `/api/jobs/run` déclenchée par Vercel Cron toutes les minutes. Pas de Redis au MVP.
- **Paiement Mobile Money** : abstraction `lib/payments/provider.ts` avec une première implémentation FedaPay (Bénin, Togo, Côte d'Ivoire) et un webhook `/api/payments/webhook`. Prévoir Moneroo ou KkiaPay comme seconde implémentation, même interface.
- **WhatsApp** : notifications via webhook n8n (`N8N_WHATSAPP_WEBHOOK_URL`). Reviz n'appelle jamais l'API WhatsApp directement.
- **Capacitor** dans `apps/android/` (coquille, voir `docs/GUIDE-APK-REVIZ.md`).

Variables d'environnement attendues dans `.env.local` (jamais commitées) : `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `DEEPSEEK_API_KEY`, `DASHSCOPE_API_KEY`, `ZAI_API_KEY`, `FEDAPAY_SECRET_KEY`, `FEDAPAY_WEBHOOK_SECRET`, `N8N_WHATSAPP_WEBHOOK_URL`, `CRON_SECRET`.

## Design system

Source de vérité : `docs/DESIGN.md` (exporté de Stitch) et, à défaut, ces règles :

- Fond crème `#FFF8E7`, cartes blanches, rayon 20 px, ombre douce. Écrans de célébration en jaune plein `#FFD23F`.
- Accent principal jaune `#FFC300` (CTA, progression, podium n°1, streak). Orange `#FF6B2C` pour l'urgence et les compte à rebours. Bleu doux `#CFE0FF` pour le n°2 et les badges. Vert `#22C55E` / rouge `#EF4444` uniquement pour bonne / mauvaise réponse.
- Typographie Nunito : 800 pour les chiffres héros (40–48 px) et titres, 700 pour les labels, 500 pour le corps (15–16 px). Pas de majuscules, pas de gris froid.
- Composants : podium 2/1/3, carte streak à 7 losanges, carte héros orange avec avatars, barres de progression 10 px en pilule, QCM une question par écran avec 4 boutons pleine largeur, barre de navigation basse à 5 onglets (Accueil / Réviser / Corriger / Gains / Profil).
- Mascotte (`public/mascotte/*.png`) sur accueil, réussite, échec, chargement, pack expiré. 24 avatars dans `public/avatars/`.
- Mobile d'abord (390 px), zones tactiles ≥ 48 px, un seul CTA principal par écran, tutoiement, textes courts.
- Tokens dans `tailwind.config.ts` : `reviz.cream`, `reviz.yellow`, `reviz.orange`, `reviz.blue`, `reviz.ink`, `reviz.muted`.

## Modèle de données (Supabase, schéma `public`)

- `profiles` : id (= auth.users.id), phone, first_name, university_id, faculty_id, study_year, avatar_key, verification_status (`none` | `pending` | `verified` | `rejected`), verified_until, referral_code (unique), referred_by, is_ambassador, created_at.
- `universities`, `faculties` (university_id, name), `subjects` (faculty_id, name).
- `courses` : id, owner_id, subject_id, title, file_hash (unique par owner), storage_path, page_count, status (`uploaded` | `processing` | `ready` | `failed`), shared_with_faculty (bool), exam_date, created_at.
- `chapters` : course_id, index, title, text, token_count, embedding (vector).
- `questions` : chapter_id, type (`mcq` | `open`), statement, options (jsonb), answer, explanation, probability (`high` | `medium` | `low`), created_at.
- `flashcards` : chapter_id, front, back.
- `attempts` : user_id, question_id, is_correct, answered_at ; vue `subject_stats` (score moyen, questions faites, points faibles).
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
3. Anti-fraude : un même numéro ou une même carte étudiante ne peut créer qu'un compte ; un parrain ne peut pas être son propre filleul.
4. Cache IA par `file_hash` : un document déjà traité par quelqu'un dans la même faculté n'est jamais re-traité.
5. Plafonds : 150 pages par cours, 200 questions générées par cours, 300 questions répondues par jour et par étudiant, 5 corrections par jour même en pack illimité.
6. Les traitements lourds (`ingest_course`) ne s'exécutent pas entre 01:00–04:00 et 06:00–10:00 UTC du lundi au vendredi (heures pleines DeepSeek), sauf si le job attend depuis plus de 20 minutes.
7. Toute sortie IA stockée en base est du JSON validé par un schéma Zod avant insertion. Un JSON invalide = retry avec le fournisseur suivant.
8. Jamais de correction « instantanée » les jours d'examen déclarés d'une faculté (table `exam_blackouts`, phase 2).

## Conventions de code

- Dossiers : `app/(public)`, `app/(auth)`, `app/(app)` pour les écrans connectés, `app/api/*` pour les routes, `components/ui` (design system), `components/reviz` (composants métier), `lib/ai`, `lib/payments`, `lib/supabase`, `lib/jobs`.
- Toute route API : validation Zod de l'entrée, vérification de session Supabase, réponse `{ ok, data | error }`.
- Pas de logique métier dans les composants ; les mutations passent par des Server Actions ou des routes API.
- Tests : Vitest pour `lib/*` (calcul des commissions, expiration des packs, sélection du fournisseur IA, validation JSON) ; ne pas tester l'UI au MVP.
- Commits en français, un commit par écran ou par fonctionnalité, jamais de clé dans le dépôt.
- Textes UI en français, centralisés dans `lib/i18n/fr.ts`.
- Quand une décision n'est pas couverte ici, proposer deux options courtes et demander avant de coder.

## Écrans du MVP (ordre de construction)

1. Design system Tailwind + composants `ui` (Button, Card, ProgressBar, Podium, StreakCard, HeroCard, QuizOption, BottomNav, Toast, EmptyState, MascotState).
2. Auth : numéro + OTP, université / filière / année, code parrain, photo carte (job `verify_card`), connexion.
3. Tableau de bord.
4. Ajout de cours → job `ingest_course` → `generate_questions` → page matière → session QCM → résultat.
5. Boutique → paiement FedaPay → webhook → activation → écran confirmation / échec / pack expiré.
6. Correction de copie (job `correct_copy`) → résultat.
7. Portefeuille, parrainage, classement, demande de retrait.
8. Profil, avatar, réglages, aide, suppression de compte.
9. États transversaux : hors ligne, vides, chargement, écran « mise à jour requise » lisant `/version.json`.
10. Coquille Capacitor + page `/app` de téléchargement.

Liste complète des 55 écrans dans `docs/SCREENS.md`.

---

## Premier message à envoyer à Claude Code

```
Lis CLAUDE.md et docs/STACK-IA.md en entier avant de faire quoi que ce soit.

Ensuite, dans cet ordre, sans passer à l'étape suivante tant que la précédente ne compile pas :

1. Initialise le projet Next.js 15 + TypeScript + Tailwind + Supabase (client et serveur), avec la structure de dossiers de CLAUDE.md, le fichier .env.example, et le tailwind.config.ts avec les tokens Reviz.
2. Écris les migrations SQL Supabase pour tout le modèle de données, avec les politiques RLS, dans supabase/migrations/. Ajoute une migration de seed avec 3 universités béninoises (UAC, UAM, UP), 5 filières chacune, 4 matières par filière, et les 5 packs avec leurs prix.
3. Construis le design system dans components/ui (liste dans CLAUDE.md) et une page /kitchen-sink qui les affiche tous, pour que je valide le rendu visuel avant les écrans.
4. Implémente lib/ai : client OpenAI-compatible générique, table de routage DeepSeek → Qwen → GLM avec bascule sur erreur ou JSON invalide, détection des heures pleines DeepSeek, enregistrement dans ai_usage, et les schémas Zod des sorties (questions, fiches, correction, lecture de carte). Tests Vitest sur le routage et la validation.

À la fin de chaque étape, donne-moi en 5 lignes ce qui est fait, ce qui manque, et la commande pour vérifier. Ne crée pas d'écran métier avant que je valide le kitchen-sink.
```
