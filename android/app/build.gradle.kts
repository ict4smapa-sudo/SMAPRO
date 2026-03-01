// =============================================================================
// File        : build.gradle.kts (App)
// Fungsi      : Konfigurasi build aplikasi Exambro SMAN 4 Jember.
// Environment : Flutter 3.41.2, AGP 8.x, compileSdk 36, minSdk 21, targetSdk 34
// =============================================================================

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.sman4jember.exambro_sman4jember"

    // compileSdk 36 — wajib untuk shared_preferences & webview_flutter terbaru
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Java 17 — WAJIB sama dengan KotlinCompile jvmTarget untuk menghindari
        // "Inconsistent JVM-target compatibility" error di Gradle 8.x
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // WAJIB "17" (bukan JavaVersion.VERSION_17.toString() yang mungkin return "17")
        // untuk memastikan string exact match dengan JavaCompile output
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "id.sman4jember.exambro_sman4jember"

        // minSdk 21 — HP siswa Android 5.0+ (Lollipop ke atas) tetap bisa ujian
        minSdk = flutter.minSdkVersion

        // targetSdk 34 — stabil di Android 9-14, kompatibel dengan fitur keamanan
        // FLAG_SECURE, kiosk_mode App Pinning, dan WebView Moodle
        targetSdk = 34

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
