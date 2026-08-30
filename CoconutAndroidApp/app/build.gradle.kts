plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "com.sniper.coconutandroidapp"
    compileSdk {
        version = release(36)
    }

    defaultConfig {
        applicationId = "com.sniper.coconutandroidapp"
        minSdk = 29
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

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
        // coconut-sdk AAR 字节码是 Java 17，消费端必须 ≥ 17
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // Coconut SDK（mavenLocal 消费者验证：先在 AndroidWebBox 跑 ./gradlew publishToMavenLocal）
    implementation("com.sniper.coconut:coconut-sdk:3.5.0")
    // 独立网络引擎（NetworkComponent 直用；mavenLocal 先发布 coconut-network）
    implementation("com.sniper.coconut:coconut-network:1.1.0")

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.androidx.activity)
    implementation(libs.androidx.constraintlayout)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
}