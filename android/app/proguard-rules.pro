# Keep Crashlytics line numbers + filenames so stack traces stay readable
# even after R8 obfuscation. Crashlytics symbol upload relies on this.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Firebase Crashlytics — required keep rules per official docs.
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

# Play Core (Flutter deferred components / split installs).
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Flutter's plugin registrant uses reflection on plugin classes.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# Kotlin coroutines internals occasionally trip R8.
-dontwarn kotlinx.coroutines.**

# image_picker uses reflection on activity result callbacks.
-keep class androidx.lifecycle.** { *; }

# Native methods used by Firebase + Flutter engine.
-keepclasseswithmembernames class * {
    native <methods>;
}

# Parcelables (used by intent extras across activities).
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
