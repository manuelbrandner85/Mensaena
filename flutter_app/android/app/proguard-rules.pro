# Keep flutter_callkit_incoming reflection-based classes.
# Plugin uses BroadcastReceiver + Service classes that R8 would strip
# without these rules, leading to Cold-Start crashes in obfuscated builds.
-keep class com.hiennv.flutter_callkit_incoming.** { *; }

# LiveKit / WebRTC native bridge.
-keep class org.webrtc.** { *; }
-keep class io.livekit.** { *; }

# Firebase Messaging — service classes need reflection.
-keep class com.google.firebase.** { *; }
-keepclassmembers class * extends com.google.firebase.iid.FirebaseInstanceIdService { *; }
-keepclassmembers class * extends com.google.firebase.messaging.FirebaseMessagingService { *; }
