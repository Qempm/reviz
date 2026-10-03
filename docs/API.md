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

### `GET /api/cours/:id`

L'état d'un cours en préparation, dans la forme de la vue `course_overview` —
l'application réutilise donc sa fabrique sans rien convertir.

**Et cet appel fait avancer la préparation.** C'est le point de la route, et
c'était le plus gros défaut fonctionnel restant. La chaîne d'un dépôt est en
deux temps : `ingest_course` découpe le document, puis `generate_questions`
traite **un chapitre par passage** et se remet en file — découpage volontaire,
pour ne pas se faire couper au milieu d'un chapitre. Seul le premier job
partait tout de suite, depuis `/api/cours/confirmer`. Les suivants attendaient
le cron, planifié une fois par jour et limité à cinq jobs : un cours de six
chapitres aurait mis **des jours** à être prêt, pour un produit dont la
promesse est « la nuit avant le contrôle ».

L'attente de l'étudiant est donc devenue le moteur de la chaîne, exactement
comme pour `GET /api/corrections/:id`. L'écran interroge la route, la route
relance un job dû, et chaque tour avance d'un chapitre. C'est aussi pourquoi
l'écran de cours ne dit plus « tu peux fermer l'application, on te prévient » :
c'était faux deux fois — il n'y a pas de notification, et fermer renvoie le
reste au traitement de nuit.

Un job reporté garde son report : on ne relance que si `run_after` est passé,
sinon un 429 du fournisseur se ferait marteler.

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

### `POST /api/payments/init`

`{ packCode, operateur, telephone }` → `{ paiementId, transactionId,
montantFcfa }`. **Le paiement se fait dans l'application** : la route crée la
transaction FedaPay avec son `customer` (prénom du profil, e-mail de la
session — jamais envoyés par le client), demande le jeton
(`POST /v1/transactions/{id}/token`), puis envoie la demande au téléphone
(`POST /v1/{mode}` `{ token, phone_number: { number, country } }`).
L'étudiant la valide avec son code secret.

`operateur` ∈ `mtn | moov | celtiis | togocel | free` ; le mode FedaPay est
choisi par `modeFedaPay()` (`lib/metier/operateurs.ts`) selon le pays du
numéro — Bénin `mtn_open` / `moov` / `sbin`, Togo `moov_tg` / `togocel`,
CI `mtn_ci`, Sénégal `free_sn`, et `momo_test` en sandbox. Wave, Orange et le
Burkina ne se paient que sur la page hébergée : refusés (**400**
`operateur-indisponible`). **426** `mise-a-jour` si `operateur` ou
`telephone` manquent (la 2.2.0, qui ouvrait la page FedaPay). **502** si la
demande ne part pas ; **503** sans clé secrète valide.

L'environnement FedaPay se lit sur le préfixe de la clé : `sk_sandbox_` →
`sandbox-api.fedapay.com`, `sk_live_` → `api.fedapay.com`.

### `GET /api/payments/status[?id=<paiementId>]`

→ `{ id, status, amount_fcfa, pack_code, created_at }`, `status` valant
`pending`, `success` ou `failed`. **Filet du webhook** : tant que le paiement
est `pending` depuis plus de 15 s, la route relit la transaction chez FedaPay
(`GET /v1/transactions/{id}`, avec la clé secrète) et applique l'issue par
`traiterTransaction()` — la même fonction que le webhook. Un étudiant qui a
payé est donc activé même si la notification se perd. 400 sur un `id` qui
n'est pas un UUID, 404 s'il n'y a rien à suivre.

### `POST /api/payments/webhook`

Appelée par FedaPay, jamais par un client. Déclarée dans le tableau de bord
FedaPay (Webhooks → Nouveau webhook), avec les événements
`transaction.approved`, `transaction.declined` et `transaction.canceled` ; son
secret (`wh_live_…` / `wh_sandbox_…`, « Click to reveal ») va dans
`FEDAPAY_WEBHOOK_SECRET`.

