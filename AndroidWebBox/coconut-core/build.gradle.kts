plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("maven-publish")
}

android {
    namespace = "com.sniper.coconut.core"
    compileSdk = (project.property("COMPILE_SDK") as String).toInt()

    defaultConfig {
        minSdk = (project.property("MIN_SDK") as String).toInt()
        targetSdk = (project.property("TARGET_SDK") as String).toInt()

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("consumer-rules.pro")
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

    buildFeatures {
        buildConfig = true
    }

    publishing {
        singleVariant("release") {
            withSourcesJar()
            withJavadocJar()
        }
    }
}

dependencies {
    // Kotlin Coroutines
    api("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")

    // Kotlin Serialization
    api("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")

    // Class scanning for auto-registration
    api("io.github.classgraph:classgraph:4.8.162")

    // AndroidX Core
    api("androidx.core:core-ktx:1.12.0")

    // Testing
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
    testImplementation("io.mockk:mockk:1.13.8")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}

publishing {
    publications {
        create<MavenPublication>("release") {
            groupId = project.property("GROUP_ID") as String
            artifactId = "coconut-core"
            version = project.property("VERSION_NAME") as String

            afterEvaluate {
                from(components["release"])
            }

            pom {
                name.set("Coconut Core")
                description.set("Core bridge and component system for Coconut SDK")
                url.set(project.property("POM_URL") as String)

                licenses {
                    license {
                        name.set("The Apache License, Version 2.0")
                        url.set("http://www.apache.org/licenses/LICENSE-2.0.txt")
                    }
                }

                developers {
                    developer {
                        id.set(project.property("POM_DEVELOPER_ID") as String)
                        name.set(project.property("POM_DEVELOPER_NAME") as String)
                        email.set(project.property("POM_DEVELOPER_EMAIL") as String)
                    }
                }

                scm {
                    connection.set(project.property("POM_SCM_CONNECTION") as String)
                    developerConnection.set(project.property("POM_SCM_CONNECTION") as String)
                    url.set(project.property("POM_SCM_URL") as String)
                }
            }
        }
    }
}
