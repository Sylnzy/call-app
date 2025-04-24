# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.facebook.imagepipeline.nativecode.WebpTranscoder
-dontwarn com.google.android.play.core.**

# Jitsi Meet SDK ProGuard Rules
-keep class org.jitsi.meet.** { *; }
-keep class org.jitsi.meet.sdk.** { *; }
-keep class com.facebook.** { *; }
-keep class com.facebook.react.** { *; }
-keep class com.oney.WebRTCModule.** { *; }
-keep class org.webrtc.** { *; }
-keep class com.reactnativecommunity.webview.** { *; }
-keep class com.swmansion.** { *; }
-keep class com.rnimmersive.** { *; }

# React Native
-keep class com.facebook.react.bridge.** { *; }
-keep class com.facebook.react.uimanager.** { *; }
-keep class com.facebook.hermes.unicode.** { *; }
-keep class com.facebook.jni.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Flutter specific
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }