package com.sniper.androidwebbox.components.event

import com.sniper.coconut.component.BaseComponent
import com.sniper.coconut.component.ComponentContext
import com.sniper.coconut.component.ComponentMetadata
import com.sniper.coconut.utils.Logger
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * Event Component
 *
 * Exposes subscribe/unsubscribe to H5 (delegating to the shared EventEmitter)
 * and a self-test `echo` method that emits a `test.echo` event after 500ms.
 */
@ComponentMetadata(
    name = "event",
    version = "1.0.0",
    description = "Event subscription component",
    dependencies = []
)
class EventComponent : BaseComponent() {

    override val name = "event"
    override val version = "1.0.0"
    override val description = "Event subscription component"

    private lateinit var sharedContext: ComponentContext

    override suspend fun handle(function: String, params: JsonObject?): JsonElement {
        return when (function) {
            "subscribe" -> subscribe(params)
            "unsubscribe" -> unsubscribe(params)
            "echo" -> echo(params)
            else -> functionNotSupportedError(function)
        }
    }

    protected override suspend fun onInit(context: ComponentContext) {
        sharedContext = context
        Logger.d(name, "Event component initialized")
    }

    /**
     * Register a subscription. Both topic and subscriptionId are H5-supplied
     * (subscriptionId generated client-side to avoid the async-window race).
     */
    private suspend fun subscribe(params: JsonObject?): JsonElement {
        val topic = getParam(params, "topic")
        val subscriptionId = getParam(params, "subscriptionId")

        if (topic.isEmpty() || subscriptionId.isEmpty()) {
            return paramValidationError("topic and subscriptionId are required")
        }

        sharedContext.eventEmitter.subscribe(topic, subscriptionId)

        return buildJsonObject {
            put("subscriptionId", JsonPrimitive(subscriptionId))
            put("topic", JsonPrimitive(topic))
        }.let { success(it) }
    }

    private suspend fun unsubscribe(params: JsonObject?): JsonElement {
        val subscriptionId = getParam(params, "subscriptionId")
        if (subscriptionId.isEmpty()) {
            return paramValidationError("subscriptionId is required")
        }
        sharedContext.eventEmitter.unsubscribe(subscriptionId)

        return buildJsonObject {
            put("subscriptionId", JsonPrimitive(subscriptionId))
            put("success", JsonPrimitive(true))
        }.let { success(it) }
    }

    /**
     * Demo: emit `test.echo` with the supplied payload after 500ms.
     */
    private suspend fun echo(params: JsonObject?): JsonElement {
        val payload: JsonElement = params ?: buildJsonObject {}
        scope.launch {
            delay(500)
            sharedContext.eventEmitter.emit(TOPIC_TEST_ECHO, payload)
            Logger.d(name, "echo emitted: $TOPIC_TEST_ECHO")
        }

        return buildJsonObject {
            put("scheduled", JsonPrimitive(true))
            put("topic", JsonPrimitive(TOPIC_TEST_ECHO))
        }.let { success(it) }
    }

    companion object {
        const val TOPIC_TEST_ECHO = "test.echo"
    }
}
