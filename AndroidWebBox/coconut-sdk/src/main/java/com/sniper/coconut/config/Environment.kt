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
        // localhost:5174 + `adb reverse tcp:5174 tcp:5174` —— works on any network
        // (emulator + USB real device) without hardcoding a LAN IP. For Wi-Fi real
        // device testing, override at app startup or use STAGING/PROD.
        defaultH5Domain = "http://localhost:5174",
        defaultApiDomain = "http://localhost:8080"
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
