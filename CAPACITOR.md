# Capacitor & APK Build Guide

Reviz est distribué comme:
1. **PWA web** hébergée sur Vercel (`reviz-eight.vercel.app`)
2. **APK Android** emboitée Capacitor (coquille WebView)

## Quick Start

### Build APK (debug)

```bash
# 1. Build Next.js
npm run build

# 2. Build Android APK
bash scripts/build-apk.sh debug

# 3. Install sur device/emulateur
adb install -r apps/android/app/build/outputs/apk/debug/app-debug.apk
```

### Build APK (release pour Play Store)

```bash
# 1. Prepare keystore
cd apps/android
keytool -genkey -v -keystore reviz-release.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias reviz-key

# 2. Configure signing in app/build.gradle.kts
# 3. Build release
bash scripts/build-apk.sh release

# 4. Output: apps/android/app/build/outputs/apk/release/app-release.apk
```

## Architecture

### Web (Next.js)

```
reviz-eight.vercel.app/
├── / (auth login)
├── /inscription (signup)
├── /(app)/ (main app with BottomNav)
│   ├── /reviser (study)
│   ├── /corriger (submit copy)
│   ├── /gains (wallet)
│   ├── /classement (leaderboard)
│   ├── /profil (profile)
│   └── ...
├── /app (APK download page)
├── /api/* (backend routes)
└── /version.json (version check)
```

### Android (Capacitor)

```
apps/android/
├── gradle.properties (build config)
├── build.gradle.kts (project config)
├── settings.gradle.kts (modules)
├── local.properties (SDK location)
└── app/
    ├── build.gradle.kts (app config)
    ├── src/
    │   ├── main/
    │   │   ├── AndroidManifest.xml (permissions, activities)
    │   │   ├── java/com/reviz/app/
    │   │   │   └── MainActivity.kt (WebView entry point)
    │   │   └── res/ (strings, colors, icons)
    │   ├── test/ (unit tests)
    │   └── androidTest/ (integration tests)
    └── build/outputs/apk/ (build artifacts)

capacitor.config.json (Capacitor settings)
├── appId: "com.reviz.app"
├── webDir: "out" (Next.js output)
├── server.url: "https://reviz-eight.vercel.app" (web app URL)
└── plugins.SplashScreen (launch screen)
```

## Version Management

### APK version (Android)

- **versionCode**: incrementing integer (1, 2, 3...)
- **versionName**: semantic version ("1.0.0", "1.0.1"...)

Location: `apps/android/app/build.gradle.kts`

```kotlin
android {
  defaultConfig {
    versionCode = 1
    versionName = "1.0.0"
  }
}
```

### Web version (Next.js)

- **version**: current app version
- **minimumVersion**: force update if less than this
- **latestVersion**: suggest update if less than this

Location: `public/version.json`

```json
{
  "version": "1.0.0",
  "minimumVersion": "1.0.0",
  "latestVersion": "1.0.0"
}
```

### Version check flow

1. User launches APK
2. `useVersionCheck()` hook fetches `/version.json`
3. Compares local version vs minimumVersion
4. If update required: redirect to `/mise-a-jour-requise`
5. If update available: show notification with link

## Permissions

Android permissions are declared in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

Runtime permissions (camera, storage) are requested by the app when needed.

## Testing

### Debug on device

```bash
# Build and install
adb install -r apps/android/app/build/outputs/apk/debug/app-debug.apk

# View logs
adb logcat | grep "reviz\|capacitor"

# Open DevTools
chrome://inspect
# Select reviz app and click "inspect"
```

### Emulator

```bash
# Start Android emulator
emulator -avd Pixel_5_API_36

# Install APK
adb install apps/android/app/build/outputs/apk/debug/app-debug.apk

# View in emulator
adb shell input keyevent 3 # Press Home
```

## Deployment

### Web app

```bash
# Vercel auto-deploys on push to main
git push origin main
# Check: https://reviz-eight.vercel.app
```

### APK distribution

#### Option 1: Direct link (MVP)

1. Upload APK to Vercel:
   ```bash
   cp apps/android/app/build/outputs/apk/debug/app-debug.apk public/reviz-1.0.0.apk
   git push
   ```

2. Share download link: `https://reviz-eight.vercel.app/reviz-1.0.0.apk`

3. Users can download and install manually

#### Option 2: Google Play Store

1. Create Google Play Developer account ($25)
2. Configure signing (see keystore section above)
3. Build release APK:
   ```bash
   bash scripts/build-apk.sh release
   ```
4. Upload to Play Console
5. Submit for review (3-24h)

## Troubleshooting

### APK won't load web app

- Check `capacitor.config.json` `server.url`
- Verify device has internet connection
- Check Vercel deployment is live
- View logs: `adb logcat | grep capacitor`

### Offline not working

- Service Worker must be in `.next/public/`
- PWA manifest must be served
- Test offline: DevTools > Network > Offline

### Build fails

- Run `npx cap clean android` then retry
- Update Gradle: `./gradlew wrapper --gradle-version latest`
- Clear Android Studio cache: Build > Clean Project

## References

- [Capacitor docs](https://capacitorjs.com/docs)
- [Android Studio](https://developer.android.com/studio)
- [Google Play Console](https://play.google.com/console)
- [Gradle documentation](https://gradle.org/docs)
