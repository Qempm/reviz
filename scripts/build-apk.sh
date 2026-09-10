#!/bin/bash

# Script de build APK pour Reviz
# Usage: ./scripts/build-apk.sh [debug|release]

set -e

BUILD_TYPE=${1:-debug}
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)

echo "🔨 Building Reviz APK ($BUILD_TYPE)"
echo "Project root: $PROJECT_ROOT"

# 1. Build Next.js
echo "📦 Building Next.js..."
cd "$PROJECT_ROOT"
npm run build

# 2. Sync Capacitor
echo "📱 Syncing Capacitor..."
npx cap sync android

# 3. Build Android
echo "🤖 Building Android APK..."
cd "$PROJECT_ROOT/apps/android"

if [ "$BUILD_TYPE" = "release" ]; then
  echo "⚙️ Building release APK (requires keystore)..."
  ./gradlew assembleRelease
  APK_PATH="app/build/outputs/apk/release/app-release.apk"
else
  echo "⚙️ Building debug APK..."
  ./gradlew assembleDebug
  APK_PATH="app/build/outputs/apk/debug/app-debug.apk"
fi

# 4. Output
if [ -f "$APK_PATH" ]; then
  APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
  echo ""
  echo "✅ Build successful!"
  echo "📁 APK location: $APK_PATH"
  echo "📊 APK size: $APK_SIZE"
  echo ""
  echo "Next steps:"
  if [ "$BUILD_TYPE" = "debug" ]; then
    echo "  - Install: adb install -r $APK_PATH"
    echo "  - Or: drag to Android Studio emulator"
  else
    echo "  - Upload to Play Store / web server"
    echo "  - Sign with release keystore"
  fi
else
  echo "❌ Build failed - APK not found at $APK_PATH"
  exit 1
fi
