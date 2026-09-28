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

> **Essayé, et c'était bien un faux diagnostic.** Le 28 septembre 2026,
> `flutter build apk --debug` a **abouti** (exit 0, 820 s) sur une machine où
> `flutter doctor` déclarait les licences inconnues et `cmdline-tools` absent :
> le SDK avait déjà ce qu'il fallait, et les licences des paquets qui
> manquaient — CMake 3.22.1 — se sont acceptées d'elles-mêmes depuis celles
> déjà présentes. Rien n'était à réparer de ce côté. Le seul vrai blocage était
> la clé de signature, § 3. Lire l'erreur réelle coûte moins cher que de
> réparer un diagnostic : la fois précédente, 51 minutes de compilation avaient
> été dépensées à conclure le contraire.

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
| `CONTACT_WHATSAPP` | le support joignable depuis l'écran d'aide ; sans lui, l'écran n'affiche pas de contact |

**La clé de service n'a rien à faire ici.** Un APK se décompile : tout ce qu'il
embarque est public. C'est la raison d'être du lot 0 de la migration — refermer
la base avant que la clé anonyme descende dans un téléphone.

---

## 3. Signer

**Fait côté gradle, reste à faire côté clé.**
`apps/mobile/android/app/build.gradle.kts` lit `android/key.properties`, et une
compilation en release **s'arrête avec un message** quand ce fichier ou son
magasin manquent. C'est le point : la version précédente écrivait
`signingConfig = signingConfigs.getByName("debug")` sous un TODO, donc
`flutter build apk --release` rendait un APK signé par la clé de débogage —
installable, d'apparence normale, et impossible à remplacer plus tard par le
vrai, puisque Android refuse un changement de signature. Un échec bruyant vaut
mieux qu'un artefact qu'on distribue sans savoir ce qu'il vaut.

Ce qui reste, et qui n'est pas de moi : **créer la clé**. Les règles
d'exclusion sont déjà en place (`*.jks`, `*.keystore`, `**/key.properties`) —
c'était l'ordre à respecter, une clé engagée par mégarde étant une clé à
révoquer.

```bash
keytool -genkey -v -keystore ~/cles/reviz.jks   -keyalg RSA -keysize 2048 -validity 10000 -alias reviz
```

Garder le fichier `.jks` **hors du dépôt**, puis copier
`apps/mobile/android/key.properties.example` en `key.properties` dans le même
dossier et le remplir :

```properties
storeFile=C:/Users/moi/cles/reviz.jks
storePassword=…
keyAlias=reviz
keyPassword=…
```

Je n'écris ni mot de passe ni clé dans un fichier versionné : le gradle lit un
fichier ignoré que tu remplis. Le gabarit, lui, est versionné et ne contient
aucune valeur.

Perdre cette clé signifie ne plus jamais pouvoir mettre à jour l'application
installée — il faudrait changer d'`applicationId` et demander à chaque étudiant
de désinstaller. À sauvegarder ailleurs que sur la machine de développement.

Pour publier l'empreinte sur la page `/app`, et pour le client OAuth Android de
Google Sign-In :

```bash
keytool -list -v -keystore ~/cles/reviz.jks -alias reviz
```

---

## 3 bis. La connexion Google

Le code est en place : `apps/mobile/lib/donnees/google.dart` ouvre la feuille
Google et échange le jeton d'identité contre une session Supabase, **sans
sortir de l'application** — c'était la demande initiale, et
`signInWithIdToken` la satisfait sans navigateur ni détour `reviz://auth`. Le
bouton s'active tout seul dès que `GOOGLE_WEB_CLIENT_ID` est passé au build ;
sans lui il reste désactivé et l'écran le dit.

Ce qui manque n'est pas du code, ce sont **deux identifiants à créer**, dans
cet ordre — le premier dépend de la clé de signature du § 3 :

**1. Le client OAuth Android.** Google Cloud Console → APIs & Services →
Credentials → Create credentials → OAuth client ID → Android.

| Champ | Valeur |
| --- | --- |
| Package name | `com.reviz.app` |
| SHA-1 | l'empreinte du certificat de signature |

```bash
# Empreinte de la clé de release (§ 3)
keytool -list -v -keystore ~/cles/reviz.jks -alias reviz
```

> **Pour essayer avant d'avoir la clé de release**, déclarer en plus
> l'empreinte de la clé de débogage : un client OAuth accepte plusieurs
> empreintes, et `flutter build apk --debug` fonctionne déjà. Le magasin de
> débogage est `~/.android/debug.keystore`, alias `androiddebugkey`, mot de
> passe `android`. C'est la seule façon de tester Google sans attendre le
> lot de signature.

**2. Le client OAuth Web.** Même écran, type « Web application ». Il ne sert à
aucune page web ici : c'est lui que l'application passe en `serverClientId`,
et c'est donc **son** identifiant qui devient l'audience (`aud`) du jeton
d'identité rendu par Google. D'où deux conséquences :

- `GOOGLE_WEB_CLIENT_ID` dans `.env.local` reçoit **celui-là**, pas celui du
  client Android. Mettre le client Android par erreur produit un jeton
  d'identité absent, et l'application répond alors « pas encore prête de notre
  côté » plutôt qu'une erreur opaque.
- Côté Supabase — Authentication → Providers → Google —, c'est **le client web**
  qu'il faut déclarer (avec son secret), puisque c'est l'audience que Supabase
  vérifie. Si le tableau de bord propose une liste d'identifiants clients
  autorisés, le client web y va aussi.

