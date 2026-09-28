# Fabriquer et distribuer l'APK

Ce guide décrivait une chaîne Capacitor qui ne pouvait pas s'exécuter :
`@capacitor/*` n'était pas dans `package.json`, et l'APK réel venait d'une
coquille Kotlin qui affichait le site dans une WebView. Les deux ont été
retirés au lot D. L'application est désormais un vrai client Flutter, et c'est
lui qu'on empaquette.

---

## 1. Ce qu'il faut sur la machine

| Outil | Vérification |
| --- | --- |
| Flutter 3.44 | `flutter --version` |
| JDK 17 ou plus | `java -version` |
| SDK Android avec build-tools et une plateforme | `flutter doctor` |
| Les licences du SDK acceptées | `flutter doctor --android-licenses` |

`flutter doctor` peut signaler `cmdline-tools component is missing` et
« Android license status unknown » : ce sont **deux symptômes du même manque**.
Sans `cmdline-tools`, Flutter ne sait pas lire l'état des licences, donc il le
déclare inconnu. Installer le composant depuis Android Studio (Settings →
Languages & Frameworks → Android SDK → SDK Tools → « Android SDK Command-line
Tools »), puis accepter les licences.

> **Avant de réparer, essayer.** Une compilation de débogage peut très bien
> passer alors que `flutter doctor` se plaint : le SDK a peut-être déjà tout ce
> qu'il faut. Lancer `flutter build apk --debug` et lire l'erreur réelle coûte
> moins cher que de réparer un diagnostic.

---

## 2. La configuration de l'application

Quatre valeurs sont injectées à la compilation — jamais écrites dans le code,
jamais commitées (`apps/mobile/lib/donnees/config.dart`) :

| Valeur | Rôle |
| --- | --- |
| `SUPABASE_URL` | l'API PostgREST et l'authentification |
| `SUPABASE_ANON_KEY` | la clé **anonyme**, celle que la RLS encadre |
| `API_BASE` | l'origine des routes Next.js |
| `GOOGLE_WEB_CLIENT_ID` | la connexion Google ; sans lui le bouton reste désactivé |

**La clé de service n'a rien à faire ici.** Un APK se décompile : tout ce qu'il
embarque est public. C'est la raison d'être du lot 0 de la migration — refermer
la base avant que la clé anonyme descende dans un téléphone.

---

## 3. Signer

`apps/mobile/android/app/build.gradle.kts` signe encore la release avec la clé
de **débogage**, ce que Flutter pose par défaut. Une clé propre est
indispensable : sans elle, une mise à jour ne peut pas remplacer l'installation
précédente.

Dans cet ordre — les règles d'exclusion **avant** la clé, parce qu'une clé de
signature engagée par mégarde est une clé à révoquer :

```bash
keytool -genkey -v -keystore reviz.jks -keyalg RSA -keysize 2048 -validity 10000 -alias reviz
```

Garder le fichier **hors du dépôt**, et poser ses mots de passe dans
`apps/mobile/android/key.properties`, que `.gitignore` couvre déjà :

```properties
storeFile=/chemin/absolu/vers/reviz.jks
storePassword=…
keyAlias=reviz
keyPassword=…
```

Puis faire lire ce fichier par `build.gradle.kts` et brancher un
`signingConfigs.create("release")`.

Perdre cette clé signifie ne plus jamais pouvoir mettre à jour l'application
installée. À sauvegarder ailleurs que sur la machine de développement.

---

## 4. Construire

```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=SUPABASE_URL=… \
  --dart-define=SUPABASE_ANON_KEY=… \
  --dart-define=API_BASE=https://…
```

Le fichier sort dans `build/app/outputs/flutter-apk/app-release.apk`.

`--split-per-abi` produit trois fichiers plus petits, un par architecture. Pour
une distribution par lien WhatsApp, l'APK unique est plus simple : il s'installe
partout, au prix de quelques mégaoctets.

---

## 5. La version, et l'ancienne installation

`apps/mobile/pubspec.yaml` porte `version: <nom>+<code>`. Le nom s'affiche, le
code décide des mises à jour : Android refuse d'installer un code inférieur ou
égal à celui déjà présent.

L'ancienne coquille et l'application Flutter déclarent **le même**
`applicationId` (`com.reviz.app`) avec des clés différentes. Android refusera
donc d'installer l'une par-dessus l'autre : il faut désinstaller l'ancienne
d'abord, et la page `/app` le dit.

`public/version.json` sert au contrôle de version côté application
(`apps/mobile/lib/metier/version.dart`) :

| Champ | Effet |
| --- | --- |
| `minimumVersion` | en dessous, l'application se bloque |
| `latestVersion` | au-dessus de la version installée, un bandeau propose la mise à jour |
| `maintenance` | bloque en annonçant un entretien, sans proposer de téléchargement |
| `updateUrl` | où le bandeau et l'écran bloquant envoient |

---

## 6. Distribuer

**Pas dans `public/`.** Un binaire versionné alourdit l'historique git à chaque
reconstruction, définitivement ; `.gitignore` couvre désormais `*.apk`. Publier
l'APK en **release GitHub**, et faire pointer `/app` et `version.json` vers
cette URL.

Le Play Store viendra plus tard. Il demandera un compte développeur, une fiche,
une politique de confidentialité, et un format `.aab` plutôt qu'`.apk`
(`flutter build appbundle`).

---

## 7. Vérifier avant de partager

- Installer sur un téléphone réel, après avoir désinstallé l'ancienne version.
- Se connecter par code e-mail — depuis l'APK, pas depuis le navigateur.
- Faire une session de dix questions et voir les XP monter.
- Photographier une copie et lire la note.
- Vérifier en base que `attempts`, `daily_activity`, `xp_events`,
  `profiles.xp_total` et `corrections` ont bougé.
- Couper le réseau : le bandeau apparaît, les QCM déjà chargés restent
  jouables.
