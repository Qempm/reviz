# Les notifications de Reviz

> Arbitrage du 1er octobre 2026 : réglages des rappels, centre de
> notifications, et push par Firebase. Tous les événements : cours et copies,
> argent, carte étudiante, ligue.

## Comment ça marche

```
événement en base ──► déclencheur SQL ──► ligne dans `notifications`
 (cours prêt, paiement,                         │
  commission, ligue…)            ┌──────────────┴───────────────┐
                                 ▼                              ▼
                     centre de notifications           push (Firebase)
                     (cloche, toutes plateformes)      lib/notifications/envoyer.ts
```

- **La base est la source unique.** Chaque événement crée une ligne,
  par un déclencheur de `20261001120000_notifications.sql`. Une même ligne
  n'est jamais créée deux fois.
- **Le centre** (la cloche de l'en-tête) lit ces lignes. Il marche partout :
  Android, iPhone, web, avec ou sans Firebase.
- **Le push** part juste après l'événement :
  - envoyé par `pousserNotifications()` après la réponse des routes concernées
    (fin de traitement, paiement, fin de série) ;
  - rattrapé par le cron du soir (ligue close, retrait passé à la main) ;
  - jamais deux fois la même ligne (`reserver_notifications_a_pousser`) ;
  - selon les préférences de l'étudiant (Profil › Notifications et rappels).
- **Les rappels** sont programmés par le téléphone lui-même :
  - la série à l'heure choisie, 20 h par défaut ;
  - les examens à J-3 et J-1 ;
  - la fin du pack la veille.
  
  Chacun se coupe dans les mêmes réglages.

Sans configuration Firebase, **tout marche sauf le push** : l'application
compile, le centre se remplit, les rappels sonnent.

## Ce qu'il faut faire pour activer le push

### 1. Le projet Firebase (gratuit)

1. <https://console.firebase.google.com> › **Ajouter un projet** › nom
   « Reviz ». Google Analytics : inutile, décoche-le.
2. Dans le projet : **Ajouter une application** › Android › nom du paquet
   **`com.reviz.app`**. Le SHA-1 n'est pas nécessaire pour le push.
3. Télécharge `google-services.json`, mais **ne le pose pas dans le
   projet**. Ouvre-le et recopie ces valeurs dans `.env.local` :

   | `.env.local` | Dans `google-services.json` |
   |---|---|
   | `FIREBASE_PROJECT_ID` | `project_info.project_id` |
   | `FIREBASE_SENDER_ID` | `project_info.project_number` |
   | `FIREBASE_ANDROID_APP_ID` | `client[0].client_info.mobilesdk_app_id` |
   | `FIREBASE_ANDROID_API_KEY` | `client[0].api_key[0].current_key` |

   Ce sont des identifiants **publics** : ils sont embarqués dans toute
   application Firebase. `npm run apk` les compile dans l'APK.

### 2. La clé d'envoi (secrète)

1. Firebase › ⚙ Paramètres du projet › **Comptes de service** ›
   **Générer une nouvelle clé privée** : un fichier JSON se télécharge.
2. Convertis-le en base64 et mets le résultat dans `FIREBASE_SERVICE_ACCOUNT` :

   ```bash
   base64 -w0 reviz-firebase-adminsdk.json
   ```

   La variable va dans `.env.local` **et sur Vercel** (Settings ›
   Environment Variables).
3. Ce fichier permet d'écrire sur le téléphone de tous les étudiants :
   - il ne va **jamais** dans le dépôt ni dans une conversation ;
   - il n'est **jamais** préfixé `NEXT_PUBLIC_` ;
   - supprime-le de ton disque une fois recopié.

   `npm run apk` refuse de compiler s'il le voit passer.

### 3. Une nouvelle version de l'application

```bash
npm run apk
```

Le push arrive sur les téléphones qui installent cette version et qui ont
autorisé les notifications. La permission est demandée après la première
série réussie, ou depuis Profil › Notifications et rappels.

### 4. iPhone (plus tard, avec le compte Apple)

1. developer.apple.com › Identifiers › `com.reviz.app` › cocher **Push
   Notifications**. Sans cela, la signature de l'application iPhone échoue,
   car le projet déclare déjà l'entitlement `aps-environment`.
2. Keys › **+** › Apple Push Notifications service › télécharger la clé
   `.p8`.
3. Firebase › Paramètres du projet › Cloud Messaging › Application Apple :
   déposer la clé `.p8`, avec son Key ID et le Team ID.
4. Firebase › Ajouter une application › iOS › `com.reviz.app`. Recopier
   `API_KEY` et `GOOGLE_APP_ID` du `GoogleService-Info.plist` dans le groupe
   `reviz_ios` de Codemagic, sous les noms `FIREBASE_IOS_API_KEY` et
   `FIREBASE_IOS_APP_ID`. Y ajouter aussi `FIREBASE_PROJECT_ID` et
   `FIREBASE_SENDER_ID`.

## Vérifier

- **Le centre** : un statut passé à la main en base crée une ligne. Par
  exemple, un retrait passé à `paid` la fait apparaître dans la cloche de
  l'étudiant.
- **Le push** : dépose un cours, ferme l'application. « Ton cours est prêt »
  arrive quand la préparation finit. Le toucher ouvre le cours.
- **Les journaux Vercel** : `[notifications] push { reservees, envoyes,
  jetonsSupprimes }` à chaque envoi.
- **Un jeton mort** (application désinstallée) est effacé au premier envoi
  refusé par Firebase.
