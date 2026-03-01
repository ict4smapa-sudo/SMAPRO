// =============================================================================
// File        : build.gradle.kts (Root)
// Fungsi      : Konfigurasi Gradle root untuk semua subproject Exambro Smapa.
// Environment : Flutter 3.41.2, AGP 8.x, Kotlin DSL, Java 17
// =============================================================================

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Flutter tools mengharapkan APK di <project>/build/app/outputs/flutter-apk/
// Custom build dir dibutuhkan agar path ini terpenuhi.
// Cross-drive Kotlin cache error (C: vs D:) sudah diatasi via kotlin.incremental=false
// di gradle.properties — sehingga custom build dir aman untuk dipakai kembali.
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// =============================================================================
// GLOBAL FIX 1: Force JVM 17 untuk SEMUA subproject
//
// gradle.projectsEvaluated berjalan SETELAH semua plugin selesai konfigurasi
// sehingga force kita tidak bisa ditimpa oleh default AGP (1.8).
// =============================================================================
gradle.projectsEvaluated {
    subprojects {
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

// =============================================================================
// GLOBAL FIX 2: AGP 8.0+ Namespace + compileSdk + Manifest untuk plugin legacy
//
// KRITIS: compileSdk HARUS di-set saat plugin di-apply (bukan di afterEvaluate
// atau gradle.projectsEvaluated — akan error "too late to set compileSdk").
// plugins.withId("com.android.library") berjalan tepat saat apply → timing benar.
//
// Fix yang diaplikasikan:
// a. namespace     : inject otomatis jika null (AGP 8.0+ wajib namespace)
// b. compileSdk    : force ke 36 agar attribute API 31+ (lStar dll) tersedia
// c. Manifest fix  : hapus package="..." yang dilarang AGP 8.0+
// =============================================================================
subprojects {
    // plugins.withId berjalan SAAT plugin di-apply — sebelum project dievaluasi.
    // Ini satu-satunya timing yang benar untuk mengubah compileSdk di plugin.
    plugins.withId("com.android.library") {
        val android = extensions.getByType<com.android.build.gradle.LibraryExtension>()

        // a. Namespace otomatis
        if (android.namespace == null) {
            android.namespace = "id.sch.sman4jember.${project.name.replace("-", ".")}"
        }

        // b. Force compileSdk=36 — fix "resource android:attr/lStar not found"
        //    lStar attribute hanya ada di API 31+; kiosk_mode defaultnya compile lebih rendah.
        android.compileSdk = 36
    }

    // Manifest package auto-remove (berjalan saat task mulai)
    plugins.withType<com.android.build.gradle.api.AndroidBasePlugin> {
        project.tasks.matching { it.name.contains("Manifest") }.configureEach {
            doFirst {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val content = manifestFile.readText()
                    if (content.contains("package=")) {
                        val updatedContent =
                            content.replace(Regex("""package\s*=\s*"[^"]*""""), "")
                        manifestFile.writeText(updatedContent)
                        println(">> [Smapa Auto-Fix] Manifest dibersihkan: ${project.name}")
                    }
                }
            }
        }
    }
}