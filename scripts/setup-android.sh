#!/usr/bin/env bash
# ================================================================
# Mensaena – Android Setup Script
# Führt einmalig aus: Android-Init, Icons, Splash, APK-Name
# Voraussetzung: Android Studio + SDK installiert
# ================================================================
set -e

echo "🚀 Mensaena Android Setup..."

# 1. Android-Projekt anlegen (falls noch nicht vorhanden)
if [ ! -d "android" ]; then
  echo "🤖 Initialisiere Android-Projekt..."
  npx cap add android
fi

# 2. Capacitor-Config & Web-Assets synchronisieren
echo "🔄 Synchronisiere Capacitor..."
npx cap sync android

# 3. Icons & Splash NACH dem android-Init generieren
#    (braucht @capacitor/assets und sharp)
echo "📱 Generiere App-Icons und Splash-Screen aus assets/..."
npx @capacitor/assets generate \
  --iconPath assets/icon-only.png \
  --splashPath assets/splash.png \
  --android

# 4. APK-Output auf mensaena.apk umbenennen
GRADLE="android/app/build.gradle"
if ! grep -q "mensaena" "$GRADLE"; then
  echo "✏️  Konfiguriere APK-Dateinamen (mensaena.apk)..."
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
echo "APK bauen (Release):"
echo "  cd android && ./gradlew assembleRelease"
echo ""
echo "APK-Datei landet in:"
echo "  android/app/build/outputs/apk/release/mensaena-release.apk"
echo ""
echo "⚠️  Für Release-APK musst du einen Signing-Key konfigurieren:"
echo "  Siehe: https://developer.android.com/studio/publish/app-signing"
