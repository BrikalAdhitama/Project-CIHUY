import groovy.json.JsonSlurper
import java.net.URI
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/// Membaca konfigurasi lokal (tidak masuk Git) ketika `flutter run/build`
/// dipanggil tanpa `--dart-define-from-file`. Nilai yang diberikan lewat
/// command line selalu menang.
fun dartDefineName(encoded: String): String? = runCatching {
    String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
        .substringBefore('=')
}.getOrNull()

fun localDartDefines(file: File, skip: Set<String>): String? {
    if (!file.isFile) return null
    val config = JsonSlurper().parse(file)
    if (config !is Map<*, *>) return null
    return config.entries
        .mapNotNull { entry ->
            val key = entry.key?.toString() ?: return@mapNotNull null
            val value = entry.value?.toString()?.trim().orEmpty()
            if (!key.matches(Regex("^[A-Z][A-Z0-9_]*$")) ||
                key in skip ||
                value.isEmpty()
            ) {
                return@mapNotNull null
            }
            Base64.getEncoder().encodeToString(
                "$key=$value".toByteArray(Charsets.UTF_8)
            )
        }
        .joinToString(",")
        .ifEmpty { null }
}

// Flutter selalu mengirim dart-defines untuk metadata build. Tambahkan
// konfigurasi lokal hanya jika kunci OAuth/Supabase belum diberikan lewat
// command line, sehingga `flutter run` biasa tetap dapat login Google.
val existingDartDefines = project.findProperty("dart-defines")?.toString().orEmpty()
val existingDartDefineNames = existingDartDefines
    .split(',')
    .filter { it.isNotBlank() }
    .mapNotNull(::dartDefineName)
    .toSet()
val requiredDartDefines = setOf(
    "SUPABASE_URL",
    "SUPABASE_PUBLISHABLE_KEY",
    "GOOGLE_WEB_CLIENT_ID",
)
if (!existingDartDefineNames.containsAll(requiredDartDefines)) {
    val localConfig = rootProject.projectDir.parentFile.resolve("supabase.local.json")
    runCatching { localDartDefines(localConfig, existingDartDefineNames) }
        .onSuccess { defines ->
            if (defines != null) {
                val merged = listOf(existingDartDefines, defines)
                    .filter { it.isNotBlank() }
                    .joinToString(",")
                project.extensions.extraProperties.set("dart-defines", merged)
                logger.lifecycle("CIHUY: konfigurasi lokal dibaca dari supabase.local.json")
            }
        }
        .onFailure { error ->
            logger.warn("CIHUY: supabase.local.json tidak dapat dibaca: ${error.message}")
        }
}

/// Kredensial rilis dibaca dari `android/key.properties` (tidak masuk Git).
/// Build release wajib memakai upload key; tidak boleh fallback ke debug.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore =
    keystorePropertiesFile.exists() &&
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            .all { !keystoreProperties.getProperty(it).isNullOrBlank() }

val validateReleaseConfiguration = tasks.register("validateReleaseConfiguration") {
    doLast {
        check(hasReleaseKeystore) {
            "CIHUY: lengkapi android/key.properties dengan upload keystore. Debug key tidak diizinkan untuk release."
        }
        check(file(keystoreProperties.getProperty("storeFile")).isFile) {
            "CIHUY: upload keystore tidak ditemukan."
        }
        val defines = project.findProperty("dart-defines")?.toString().orEmpty()
            .split(',').filter { it.isNotBlank() }.associate {
                val decoded = String(Base64.getDecoder().decode(it), Charsets.UTF_8)
                decoded.substringBefore('=') to decoded.substringAfter('=', "")
            }
        check(requiredDartDefines.all { !defines[it].isNullOrBlank() }) {
            "CIHUY: konfigurasi Supabase dan Google OAuth wajib tersedia untuk release."
        }
        check(!defines["DEVELOPER_NAME"].isNullOrBlank() &&
            defines["SUPPORT_EMAIL"].orEmpty().matches(Regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"))) {
            "CIHUY: isi DEVELOPER_NAME dan SUPPORT_EMAIL di release.local.json."
        }
        for (key in listOf("PRIVACY_POLICY_URL", "ACCOUNT_DELETION_URL")) {
            val uri = runCatching { URI(defines[key].orEmpty()) }.getOrNull()
            check(uri?.scheme == "https" && !uri.host.isNullOrBlank()) {
                "CIHUY: $key wajib berupa URL HTTPS. Gunakan --dart-define-from-file=release.local.json."
            }
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseConfiguration)
}

android {
    namespace = "com.brikal.cihuy"
    // androidx.core 1.19 (lewat flutter_local_notifications 23) membutuhkan
    // compileSdk 37. targetSdk tetap mengikuti Flutter (36).
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.brikal.cihuy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