**Rien de tout cela n'a été essayé** : il n'existe encore ni identifiant ni
appareil de test dans ce projet. Ce qui est vérifié, c'est la logique autour —
`apps/mobile/test/google_test.dart` couvre le nonce et la traduction des
échecs.

Un mot sur le nonce, parce que c'est l'inversion qui coûte le plus de temps à
trouver : **Google reçoit l'empreinte SHA-256, Supabase reçoit le nonce brut**
(`gotrue` compare l'empreinte du nonce fourni à celle inscrite dans le jeton).
Les envoyer à l'envers donne un refus dont le message ne dit rien. Deux tests
tiennent cette règle.

Et un échec à prévoir sur les Android d'entrée de gamme : sans Play Services,
la connexion Google est simplement indisponible. L'application le détecte
(`providerConfigurationError`) et renvoie vers la connexion par code e-mail,
qui reste la voie principale.

---

## 4. Construire

```bash
npm run apk
```

C'est la voie à prendre, et pas la commande brute. `flutter build apk
--release` sans `--dart-define` produit un APK qui **s'installe et démarre**,
puis affiche un bandeau rouge « configuration absente » : `Config.supabaseUrl`
est une chaîne vide, donc rien ne se connecte. Aucune étape de compilation ne
le signale, et un fichier partagé par WhatsApp ne se reprend pas.

`scripts/apk.mjs` lit donc `.env.local`, **refuse de compiler** si une valeur
manque, écarte toute variable de serveur — un APK se décompile, tout ce qu'il
embarque est public — et rend à la fin la taille et l'empreinte SHA-256 à
reporter dans `lib/metier/publication.ts`.

Les valeurs attendues sont dans `.env.example` (`API_BASE`,
`GOOGLE_WEB_CLIENT_ID`), en plus de l'URL et de la clé anonyme de Supabase.

La commande brute reste là pour un essai sans configuration :

```bash
cd apps/mobile && flutter build apk --debug
```

Le fichier sort dans `build/app/outputs/flutter-apk/app-release.apk`.

### Le poids, mesuré

| Compilation | Taille |
| --- | --- |
| `--debug` | 155,6 Mo (jamais distribué : moteur de débogage, aucune optimisation) |
| `--release`, APK unique | **55,5 Mo** |

55,5 Mo, c'est beaucoup pour le public visé : forfait data limité, partage par
WhatsApp, téléchargement la nuit avant un contrôle. Deux leviers, à décider :

```bash
npm run apk -- --split-per-abi
```

produit trois fichiers, un par architecture — environ un tiers du poids
chacun. Le coût est réel : il faut alors savoir quel fichier envoyer à qui, et
un mauvais choix ne s'installe pas. Le fichier unique reste donc le défaut,
parce qu'un téléchargement qui échoue est pire qu'un téléchargement long.

L'autre levier, moins coûteux, est d'écarter `x86_64`, qui ne sert qu'aux
émulateurs :

```bash
npm run apk -- --target-platform=android-arm,android-arm64
```

Aucun des deux n'a été mesuré ; seul le 55,5 Mo ci-dessus l'a été.

---

## 5. La version, et l'ancienne installation

`apps/mobile/pubspec.yaml` porte `version: <nom>+<code>`. Le nom s'affiche, le
code décide des mises à jour : Android refuse d'installer un code inférieur ou
égal à celui déjà présent.

L'ancienne coquille et l'application Flutter déclarent **le même**
`applicationId` (`com.reviz.app`) avec des clés différentes. Android refusera
donc d'installer l'une par-dessus l'autre : il faut désinstaller l'ancienne
d'abord, et la page `/app` le dit.

Le contrôle de version côté application
(`apps/mobile/lib/metier/version.dart`) lit `/version.json`, désormais **servi
par une route** (`app/version.json/route.ts`) qui rend
`lib/metier/publication.ts`. Le fichier statique `public/version.json` est
supprimé, pour deux raisons : un seul endroit décide de ce qui est publié — la
page `/app` et les seuils sortaient du même fait déclaré deux fois —, et un
fichier de `public/` est servi par le CDN avec un cache long, alors qu'un écran
de blocage qu'on ne peut pas lever avant un jour n'est pas un blocage mais une
panne.

Publier une version, c'est donc éditer `lib/metier/publication.ts` :

| Champ | Effet |
| --- | --- |
| `minimumVersion` | en dessous, l'application se bloque |
| `latestVersion` | au-dessus de la version installée, un bandeau propose la mise à jour |
| `maintenance` | bloque en annonçant un entretien, sans proposer de téléchargement |
| `updateUrl` | où le bandeau et l'écran bloquant envoient — dérivé de la requête, plus écrit en dur |

`VERSION_MINIMALE` ne doit **jamais** dépasser la version réellement
téléchargeable : tout le parc s'arrêterait sans issue, y compris ceux qui
viennent d'installer. `lib/metier/publication.test.ts` le vérifie.

---

## 6. Distribuer

**Pas dans `public/`.** Un binaire versionné alourdit l'historique git à chaque
reconstruction, définitivement ; `.gitignore` couvre désormais `*.apk`. Publier
l'APK en **release GitHub**, puis renseigner `APK` dans
`lib/metier/publication.ts` — l'URL de l'asset, sa taille en octets et son
empreinte SHA-256 (`sha256sum app-release.apk`). La page `/app` affiche alors
le bouton de téléchargement, et `/version.json` porte le lien ; tant que `APK`
vaut `{ publie: false }`, la page annonce honnêtement que le fichier n'est pas
signé plutôt que de proposer un lien mort.

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
