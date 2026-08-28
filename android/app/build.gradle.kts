import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Release signing ---------------------------------------------------------
//
// Play Store builds must be signed with the UPLOAD KEY, which is a secret only
// the maintainer holds. It is configured through `android/key.properties`, a
// file that is gitignored (both here and in the repo-root .gitignore) and must
// NEVER be committed — this repository is public.
//
// key.properties is a plain java.util.Properties file with four keys:
//
//     storeFile=/absolute/path/outside/this/repo/dindin-upload-key.jks
//     storePassword=...
//     keyAlias=upload
//     keyPassword=...
//
// See docs/DEPLOY.md ("Android release") for how to generate the keystore and
// where to keep its backup.
//
// GRACEFUL FALLBACK: if key.properties is absent — a fresh clone, CI, anyone
// who is not the maintainer — release builds fall back to the debug key, so
// `flutter build apk/appbundle --release` and `flutter run --release` still
// work for local verification. A debug-signed bundle is REJECTED by Play, so
// this fallback cannot accidentally produce a "real" release; the warning
// below makes it obvious which key was used.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties =
    Properties().apply {
        if (keystorePropertiesFile.exists()) {
            keystorePropertiesFile.inputStream().use { load(it) }
        }
    }
val hasUploadKeystore =
    keystorePropertiesFile.exists() &&
        !keystoreProperties.getProperty("storeFile").isNullOrBlank()

android {
    namespace = "com.cafelabs.dindin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // PERMANENT once published on Google Play — the application id can
        // never be changed for an existing listing. Matches the `namespace`
        // above and the package registered in android/app/google-services.json.
        applicationId = "com.cafelabs.dindin"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Both come from pubspec.yaml's `version: <versionName>+<versionCode>`.
        // versionCode must increase by at least 1 on EVERY upload to Play,
        // forever — see docs/DEPLOY.md ("Versioning").
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKeystore) {
            create("release") {
                // An absolute path in key.properties is resolved as-is; a
                // relative one would resolve against android/app/, which is
                // why docs/DEPLOY.md tells you to use an absolute path to a
                // location OUTSIDE the repository.
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasUploadKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

// Loud warning when a release artifact is produced without the upload key.
// Only fires for release-ish Gradle tasks so day-to-day debug builds stay
// quiet. Emitted at ERROR level (not WARN) purely so it survives the output
// filtering `flutter build` applies to Gradle's console — at WARN level it was
// swallowed entirely (verified on Flutter 3.44.4). It does NOT fail the build.
// A future Flutter version could filter this too, so the authoritative guards
// stay scripts/release_android.sh's preflight (refuses to build at all without
// key.properties) and its post-build check of the bundle's real signer
// certificate.
if (!hasUploadKeystore &&
    gradle.startParameter.taskNames.any {
        it.contains("Release", ignoreCase = true) || it.contains("Bundle", ignoreCase = true)
    }
) {
    logger.error(
        "\n" +
            "*******************************************************************\n" +
            "  android/key.properties not found — this RELEASE build is signed\n" +
            "  with the DEBUG key. Google Play WILL REJECT the resulting bundle.\n" +
            "  Fine for local verification and CI; see docs/DEPLOY.md before\n" +
            "  building anything meant for the Play Console.\n" +
            "*******************************************************************\n",
    )
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