Signature au format du SDK officiel : en-tête `X-FEDAPAY-SIGNATURE` valant
`t=<horodatage>,s=<hmac>`, HMAC-SHA256 de `"<horodatage>.<corps brut>"`,
**comparé à temps constant**, refusé au-delà de 5 minutes. Événement
`{ name, entity }` : `name` vaut `transaction.approved`…, `entity` est la
transaction. `approved` et `transferred` activent ; `declined`, `canceled` et
`expired` échouent ; le reste est ignoré (`statutDepuisFedaPay()`).

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

**Seuil de parrainage (3 octobre 2026).** La commission n'est due que si le
parrain a 3 000 XP ou est ambassadeur (`calculerCommission`, motif
`parrain_sous_seuil_xp`), et `enregistrer_paiement()` le revérifie avant
d'écrire (`seuil_xp_parrainage()`). Essai annulé contre la base hébergée : un
parrain à 2 999 XP n'est pas crédité, un parrain à 3 000 XP et un ambassadeur à
0 XP le sont, et les trois filleuls ont leur accès. Les 500 XP de parrainage
partent au premier paiement d'un filleul vérifié, même sous le seuil, une fois
par filleul (`xp_events.reference_id` = le filleul).

### Les quatre routes de la correction

`POST /api/corrections/preparer` — `{ copie: {mime, taille}, pages?, sujet?,
courseId?, typeEpreuve?, bareme? }`. `pages` : jusqu'à trois pages de plus,
signées en `champ: 'page'` dans l'ordre (`copie-2`, `copie-3`…).
`typeEpreuve` (`devoir` | `interrogation` | `partiel` | `examen` | `td`) et
`bareme` (5 à 100) sont gardés dans `feedback.demande` jusqu'à la
correction, qui les revalide ; avec `courseId`, la correction est jugée
d'après ce cours, l'année et la filière de l'étudiant, et rend
`feedback.chapitres` (`[{id, index, titre}]`, trois au plus) et
`feedback.notions`. Tous ces champs sont facultatifs : un APK antérieur
continue de fonctionner.
Vérifie les droits par `etatAcces()` + `peutCorriger()`, réserve la ligne
`corrections` **avant** l'envoi — pour que le plafond de cinq par jour tranche
en 200 ms et non après quarante secondes d'envoi — et signe une URL par
fichier, **sous l'identité de l'appelant** : la politique « Je dépose mes
copies » s'applique alors au moment de la signature. Réponse :
`{ correctionId, envois: [{champ, chemin, url}] }`. **402** avec un `motif`
parmi `aucun_pack`, `pack_expire`, `credit_epuise`, `plafond_journalier` —
quatre refus, quatre phrases.

`POST /api/corrections/confirmer` — `{ correctionId }`. Vérifie que les
fichiers sont bien arrivés, enfile le job `correct_copy`, **puis lance le
traitement dans la même invocation** par `after()` : le cron ne tourne
qu'une fois par jour sur l'offre Hobby, et une copie photographiée à 21:00
avant un contrôle ne peut pas attendre 22:00 du lendemain. Le téléphone
n'appelle jamais `/api/jobs/run` et n'apprend jamais `CRON_SECRET`.

`POST /api/corrections/annuler` — `{ correctionId }`. Retire une réservation
dont l'envoi a échoué. Pas décorative : sans elle, une coupure en cours
d'envoi consomme une des cinq corrections du jour.

`GET /api/corrections/:id` — l'état d'une correction, et **relance** un
traitement dont le report est écoulé. C'est pourquoi l'écran interroge cette
route et non PostgREST, que la RLS autoriserait : l'attente de l'étudiant
devient le moteur des reprises.

Le fichier ne traverse jamais ces routes : une photo de copie pèse 3 à 8 Mo,
et la charge utile d'une fonction serverless est plafonnée à 4,5 Mo. L'ancienne
`POST /api/corrections` en multipart est supprimée.

### Les deux routes de la carte étudiante

