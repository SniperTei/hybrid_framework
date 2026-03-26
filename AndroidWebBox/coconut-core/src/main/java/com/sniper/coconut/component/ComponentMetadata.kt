package com.sniper.coconut.component

/**
 * Component Metadata Annotation
 *
 * Use this annotation to mark component classes for auto-registration
 *
 * Example:
 * ```kotlin
 * @ComponentMetadata(
 *     name = "device",
 *     version = "1.0.0",
 *     description = "Device information component",
 *     dependencies = []
 * )
 * class DeviceComponent : BaseComponent() {
 *     override val name = "device"
 *     override suspend fun handle(function: String, params: JsonObject?): JsonElement {
 *         // Component implementation
 *     }
 * }
 * ```
 */
@Target(AnnotationTarget.CLASS)
@Retention(AnnotationRetention.RUNTIME)
annotation class ComponentMetadata(
    /**
     * Component name
     * Used as the key in "componentName.function" format
     * Must be unique across all components
     */
    val name: String,

    /**
     * Component version
     * Format: "major.minor.patch"
     * Useful for compatibility checking
     */
    val version: String = "1.0.0",

    /**
     * Component description
     * Explains what the component does
     */
    val description: String = "",

    /**
     * Component dependencies
     * List of component names that this component depends on
     * Dependencies must be registered before this component
     */
    val dependencies: Array<String> = [],

    /**
     * Whether component is enabled by default
     * Can be used to disable components without removing code
     */
    val enabled: Boolean = true
)
