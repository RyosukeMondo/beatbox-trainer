# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Permission handler plugin
-keep class com.baseflow.permissionhandler.** { *; }

# Keep native methods (JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Rust FFI bridge code
-keep class io.flutter.plugins.** { *; }

# Don't warn about missing classes
-dontwarn io.flutter.embedding.**

# Preserve line numbers for debugging stack traces
-keepattributes SourceFile,LineNumberTable

# Keep custom exceptions for better crash reports
-keep public class * extends java.lang.Exception
