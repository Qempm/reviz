# Surface HTTP de Reviz

Ce que Flutter appelle, et ce qu'il lit directement dans Supabase.

L'architecture retenue le 22 septembre 2026 : **Flutter ne remplace que
l'écran**. Next.js reste le serveur et garde la logique déjà écrite et testée
— routage IA, commissions, packs, file de jobs — ainsi que les clés qui ne
doivent jamais descendre dans un téléphone.

---

## 1. Deux canaux, et comment choisir

| Canal | Quand | Autorité |
| --- | --- | --- |
| **Supabase en direct** (PostgREST, `supabase_flutter`) | toute **lecture** que la RLS sait filtrer | les politiques RLS |
| **Routes REST Next.js** | toute **écriture** qui exige un privilège, une validation métier ou la clé de service | le serveur |

La règle pratique : si l'opération a besoin de `SUPABASE_SERVICE_ROLE_KEY`,
d'une clé de fournisseur, ou d'une règle que la base n'applique pas
elle-même, elle passe par une route. Sinon, elle passe en direct.

**Ce qui se lit en direct** — `profiles` (sa propre ligne), `courses`,
`chapters`, `questions`, `flashcards`, `attempts`, `corrections`, `packs`,
`subscriptions`, `wallet_ledger`, `withdrawals`, `referrals`, `xp_events`,
`daily_activity`, et les quatre vues `subject_stats`, `chapter_stats`,
`course_overview`, `active_subscriptions`. Plus les RPC `streak_week(date)`,
`daily_goal()`, `wallet_balance()`, `classement_faculte(limite)` et
`mon_rang_faculte()`.

> `get_user_rank(uuid)` **n'existe pas** : sa migration ne s'appliquait pas, et
> elle prenait un identifiant en paramètre — le motif qui avait déjà coûté
> quatre passes de correction. Le classement passe par `classement_faculte()`,
> qui ne prend ni ne rend aucun identifiant : « c'est toi » se lit sur la
> colonne `est_moi`.

**Ce qui n'est pas lisible du tout** — `jobs` et `ai_usage` : RLS activée,
aucune politique.

---

## 2. Authentification

`supabase_flutter` gère la session. Deux portes, toutes deux entièrement
côté client :

```dart
// Code à six chiffres par email
await supabase.auth.signInWithOtp(email: email);
await supabase.auth.verifyOTP(email: email, token: code, type: OtpType.email);

// Google, nativement dans l'application
final google = await GoogleSignIn(serverClientId: WEB_CLIENT_ID).signIn();
final auth = await google!.authentication;
await supabase.auth.signInWithIdToken(
  provider: OAuthProvider.google,
  idToken: auth.idToken!,
  accessToken: auth.accessToken,
);
```

Rien de la machinerie web n'est nécessaire : ni `reviz://auth`, ni onglet
personnalisé, ni la route `/auth/rappel`. Elle reste en place pour le web.

Chaque appel aux routes porte ensuite le jeton :

```
Authorization: Bearer <session.accessToken>
```

`lib/supabase/jeton.ts` le lit et **valide la signature auprès du serveur
d'authentification** — un JWT fabriqué ou périmé reçoit 401. En l'absence
d'en-tête, la route retombe sur les cookies, ce qui laisse le web
fonctionner sans modification pendant tout le portage.

---

## 3. Enveloppe de réponse

Toutes les routes répondent selon la convention de `CLAUDE.md` :

```json
{ "ok": true,  "data": { … } }
{ "ok": false, "error": "Message en français, destiné à l'étudiant." }
```

Certains refus ajoutent un `motif` en kebab-case, stable et traduisible côté
client, quand l'écran doit réagir différemment selon la cause.

| Statut | Sens |
| --- | --- |
| 400 | entrée invalide ou corps illisible |
| 401 | pas de session, ou jeton refusé |
| 402 | droits d'accès insuffisants — pack absent, expiré, plafond atteint |
| 409 | l'opération a déjà eu lieu |
| 413 / 415 | fichier trop gros / type non accepté |
| 500 | panne de notre côté |

