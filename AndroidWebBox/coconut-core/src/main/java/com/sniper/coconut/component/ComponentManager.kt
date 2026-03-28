package com.sniper.coconut.component

import com.sniper.coconut.utils.Logger
import io.github.classgraph.ClassGraph
import io.github.classgraph.ClassInfo
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.ConcurrentHashMap

/**
 * Component Manager
 *
 * Manages component lifecycle, registration, and routing
 */
class ComponentManager private constructor() {

    private val components = ConcurrentHashMap<String, CoconutPlugin>()
    private val mutex = Mutex()

    // Shared ComponentContext - host is updated dynamically
    internal val sharedContext by lazy {
        ComponentContext(
            applicationContext = requireNotNull(applicationContext) {
                "Application context not set"
            },
            coroutineScope = requireNotNull(coroutineScope) {
                "Coroutine scope not set"
            }
        )
    }

    /**
     * Set the current ComponentHost (called by CoconutWebActivity)
     * Components access the host through their ComponentContext
     */
    fun setHost(host: ComponentHost?) {
        sharedContext.host = host
    }

    /**
     * Register a component
     *
     * @param component Component instance
     * @throws ComponentException if component already registered or dependencies not met
     */
    suspend fun register(component: CoconutPlugin) {
        mutex.withLock {
            // Check if component already registered
            if (components.containsKey(component.name)) {
                throw ComponentException("Component '${component.name}' is already registered")
            }

            // Check dependencies
            checkDependencies(component)

            Logger.d("ComponentManager", "Registering component: ${component.name} v${component.version}")

            // Initialize component with shared context
            try {
                component.init(sharedContext)
                components[component.name] = component
                Logger.i("ComponentManager", "✓ Component registered: ${component.name}")
            } catch (e: Exception) {
                Logger.e("ComponentManager", "Failed to initialize component: ${component.name}", e)
                throw ComponentException("Failed to initialize component '${component.name}': ${e.message}", e)
            }
        }
    }

    /**
     * Unregister a component
     *
     * @param componentName Component name
     */
    suspend fun unregister(componentName: String) {
        mutex.withLock {
            val component = components.remove(componentName)
            if (component != null) {
                try {
                    component.cleanup()
                    Logger.i("ComponentManager", "✓ Component unregistered: $componentName")
                } catch (e: Exception) {
                    Logger.e("ComponentManager", "Error cleaning up component: $componentName", e)
                }
            }
        }
    }

    /**
     * Inject multiple components at once
     * Useful for batch registration
     *
     * @param components Vararg of component instances
     */
    suspend fun inject(vararg components: CoconutPlugin) {
        for (component in components) {
            try {
                register(component)
            } catch (e: Exception) {
                Logger.e("ComponentManager", "Failed to register component: ${component.name}", e)
                // Continue registering other components
            }
        }
    }

    /**
     * Get component by name
     *
     * @param name Component name
     * @return Component instance or null if not found
     */
    suspend fun getComponent(name: String): CoconutPlugin? {
        mutex.withLock {
            return components[name]
        }
    }

    /**
     * Check if component is registered
     *
     * @param name Component name
     * @return true if registered
     */
    suspend fun hasComponent(name: String): Boolean {
        mutex.withLock {
            return components.containsKey(name)
        }
    }

    /**
     * Get all registered component names
     *
     * @return List of component names
     */
    suspend fun getRegisteredComponents(): List<String> {
        mutex.withLock {
            return components.keys.toList()
        }
    }

    /**
     * Get component info
     *
     * @param name Component name
     * @return Component info or null
     */
    suspend fun getComponentInfo(name: String): ComponentInfo? {
        val component = getComponent(name) ?: return null
        return ComponentInfo(
            name = component.name,
            version = component.version,
            description = component.description,
            dependencies = component.dependencies,
            isInitialized = component.isInitialized
        )
    }

    /**
     * Get all components info
     *
     * @return List of component info
     */
    suspend fun getAllComponentsInfo(): List<ComponentInfo> {
        val componentNames = getRegisteredComponents()
        return componentNames.mapNotNull { getComponentInfo(it) }
    }

    /**
     * Auto-register components with @ComponentMetadata annotation
     *
     * @param packageName Package to scan
     */
    suspend fun autoRegister(packageName: String) {
        Logger.d("ComponentManager", "Auto-registering components from package: $packageName")

        val scanResult = try {
            ClassGraph()
                .enableClassInfo()
                .enableAnnotationInfo()
                .acceptPackages(packageName)
                .scan()
        } catch (e: Exception) {
            Logger.e("ComponentManager", "Failed to scan for components", e)
            return
        }

        try {
            val componentClasses = scanResult.getClassesWithAnnotation(ComponentMetadata::class.java.name)

            for (classInfo: ClassInfo in componentClasses) {
                try {
                    @Suppress("UNCHECKED_CAST")
                    val componentClass = classInfo.loadClass() as Class<CoconutPlugin>
                    val component = componentClass.getDeclaredConstructor().newInstance()

                    try {
                        register(component)
                    } catch (e: Exception) {
                        Logger.e("ComponentManager", "Failed to auto-register component: ${classInfo.name}", e)
                    }
                } catch (e: Exception) {
                    Logger.e("ComponentManager", "Failed to instantiate component: ${classInfo.name}", e)
                }
            }

            Logger.d("ComponentManager", "Auto-registered ${componentClasses.size} components")
        } finally {
            scanResult.close()
        }
    }

    /**
     * Cleanup all components
     */
    suspend fun cleanup() {
        mutex.withLock {
            Logger.d("ComponentManager", "Cleaning up all components")
            components.values.forEach { component ->
                try {
                    component.cleanup()
                } catch (e: Exception) {
                    Logger.e("ComponentManager", "Error cleaning up component: ${component.name}", e)
                }
            }
            components.clear()
            Logger.d("ComponentManager", "All components cleaned up")
        }
    }

    /**
     * Check component dependencies
     *
     * @param component Component to check
     * @throws ComponentException if dependencies not met
     */
    private suspend fun checkDependencies(component: CoconutPlugin) {
        for (dependency in component.dependencies) {
            if (!components.containsKey(dependency)) {
                throw ComponentException("Component '${component.name}' depends on '$dependency' which is not registered")
            }
        }
    }

    /**
     * Set application context
     * Must be called before registering any components
     */
    fun setApplicationContext(context: android.content.Context) {
        applicationContext = context
    }

    /**
     * Set coroutine scope
     */
    fun setCoroutineScope(scope: kotlinx.coroutines.CoroutineScope) {
        coroutineScope = scope
    }

    companion object {
        @Volatile
        private var instance: ComponentManager? = null

        private var applicationContext: android.content.Context? = null
        private var coroutineScope: kotlinx.coroutines.CoroutineScope? = null

        /**
         * Get singleton instance
         */
        fun getInstance(): ComponentManager {
            return instance ?: synchronized(this) {
                instance ?: ComponentManager().also { instance = it }
            }
        }
    }
}

/**
 * Component information
 */
data class ComponentInfo(
    val name: String,
    val version: String,
    val description: String,
    val dependencies: List<String>,
    val isInitialized: Boolean
)

/**
 * Component exception
 */
class ComponentException(message: String, cause: Throwable? = null) : Exception(message, cause)
