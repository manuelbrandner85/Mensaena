#!/usr/bin/env bash
# ================================================================
# Mensaena – Android Setup Script
# Führt einmalig aus: Icons, Splash, APK-Name, Android-Init
# Voraussetzung: Android Studio + SDK installiert
# ================================================================
set -e

echo "🚀 Mensaena Android Setup..."

# 1. Icons & Splash aus assets/ generieren (braucht sharp)
echo "📱 Generiere App-Icons und Splash-Screen..."
npx @capacitor/assets generate \
  --iconPath assets/icon-only.png \
  --splashPath assets/splash.png \
  --pwaManifestPath public/manifest.json \
  --android \
  --ios

# 2. Android-Projekt anlegen (falls noch nicht vorhanden)
if [ ! -d "android" ]; then
  echo "🤖 Initialisiere Android-Projekt..."
  npx cap add android
fi

# 3. Capacitor-Config & Web-Assets synchronisieren
echo "🔄 Synchronisiere Capacitor..."
npx cap sync android

# 4. APK-Output auf mensaena.apk umbenennen
GRADLE="android/app/build.gradle"
if ! grep -q "mensaena" "$GRADLE"; then
  echo "✏️  Konfiguriere APK-Dateinamen (mensaena.apk)..."
  # Füge applicationVariants-Block nach dem android { Block ein
  sed -i '/^android {/a\
\
    applicationVariants.all { variant ->\
        variant.outputs.all {\
            outputFileName = "mensaena-${variant.name}.apk"\
        }\
    }' "$GRADLE"
fi

echo ""
echo "✅ Setup abgeschlossen!"
echo ""
echo "APK bauen:"
echo "  Debug:   cd android && ./gradlew assembleDebug"
echo "  Release: cd android && ./gradlew assembleRelease"
echo ""
echo "APK-Dateien landen in:"
echo "  android/app/build/outputs/apk/debug/mensaena-debug.apk"
echo "  android/app/build/outputs/apk/release/mensaena-release.apk"