`POST /api/carte/preparer` — `{ mime, taille }`. Signe une URL d'envoi vers le
seau `cartes`, **sous l'identité de l'appelant** : la politique « Je dépose ma
carte » s'applique au moment de la signature. Réponse : `{ chemin, uploadUrl }`.
**409** avec un `motif` `deja-verifie` ou `en-cours` — accepter un second dépôt
laisserait essayer des cartes jusqu'à ce qu'une passe.

Rien n'est réservé avant l'envoi, contrairement au dépôt d'un cours : le profil
existe déjà, et il n'y a pas de plafond journalier à faire trancher tôt. Donc
pas de route `annuler` — un envoi interrompu ne consomme rien.

Le chemin porte un horodatage : une carte redéposée n'écrase pas la
précédente, qui sert de pièce en cas de contestation.

`POST /api/carte/confirmer` — `{ chemin }`. Vérifie que la photo est arrivée,
passe le profil en `pending`, enfile le job `verify_card` et **lance le
traitement dans la même invocation** par `after()`, comme la correction. Le
statut passe à `pending` **ici** et non dans le traitement : c'est ce qui fait
que l'écran annonce « on lit ta carte » dès le retour, sans attendre le premier
appel de vision.

Le chemin est vérifié comme appartenant à l'appelant
(`cheminDeSonDossier()` dans `lib/metier/carte.ts`, testée). C'est le vrai
risque du dépôt : faire vérifier la carte d'un camarade reviendrait à
**s'attribuer son empreinte**, et à faire refuser la sienne comme « déjà
utilisée ».

**Le verdict n'est pas dans la réponse.** Il arrive dans
`profiles.verification_status`, que l'écran relit — la vérification part après
la réponse, et `jobs` n'est lisible par aucun client. Une lecture trop floue
laisse le profil en `pending`, indiscernable du traitement en cours ; les deux
demandent la même chose à l'étudiant — rien —, donc l'écran affiche « on
regarde ta carte » passé une minute d'attente.

### `POST /api/profile/delete`

Sans corps. Réponse : `{ anonymise, dejaFait, fichiersRetires }`.

**Anonymise au lieu de supprimer**, parce que la base refuse la suppression :
`payments`, `wallet_ledger` et `withdrawals` référencent `profiles` en
`on delete restrict`, et le trigger `xp_events_no_delete` lève sur tout DELETE
y compris pour le rôle de service. La version précédente appelait
`admin.auth.admin.deleteUser()` et rendait un 500 opaque à tout étudiant ayant
gagné un point ou effleuré un pack.

La route retire d'abord les fichiers par l'API de stockage — supprimer une
ligne de `storage.objects` en SQL ôterait la référence mais laisserait le
binaire — puis appelle `anonymiser_compte(uuid)`. Le contenu personnel part
(cours, chapitres, questions, fiches, réponses, corrections, parrainages,
identité du profil) ; les lignes financières restent, sans nom dessus. Le
compte devient inutilisable : adresse sur `.invalid`, identités détachées,
sessions révoquées, `banned_until` à l'infini. Idempotente.

### `PUT /api/profile/avatar`

`{ avatar_key }` — une des **douze clés** de `lib/profil/avatars.ts`. Réponse :
`{ avatarKey }`.

La liste blanche est le point de la route. `profiles.avatar_key` est une
colonne `text` libre que le trigger `protect_profile_columns` ne gèle pas : la
version précédente acceptait n'importe quelle chaîne de cent caractères, et
rien ne garantissait que ce qu'un écran lit soit un avatar.

Les images sont embarquées dans l'application, pas servies par le site :
depuis le 3 octobre 2026, douze bustes d'animaux en peluche 3D
(`apps/mobile/assets/avatars/<clé>.webp`, `scripts/avatars.mjs`). Les clés
n'ont jamais bougé — d'une initiale sur un fond aux pochoirs, puis aux bustes
3D, `ton-03` a toujours désigné le même avatar, sans migration.

### Notifications

Les lignes de `notifications` naissent dans des déclencheurs SQL
(`20261001120000_notifications.sql`) ; l'application les lit en direct
(RLS : les siennes) et les marque lues par la RPC
`marquer_notifications_lues(ids?)`. Le push part après la réponse des routes
qui produisent des événements (`pousserNotifications()`), et au cron du soir
en rattrapage. Guide : `docs/GUIDE-NOTIFICATIONS.md`.

