package com.sniper.coconut.config

/**
 * Environment configuration
 *
 * Defines different runtime environments for the SDK.
 * Each environment has its own H5 domain, API domain, and feature flags.
 */
enum class Environment(
    val displayName: String,
    val defaultH5Domain: String,
    val defaultApiDomain: String
) {
    DEV(
        displayName = "Development",
        defaultH5Domain = "http://192.168.3.49:5174",
        defaultApiDomain = "http://192.168.3.49:8080"
    ),
    TEST(
        displayName = "Testing",
        defaultH5Domain = "http://192.168.1.100:5174",
        defaultApiDomain = "http://192.168.1.100:8080"
    ),
    STAGING(
        displayName = "Staging",
        defaultH5Domain = "https://staging-h5.example.com",
        defaultApiDomain = "https://staging-api.example.com"
    ),
    PROD(
        displayName = "Production",
        defaultH5Domain = "https://h5.example.com",
        defaultApiDomain = "https://api.example.com"
    );

    val isDebug: Boolean get() = this == DEV || this == TEST
}
