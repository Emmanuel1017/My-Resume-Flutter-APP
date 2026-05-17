plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.portfolio_admin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications — backports java.time APIs
        // (used internally for notification scheduling) onto older Android.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.portfolio_admin"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Only ship ARM binaries — drops ~30 % APK size and avoids x86
        // code paths that don't benefit from Vulkan/Impeller optimisations.
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")

            // R8 full mode: whole-program optimisation, inlining, and dead-code
            // elimination across all classes including Flutter/Firebase deps.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Keep debug fast — no shrinking or obfuscation.
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Provides the runtime backport classes that the desugaring above rewrites
    // bytecode to call. Pinned to the latest 2.x line.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
