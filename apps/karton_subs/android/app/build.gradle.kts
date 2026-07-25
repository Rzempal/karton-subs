plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.michalrapala.zostaje"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // AIDL: duplikaty kontraktu Lokalnego Silnika AI (src/main/aidl) - mostek OCR rachunkow.
    buildFeatures {
        aidl = true
    }

    flavorDimensions += "channel"

    productFlavors {
        create("production") {
            dimension = "channel"
            applicationId = "app.michalrapala.zostaje"
            resValue("string", "app_name", "Zostaje")
        }
        create("internal") {
            dimension = "channel"
            applicationId = "app.michalrapala.zostaje.dev"
            resValue("string", "app_name", "Zostaje DEV")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Reguly R8 (m.in. warianty jezykowe ML Kit, ktorych nie dolaczamy).
            proguardFiles("proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
