# ADR-0009: APK Release Build Optimizasyonu

**Status:** Accepted
**Tarih:** 2026-05-11

## Context

Phase 4b sonrası `flutter build apk` ile üretilen debug APK **203 MB** çıktı. Kullanıcı "minimal optimize bir APK" beklediğini bildirdi. Debug APK şişkinliğinin sebepleri:

- `kernel_blob.bin` 90 MB — Dart JIT kernel (yalnız debug)
- `libflutter.so` × 3 ABI = 107 MB — debug engine (release çok daha küçük)
- `libVkLayer_khronos_validation.so` 15 MB — Vulkan validation, sadece debug
- `isolate_snapshot_data` 11 MB — debug snapshot
- Tek APK 3 ABI birden taşıyor (arm64-v8a + armeabi-v7a + x86_64)
- R8/ProGuard kapalı → kod küçültme yok
- `shrinkResources` kapalı → kullanılmayan resource'lar APK'da
- Font asset tree-shake debug build'de etkisiz

Phase 5'te sürüm yönetimi (kendi backend'den APK indir + install_plugin akışı) planlandığı için APK boyutunun küçük olması doğrudan UX'i etkiliyor: kullanıcı her sürümde 200+ MB indirmek istemez.

## Decision

Release build için aşağıdaki paket aktif edildi (`android/app/build.gradle.kts`):

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug") // Phase 5'te değişecek
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro",
        )
    }
}
```

`android/app/proguard-rules.pro` eklendi. Conservative keep kuralları:
- `io.flutter.**` (engine)
- `androidx.work.**` + `be.tramckrijte.workmanager.**` (workmanager fallback)
- `com.pravera.flutter_foreground_task.**` (LocationHub ping service)
- `com.baseflow.geolocator.**` + `com.baseflow.permissionhandler.**`
- `com.simolus3.drift.**` + `org.sqlite.**` (Drift + sqlite3_flutter_libs)
- `com.google.mlkit.**` + `com.google.android.gms.vision.**` (mobile_scanner ML Kit)
- `*Annotation*`, `Signature`, `InnerClasses`, `EnclosingMethod` attribute koruması
- `SourceFile,LineNumberTable` (release crash trace okunabilirliği)

Build komutu: `flutter build apk --release --split-per-abi`.

## Consequences

- ➕ APK 203 MB → arm64-v8a için **29.8 MB** (-85%); armeabi-v7a 26 MB, x86_64 31 MB.
- ➕ Font tree-shake otomatik: MaterialIcons 1.6 MB → 5 KB, CupertinoIcons 257 KB → 848 B.
- ➕ Phase 5 sürüm güncelleme akışında indirilen dosya küçük → daha hızlı, daha az veri.
- ➕ R8 sayesinde Dart→Java köprü kodları + plugin kalıntıları da küçülüyor.
- ➖ ProGuard yanlış kural ile bazı native paketler runtime'da kırılabilir (reflection lookup, ServiceLoader). Cihaz testi şart.
- ➖ `signingConfig = debug` hâlâ — release APK Play Store / yan yükleme için imza güvenli değil; Phase 5'in ön koşulu kendi keystore.
- 🔁 Geri almak istersek: build.gradle.kts release bloğundaki minify/shrink/proguard satırlarını kaldır + `proguard-rules.pro` dosyasını sil.

## Alternatives considered

- **Sadece split-per-abi, R8 yok** — Boyut yine düşerdi ama 50-60 MB civarı kalırdı; native plugin kalıntıları DEX'te. R8'le birlikte ek %30 kazanç olduğu için elenmedi.
- **App Bundle (.aab)** — Play Store dışı dağıtım için anlamsız (yan yükleme APK ister). Phase 5 Play Store kullanmadığı için elenmedi.
- **Tek fat APK + R8** — Tek APK 3 ABI taşıdığı için 80+ MB kalırdı; split daha agresif kazanç verir.
- **`--target-platform android-arm64` tek başına** — armeabi-v7a (32-bit eski cihazlar) kullanıcısı varsa dışlamak istemiyoruz; split her ABI için ayrı dağıtım imkânı veriyor.
