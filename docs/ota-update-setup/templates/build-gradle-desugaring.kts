// Dodaj te bloki do android/app/build.gradle.kts
// Wymagane przez ota_update 7.0.0+

// W bloku android { compileOptions { ... } }:
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
}

// W bloku dependencies { }:
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
