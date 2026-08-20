plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
    id("maven-publish")
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    // Kotlin Coroutines
    api(libs.kotlinx.coroutines.core)

    // Kotlin Serialization
    api(libs.kotlinx.serialization.json)

    // OkHttp adapter is optional at runtime — hosts that want OkHttpAdapter
    // add the dependency themselves (module never forces it transitively)
    compileOnly(libs.okhttp)

    // Testing
    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.okhttp)
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            groupId = project.property("GROUP_ID") as String
            artifactId = "coconut-network"
            // Independent of the CoconutSDK VERSION_NAME — engine evolves on its own
            version = "1.0.0"

            from(components["java"])

            pom {
                name.set("Coconut Network")
                description.set("Standalone HTTP engine for Coconut SDK (JVM, zero Android dependencies)")
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
