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

    testOptions {
        unitTests {
            // android.util.Log / Context stubs return defaults instead of throwing
            isReturnDefaultValues = true
        }
    }
}

dependencies {
    // Coconut SDK
    implementation(project(":coconut-sdk"))

    // Coconut Network engine (pure JVM HTTP library)
    implementation(project(":coconut-network"))

    // AndroidX libraries
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.androidx.activity)
    implementation(libs.androidx.constraintlayout)

    // Testing
    testImplementation(libs.junit)
    testImplementation("io.mockk:mockk:1.13.8")
    testImplementation(libs.kotlinx.coroutines.test)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
}