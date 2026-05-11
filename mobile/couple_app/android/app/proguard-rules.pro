# Flutter / Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# AndroidX & Kotlin
-dontwarn kotlinx.**
-dontwarn kotlin.**

# WorkManager (workmanager paketi 15dk fallback için kullanıyor)
-keep class androidx.work.** { *; }
-keep class be.tramckrijte.workmanager.** { *; }

# flutter_foreground_task (LocationHub'a ping atan foreground service)
-keep class com.pravera.flutter_foreground_task.** { *; }

# Geolocator (LocationManager binding)
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }

# Drift / sqlite3_flutter_libs (native sqlite + reflection ile sınıf adı çözümleme)
-keep class com.simolus3.drift.** { *; }
-keep class org.sqlite.** { *; }

# mobile_scanner — ML Kit Barcode (libbarhopper_v3, davet QR tarama)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.mlkit.**

# qr_flutter / zxing (davet QR üretme — utility paketi, çoğunlukla pure Dart)

# signalr_netcore (chat hub) — pure Dart, native dependency yok

# Tyrus/OkHttp (Dio + SignalR transport)
-dontwarn okhttp3.**
-dontwarn okio.**

# Annotation'lar — kaybolursa generated kod kırılır
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Stack trace okunabilirliği (release crash report'larında dosya/satır)
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
