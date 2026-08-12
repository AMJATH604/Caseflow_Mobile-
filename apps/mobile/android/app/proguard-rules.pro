# ══════════════════════════════════════════════════════════════
# CaseFlow ProGuard Rules — Production Release
# ══════════════════════════════════════════════════════════════

# ─── Flutter ──────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ─── Firebase ─────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ─── Firebase Crashlytics ─────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# ─── Firebase Messaging (FCM) ────────────────────────────────
-keep class com.google.firebase.messaging.** { *; }

# ─── Google ML Kit Text Recognition (OCR) ────────────────────
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.chinese.**

# ─── Supabase / GoTrue / Realtime ─────────────────────────────
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# ─── OkHttp / Retrofit (used by some plugins) ────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# ─── Gson (used by Firebase & other libs) ─────────────────────
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# ─── Image processing plugins ────────────────────────────────
-keep class com.shockwave.** { *; }
-dontwarn com.shockwave.**

# ─── Flutter Local Notifications ──────────────────────────────
-keep class com.dexterous.** { *; }

# ─── Connectivity Plus ────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ─── SQLite (sqflite) ────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }

# ─── Prevent R8 from stripping annotations ───────────────────
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations

# ─── General Android ─────────────────────────────────────────
-keep class androidx.** { *; }
-dontwarn androidx.**
-keep class android.** { *; }
-dontwarn android.**