---

## 4. Les routes

### `POST /api/profil`

Crée le profil après la première connexion.

```json
{ "prenom": "Awa", "universiteId": "uuid", "faculteId": "uuid",
  "annee": 2, "telephone": "97000000", "pays": "BJ", "codeParrain": "ABC123" }
```

`telephone`, `pays` et `codeParrain` sont facultatifs. Réponse :
`{ "id": "uuid" }`. Un refus porte `champ` pour désigner l'entrée à corriger.

Passe par le serveur et non par une insertion directe : le code parrain
désigne un profil dont la RLS ne laisse rien lire, donc la recherche exige le
rôle de service.

### `POST /api/packs/decouverte`

Active le pack gratuit — trois jours, une matière, une correction. Une seule
fois par étudiant : un second appel renvoie 409 avec le motif
`deja-utilise`.

### `POST /api/cours/preparer`

Vérifie les droits, crée la ligne `courses` et **signe une URL d'envoi**.

```json
{ "fileHash": "<sha256 en 64 hexa>", "subjectId": "uuid",
  "title": "Droit constitutionnel", "examDate": "2026-12-15",
  "mime": "application/pdf", "taille": 1048576 }
```

Réponse : `{ "courseId", "storagePath", "uploadUrl" }`.

Le fichier **ne passe pas par cette route** : le client le dépose ensuite
lui-même sur `uploadUrl`, par un `PUT` avec l'en-tête `Content-Type` du
fichier. C'est ce qui permet un polycopié de 25 Mo, là où une fonction
serverless plafonne à 4,5 Mo.

L'empreinte est calculée par le client, et c'est elle qui permet de savoir
avant l'envoi si le document a déjà été traité (règle métier 4). Un document
déjà déposé renvoie 409 avec `courseId` : ce n'est pas une erreur, c'est un
raccourci vers le cours existant.

### `POST /api/cours/confirmer`

`{ "courseId": "uuid" }`. Le fichier est arrivé : le cours passe en
`processing` et le dépôt rapporte ses 25 XP. La transition n'a lieu qu'une
fois, même si le client rappelle la route après une coupure.

### `POST /api/cours/annuler`

`{ "courseId": "uuid" }`. L'envoi a échoué : la ligne créée est retirée. À
appeler systématiquement en cas d'échec, sinon l'empreinte reste prise par
`unique (owner_id, file_hash)` et le même document ne pourra plus jamais être
redéposé.

### `POST /api/session/terminer`

```json
{ "courseId": "uuid",
  "reponses": [ { "questionId": "uuid", "choix": "Le 11 décembre 1990" } ] }
```

De 1 à 50 réponses. `choix: null` pour une question passée.

Réponse : `{ "bonnes", "total", "gains", "xp", "objectifAtteint", "serie" }`.

**Le client envoie ce qu'il a choisi, jamais son verdict.** Le serveur
recorrige depuis `questions.answer` avant d'écrire quoi que ce soit — sans
cela, une requête bricolée vaudrait dix bonnes réponses et la première place
du classement. Le client peut afficher un retour immédiat à partir des
réponses attendues qu'il a reçues avec les questions ; c'est le serveur qui
tranche.

### `POST /api/corrections`

`multipart/form-data` : `copie` (obligatoire), `sujet` (facultatif). Images
JPEG, PNG ou WebP. Réponse : `{ "correctionId": "uuid" }`.

> **Limite connue.** Les fichiers traversent la fonction, plafonnée à 4,5 Mo
> de charge utile sur Vercel, alors que le bucket accepte 10 Mo par image.
> La route refuse au-delà de 4 Mo par champ avec un 413 explicite. Le dépôt
> de cours a résolu le problème par une URL signée ; la correction devra
> suivre le même chemin.

### `POST /api/wallet/withdrawal`

`{ amount_fcfa, operator, phone }` — `operator` vaut `mtn`, `moov` ou `wave`,
`phone` est au format E.164. Réponse : `{ "id": "uuid" }`.

Trois statuts distincts, parce que « sous le seuil » et « solde insuffisant »
ne demandent pas la même chose à l'étudiant : **400** pour une entrée ou un
montant sous les 3 000 F, **402** quand le solde ne suffit pas, **401** sans
session. La vérification passe par `verifierRetrait()`, qui porte ces deux
cas séparément, et le solde est relu côté serveur — un montant proposé par le
client ne décide de rien.

### `POST /api/payments/webhook`

Appelée par le fournisseur, jamais par un client. Signature HMAC-SHA256 sur la
charge utile brute, en-tête `X-Fedapay-Signature`, **comparée à temps
constant**.

Elle répond **200 sur tout ce qui n'a pas d'effet** — statut `pending`,
transaction inconnue, événement déjà traité : un autre code ferait réessayer le
fournisseur indéfiniment. Elle répond 401 sur une signature invalide, 400 sur
une charge utile inattendue, 500 sur une panne de base.

La décision est prise par `deciderPaiement()` (`lib/metier/paiement.ts`), sans
base, et l'écriture par la fonction SQL `enregistrer_paiement()`, qui reprend
la ligne de paiement `for update` : statut, abonnement, commission et
`first_payment_at` tiennent ou échouent ensemble, et une relivraison n'écrit
rien. Deux index uniques partiels —
`subscriptions_un_par_paiement_idx` et
`wallet_ledger_une_commission_par_paiement_idx` — rendent le doublon
impossible même en cas de bogue applicatif.

Vérifié contre la base hébergée : la même charge utile jouée deux fois rend
`traite` puis `deja-traite`, laisse un abonnement, une commission, et pose
`expires_at` à douze mois.

### Les routes antérieures

`/api/payments/init`, `/api/payments/status`, `/api/payments/webhook`,
`/api/profile/avatar`, `/api/profile/delete` et `/api/jobs/run` existaient
déjà, et **n'ont pas été converties** : elles construisent leur client
Supabase à partir des cookies uniquement, donc tout appel depuis
l'application Flutter reçoit 401. Leurs messages d'erreur sont en anglais et
leur enveloppe n'est pas uniforme.

`/api/wallet/withdrawal` était dans ce lot ; elle a été convertie avec l'écran
des gains, qui en avait besoin — sans quoi le bouton « Demander un retrait »
n'aurait été qu'un décor de plus. C'est la règle à suivre pour les autres :
on les convertit quand un écran les appelle, pas avant.

`/api/jobs/run` est un cas à part : elle s'authentifie par `CRON_SECRET` et
n'a aucune raison d'accepter un jeton d'étudiant.

---

## 5. Ce qui reste à faire de ce côté

- Convertir les cinq routes antérieures restantes (`payments/init`,
  `payments/status`, `payments/webhook`, `profile/avatar`, `profile/delete`)
  sur `authentifier()`, l'enveloppe commune et le français. Tant qu'elles ne le
  sont pas, aucun écran Flutter ne peut les appeler.
- Le dépôt de correction par URL signée, pour lever le plafond de 4,5 Mo.
- `/api/payments/init` et la Server Action `initiatePayment` font la même
  chose : n'en garder qu'une. La route est celle que l'application Flutter
  appellera, une fois convertie sur `authentifier()`.
- Le cron de `/api/jobs/run` est planifié **une fois par jour** dans
  `vercel.json` (limite de l'offre Hobby), alors que le code annonce « toutes
  les minutes » : avec `BATCH_SIZE = 5`, cinq jobs par jour au plus. C'est la
  raison pour laquelle le webhook notifie n8n directement au lieu d'enfiler un
  job `notify`.
- La suppression de compte échoue pour tout étudiant ayant gagné un seul
  point d'XP — `xp_events` refuse le DELETE, y compris en cascade et y
  compris au rôle de service. Une stratégie reste à trancher : anonymiser, ou
  refuser explicitement avec un motif lisible.