#### `POST /api/notifications/appareil`

Enregistre le jeton de push du téléphone : `{ token, plateforme: 'android' |
'ios' }`. Le jeton est la clé : un téléphone reconnecté sous un autre compte
change de titulaire. Rend `{ ok: true, data: { enregistre: true } }`.

#### `DELETE /api/notifications/appareil`

`{ token }` — à la déconnexion, avant de fermer la session. Rend
`{ ok: true, data: { oublie: true } }`.

#### `PUT /api/profile/notifications`

`{ cours, argent, compte, ligue }`, quatre booléens, tous exigés (schéma
strict) : les catégories de push voulues. Le centre de notifications montre
tout, quelles que soient ces préférences.

### Les routes antérieures

`/api/payments/init` et `/api/payments/status` sont converties au lot D :
`authentifier()`, l'enveloppe commune, des messages français. `init` était
aussi la **deuxième** voie d'initiation de paiement — la Server Action
`initiatePayment` de l'écran boutique faisait presque la même chose en
divergeant, et c'était elle que l'interface appelait. Elle est partie avec les
écrans web ; il ne reste qu'une voie.

Deux routes ne sont **pas** converties, et ne doivent pas l'être :

- `POST /api/payments/webhook` est appelée par le fournisseur, pas par un
  étudiant. Elle s'authentifie par signature HMAC sur la charge utile brute ;
  y ajouter `authentifier()` n'aurait aucun sens, puisqu'il n'y a ni session ni
  jeton. Ses messages restent à harmoniser.
- `GET /api/jobs/run` s'authentifie par `CRON_SECRET`, que Vercel place dans
  l'en-tête des appels planifiés. Un jeton d'étudiant n'y a pas sa place.

Note : **`middleware.ts` a été retiré au lot D.** Il renouvelait le cookie de
session à chaque requête, gardait des routes qui n'existent plus et
redirigeait vers un `/connexion` supprimé — tout en réveillant Supabase pour
servir les deux pages publiques. La porte cookie d'`authentifier()` reste
écrite mais n'a plus d'appelant : si un écran web revient, il faudra remettre
le renouvellement avec lui.

Ce qui suit décrivait l'état antérieur : elles construisent leur client
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

- ~~Convertir `payments/init` et `payments/status`.~~ Fait au lot D.
  `payments/webhook` reste hors de `authentifier()`, et doit le rester : elle
  est appelée par le fournisseur, s'authentifie par signature HMAC sur la
  charge utile brute, et n'a ni session ni jeton. Ses sept messages sont en
  français et dans l'enveloppe commune — c'était la dernière chose qu'on lui
  reprochait.
- ~~Le dépôt de correction par URL signée.~~ Fait : quatre routes, voir plus
  haut.
- ~~`/api/payments/init` et la Server Action `initiatePayment` font la même
  chose.~~ La Server Action est partie avec les écrans web.
- Le cron de `/api/jobs/run` est planifié **une fois par jour** dans
  `vercel.json` (limite de l'offre Hobby), alors que le code annonce « toutes
  les minutes » : avec `BATCH_SIZE = 5`, cinq jobs par jour au plus. Plus
  rien n'enfile de job `notify` (WhatsApp abandonné le 30 septembre 2026) :
  l'étudiant est prévenu par le centre de notifications et le push, qui
  partent après la réponse des routes, sans passer par la file.

  Les traitements que l'étudiant attend ne dépendent plus de ce cron :
  `correct_copy`, `verify_card` et `ingest_course` partent depuis l'invocation
  du dépôt, et `generate_questions` avance à chaque interrogation de
  `GET /api/cours/:id`. Le cron n'est plus qu'un filet pour qui a fermé
  l'application.
- ~~La suppression de compte échoue pour tout étudiant ayant gagné un point
  d'XP.~~ Tranché : on anonymise (voir `POST /api/profile/delete`).
