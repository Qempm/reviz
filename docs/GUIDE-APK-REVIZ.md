# Guide de Build APK Reviz avec Capacitor

Ce guide explique comment construire et distribuer l'APK Reviz sur Android.

## Architecture

Reviz est une **PWA emboitee dans une coquille Capacitor**:
- **Frontend**: Next.js 15 (web app)
- **Coquille mobile**: Capacitor (WebView wrapper)
- **Backend**: Supabase + DeepSeek IA

La coquille Capacitor:
- Charge l'app Next.js deployee sur Vercel
- Offre acces aux APIs natives Android (camera, fichiers, notifications)
- Gere la mise a jour de l'app (versioning)

## Prerequis

- Node.js 18+
- JDK 11+
- Android SDK 36 (API level)
- Gradle 8.5+
- Vercel deployment de Reviz (NEXT_PUBLIC_VERCEL_URL)

## Etapes de build

### 1. Build Next.js pour production

```bash
cd /path/to/reviz
npm run build
# Genere .next/ avec tous les assets
```

### 2. Configurer Capacitor (premiere fois)

```bash
npm install @capacitor/core @capacitor/android
npx cap init reviz com.reviz.app
```

Cela cree:
- `capacitor.config.json` : configuration globale
- `apps/android/` : projet Android studio

### 3. Configuration capacitor.config.json

```json
{
  "appId": "com.reviz.app",
  "appName": "Reviz",
  "webDir": "out",
  "server": {
    "url": "https://reviz-eight.vercel.app",
    "cleartext": false
  },
  "android": {
    "webContentsDebuggingEnabled": false,
    "useLegacyBridge": false
  },
  "plugins": {
    "SplashScreen": {
      "launchShowDuration": 3000,
      "backgroundColor": "#fcf9f8"
    }
  }
}
```

### 4. Sync avec Android

```bash
npx cap sync android
# Copie les assets web dans le projet Android
```

### 5. Build Android

#### Build Debug (pour testing)

```bash
cd apps/android
./gradlew assembleDebug
# Produit: app/build/outputs/apk/debug/app-debug.apk
```

#### Build Release (pour Play Store)

```bash
cd apps/android
# 1. Cree un keystore pour signer l'APK
keytool -genkey -v -keystore reviz-release-key.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias reviz-release

# 2. Configure le signing dans app/build.gradle.kts
# 3. Build release
./gradlew assembleRelease
# Produit: app/build/outputs/apk/release/app-release.apk
```

## Distribution

### Web direct (recommande pour MVP)

1. Upload l'APK sur serveur: `https://reviz-eight.vercel.app/reviz-latest.apk`
2. Partage le lien WhatsApp / QR code
3. Utilisateurs telecharge et installe manuellement

### Google Play Store

1. Cree un compte developer Google Play ($25 one-time)
2. Signe l'APK release (voir keystore ci-dessus)
3. Upload `app-release.apk` et configure:
   - Titre: "Reviz - Revision pour etudiants"
   - Description: texte marketing
   - Screenshots: 5 en 1440x900
   - Icone: 512x512
4. Soumet pour review (3-24h)

## Versioning

- Incrementer `versionCode` et `versionName` dans `apps/android/app/build.gradle.kts`
- Version app Next.js dans `/version.json`
- Middleware verifie minimumVersion et force update si necessaire

Exemple:
```kotlin
versionCode = 2        // Incrementer a chaque build
versionName = "1.0.1"  // Semantic versioning
```

## Troubleshooting

### Erreur: "Web directory not found"

```bash
npm run build
npx cap sync android
```

### APK n'affiche rien

- Verifie `capacitor.config.json` `server.url` pointe vers Vercel
- Verifie Android a acces internet (manifest permissions)
- Debug via Chrome: `chrome://inspect` sur desktop

### Offline ne fonctionne pas

- Verifie service worker dans `.next/`
- Verifie fichiers caches dans `public/` (icons, manifest)
- Test offline mode: DevTools > Network > Offline

## Ressources

- Capacitor docs: https://capacitorjs.com/docs
- Android Studio: https://developer.android.com/studio
- Play Console: https://play.google.com/console
- Reviz CLAUDE.md: configuration stack complete
