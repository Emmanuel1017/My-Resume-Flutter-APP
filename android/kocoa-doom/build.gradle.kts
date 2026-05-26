plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.hiperbou.kocoaDoom"
    compileSdk = 34

    defaultConfig {
        minSdk = 21
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            kotlin.srcDirs("src/main/kotlin", "src/main/java")
        }
    }

    lint {
        abortOnError = false
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
