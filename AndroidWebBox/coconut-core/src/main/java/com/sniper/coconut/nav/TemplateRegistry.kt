package com.sniper.coconut.nav

import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/**
 * Container template registry entry (assets/coconut_templates.json).
 * templatePage = fully qualified Activity class name on Android.
 */
@Serializable
data class TemplateEntry(
    val templateName: String,
    val templatePage: String,
)

/**
 * Template registry: logical template name → host custom container subclass.
 *
 * JSON file shape: `[{"templateName":"demo","templatePage":"com.sniper.web.DemoTemplateActivity"}]`
 *
 * [validate] resolves each entry via reflection and enforces:
 * - class resolves (Class.forName, no init)
 * - class is a subclass of the container base class (parameterized so core
 *   does not depend on coconut-sdk)
 * - no duplicate templateName
 *
 * Bad entries throw IllegalStateException with entry context (fail-fast).
 * NOTE: validation cannot detect a missing `<activity>` manifest declaration —
 * reflection resolves the class fine; launching it crashes. Hosts must declare
 * every template Activity.
 */
object TemplateRegistry {

    private val json = Json { ignoreUnknownKeys = true }

    fun parse(jsonText: String): List<TemplateEntry> =
        json.decodeFromString(ListSerializer(TemplateEntry.serializer()), jsonText)

    fun validate(
        entries: List<TemplateEntry>,
        classLoader: ClassLoader,
        baseClass: Class<*>,
    ): Map<String, Class<*>> {
        val map = LinkedHashMap<String, Class<*>>()
        for (entry in entries) {
            if (entry.templateName.isBlank()) {
                throw IllegalStateException("template entry with blank templateName: $entry")
            }
            if (map.containsKey(entry.templateName)) {
                throw IllegalStateException("duplicate templateName: '${entry.templateName}'")
            }
            val clazz = try {
                Class.forName(entry.templatePage, false, classLoader)
            } catch (e: ClassNotFoundException) {
                throw IllegalStateException(
                    "template '${entry.templateName}': class not found: ${entry.templatePage}", e,
                )
            }
            if (!baseClass.isAssignableFrom(clazz)) {
                throw IllegalStateException(
                    "template '${entry.templateName}': ${entry.templatePage} is not a subclass of ${baseClass.name}",
                )
            }
            map[entry.templateName] = clazz
        }
        return map
    }
}
