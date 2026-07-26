plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "com.sniper.androidwebbox"
    compileSdk {
        version = release(36)
    }

    defaultConfig {
        applicationId = "com.sniper.androidwebbox"
        minSdk = 29
        targetSdk = 36
        versionCode = 2
        versionName = "2.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    lint {
        // Suppress deprecated onBackPressed warning
        disable += "GestureBackNavigation"
    }
}

dependencies {
    // Coconut SDK
    implementation(project(":coconut-sdk"))

    // OkHttp (used by NetworkComponent's OkHttpHttpClient)
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // ML Kit Barcode (bundled variant — model in APK, NO GMS dependency).
    // Used by CameraComponent.scanQRCode. Bundled runs fully on-device,
    // works on HMS-only / non-GMS ROMs. (+~2.5MB)
    implementation("com.google.mlkit:barcode-scanning:17.3.0")

    // CameraX (AndroidX Jetpack) — official camera preview for scanQRCode.
    val cameraxVersion = "1.3.4"
    implementation("androidx.camera:camera-core:$cameraxVersion")
    implementation("androidx.camera:camera-camera2:$cameraxVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraxVersion")
    implementation("androidx.camera:camera-view:$cameraxVersion")

    // AndroidX libraries
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.androidx.activity)
    implementation(libs.androidx.constraintlayout)

    // Testing
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
}