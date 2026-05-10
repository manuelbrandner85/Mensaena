// 1:1 Pattern aus Weltenbibliothekapp/android/app/build.gradle.kts:
// - Persistenter Release-Keystore über key.properties
// - hasReleaseKeystore-Flag (statt File-Existence-Check) — Weltenbibliothek-Pattern
// - signingConfigs.create("release") nur wenn Keystore vorhanden ist
//   (verhindert dass AGP eine "release"-Config mit null-Werten registriert
//   und dann unsigniert exportiert)

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Cloud Messaging — wendet google-services.json an.
    id("com.google.gms.google-services")
}

// Release-Keystore laden (persistenter Key für APK-Updates ohne Deinstallation).
// Quelle: android/key.properties → wird in CI aus GitHub-Secrets erzeugt.
// Lokal ohne key.properties bleibt der Release-Build debug-signiert.
val keystorePropsFile = rootProject.file("key.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) {
        load(FileInputStream(keystorePropsFile))
    }
}
val hasReleaseKeystore = keystoreProps.getProperty("storeFile")?.isNotBlank() == true

android {
    namespace = "de.mensaena.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "de.mensaena.app"
        // flutter_sound 9.x braucht minSdk 24
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ARM64 (moderne Geräte) + ARM32 (ältere/32-bit Geräte)
        // x86_64 wird weggelassen — Shorebird unterstützt es nicht im Prod-Release
        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
        }
    }

    signingConfigs {
        // Persistenter Release-Key (nur wenn key.properties vorhanden).
        // Damit sind alle zukünftigen APKs mit dem gleichen Key signiert →
        // User können Updates ohne Deinstallation installieren.
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Fallback: Debug-Key (nur Dev / lokaler `flutter run --release`).
                // CI setzt IMMER key.properties aus den Secrets.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
