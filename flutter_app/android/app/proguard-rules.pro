# Flutter Engine (Plugin-Reflection)
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep flutter_callkit_incoming reflection-based classes.
# Plugin uses BroadcastReceiver + Service classes that R8 would strip
# without these rules, leading to Cold-Start crashes in obfuscated builds.
-keep class com.hiennv.flutter_callkit_incoming.** { *; }

# LiveKit / WebRTC native bridge.
-keep class org.webrtc.** { *; }
-keep class io.livekit.** { *; }

# Firebase Messaging — service classes need reflection.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keepclassmembers class * extends com.google.firebase.iid.FirebaseInstanceIdService { *; }
-keepclassmembers class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }

# Supabase / GoTrue / PostgREST — keep reflection-accessed fields.
-keep class io.supabase.** { *; }
-keepclassmembers class * { @kotlinx.serialization.Serializable *; }

# Serializable (Dart-JSON serialization über reflection)
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Image-Picker / Camera Plugins (Resource-Reflection)
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.camera.** { *; }

# Geolocator / Permission-Handler
-keep class com.baseflow.** { *; }

# Google Play Core (Deferred-Components, Split-Install) — R8 erwartet
# diese Klassen weil Flutter sie referenziert für App-Bundles, aber wir
# nutzen sie nicht aktiv. Müssen aber als dontwarn drin sein.
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.**

# Don't warn on missing optional classes
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
