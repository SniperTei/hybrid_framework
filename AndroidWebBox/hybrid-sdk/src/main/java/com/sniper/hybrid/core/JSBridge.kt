package com.sniper.hybrid.core

import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONObject
import java.util.UUID

/**
 * JSBridge核心类
 * 负责H5与Native的双向通信
 */
class JSBridge(private val webView: WebView) {

    private val pendingCallbacks = mutableMapOf<String, ((Boolean, Any?, Int?, Pair<String, String>?) -> Unit)>()
    private val eventListeners = mutableMapOf<String, MutableList<(Any?) -> Unit>>()

    private val pluginManager = PluginManager(this)

    /**
     * 初始化JSBridge
     */
    fun init() {
        // 启用JavaScript
        webView.settings.javaScriptEnabled = true

        // 添加JSBridge接口 - 用于接收H5的消息
        webView.addJavascriptInterface(JSBridgeInterface(), "AndroidWebBoxNative")

        // 注入JS SDK
        injectJSSDK()
    }

    /**
     * 设置插件上下文
     */
    fun setPluginContext(context: com.sniper.hybrid.plugin.PluginContext) {
        pluginManager.init(context)
    }

    /**
     * 获取插件管理器
     */
    fun getPluginManager(): PluginManager = pluginManager

    /**
     * 注入JavaScript SDK
     */
    private fun injectJSSDK() {
        val jsSDK = """
            (function() {
                'use strict';

                if (window.AndroidWebBox) {
                    return; // 已经注入过
                }

                const AndroidWebBox = {
                    callbacks: {},
                    eventListeners: {},

                    // 生成唯一ID
                    generateId: function() {
                        return 'cb_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
                    },

                    // 调用Native方法
                    callNative: function(plugin, action, params, callback) {
                        const callbackId = this.generateId();

                        if (callback) {
                            this.callbacks[callbackId] = callback;
                        }

                        const message = JSON.stringify({
                            callbackId: callbackId,
                            plugin: plugin,
                            action: action,
                            params: params || {}
                        });

                        try {
                            window.AndroidWebBoxNative.postMessage(message);
                        } catch (e) {
                            console.error('JSBridge call error:', e);
                            if (callback) {
                                callback({ error: 'JSBridge call failed' });
                            }
                        }

                        return callbackId;
                    },

                    // Native回调JS
                    onNativeCallback: function(callbackId, success, data, progress, error) {
                        const callback = this.callbacks[callbackId];
                        if (!callback) return;

                        if (progress !== undefined && progress !== null) {
                            callback({ progress: progress });
                        } else if (success) {
                            callback({ success: true, data: data });
                            delete this.callbacks[callbackId];
                        } else {
                            callback({ success: false, error: error });
                            delete this.callbacks[callbackId];
                        }
                    },

                    // 监听Native事件
                    onNativeEvent: function(eventName, data) {
                        const listeners = this.eventListeners[eventName] || [];
                        listeners.forEach(function(callback) {
                            callback(data);
                        });
                    },

                    // 事件监听
                    event: {
                        on: function(eventName, callback) {
                            if (!AndroidWebBox.eventListeners[eventName]) {
                                AndroidWebBox.eventListeners[eventName] = [];
                            }
                            AndroidWebBox.eventListeners[eventName].push(callback);
                        },

                        off: function(eventName, callback) {
                            const listeners = AndroidWebBox.eventListeners[eventName];
                            if (listeners) {
                                const index = listeners.indexOf(callback);
                                if (index > -1) {
                                    listeners.splice(index, 1);
                                }
                            }
                        },

                        emit: function(eventName, data) {
                            AndroidWebBox.callNative('event', 'emit', {
                                event: eventName,
                                data: data
                            });
                        }
                    }
                };

                // 快捷API方法
                AndroidWebBox.camera = {
                    capture: function(options, callback) {
                        return AndroidWebBox.callNative('camera', 'capture', options, callback);
                    }
                };

                AndroidWebBox.gallery = {
                    pick: function(options, callback) {
                        return AndroidWebBox.callNative('gallery', 'pick', options, callback);
                    }
                };

                AndroidWebBox.video = {
                    record: function(options, callback) {
                        return AndroidWebBox.callNative('video', 'record', options, callback);
                    }
                };

                AndroidWebBox.device = {
                    getInfo: function(callback) {
                        return AndroidWebBox.callNative('device', 'getInfo', {}, callback);
                    }
                };

                AndroidWebBox.http = {
                    get: function(options, callback) {
                        return AndroidWebBox.callNative('http', 'GET', options, callback);
                    },
                    post: function(options, callback) {
                        return AndroidWebBox.callNative('http', 'POST', options, callback);
                    },
                    put: function(options, callback) {
                        return AndroidWebBox.callNative('http', 'PUT', options, callback);
                    },
                    delete: function(options, callback) {
                        return AndroidWebBox.callNative('http', 'DELETE', options, callback);
                    },
                    patch: function(options, callback) {
                        return AndroidWebBox.callNative('http', 'PATCH', options, callback);
                    },
                    upload: function(options, callback) {
                        return AndroidWebBox.callNative('http', 'upload', options, callback);
                    },
                    download: function(options, callback) {
                        return AndroidWebBox.callNative('http', 'download', options, callback);
                    },
                    setConfig: function(options, callback) {
                        return AndroidWebBox.callNative('http', 'setConfig', options, callback);
                    }
                };

                window.AndroidWebBox = AndroidWebBox;
                console.log('AndroidWebBox JS SDK initialized');
            })();
        """.trimIndent()

        webView.evaluateJavascript(jsSDK, null)
        webView.post {
            // 再次注入确保页面加载完成后可用
            webView.evaluateJavascript(jsSDK, null)
        }
    }

    /**
     * 处理来自JS的调用
     */
    fun handleJsCall(message: String) {
        try {
            val json = JSONObject(message)
            val callbackId = json.optString("callbackId")
            val plugin = json.optString("plugin")
            val action = json.optString("action")
            val params = json.optJSONObject("params") ?: JSONObject()

            pluginManager.exec(plugin, action, params, callbackId)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Native回调JS
     */
    fun callJs(
        callbackId: String,
        success: Boolean?,
        data: Any?,
        progress: Int?,
        error: Pair<String, String>?
    ) {
        val jsCode = buildString {
            append("if (window.AndroidWebBox) {")
            append("AndroidWebBox.onNativeCallback(")
            append("'$callbackId', ")
            append(success?.let { if (it) "true" else "false" } ?: "null")
            append(", ")
            when (data) {
                is String -> append("'$data'")
                is Number -> append(data)
                is Boolean -> append(if (data) "true" else "false")
                null -> append("null")
                else -> append(data) // JSONObject等
            }
            append(", ")
            progress?.let { append(it) } ?: append("null")
            append(", ")
            error?.let {
                append("{ code: '${it.first}', message: '${it.second}' }")
            } ?: append("null")
            append(");")
            append("}")
        }

        webView.post {
            webView.evaluateJavascript(jsCode, null)
        }
    }

    /**
     * Native发送事件到JS
     */
    fun emitEvent(eventName: String, data: Any?) {
        val dataStr = when (data) {
            is String -> "'$data'"
            is Number, is Boolean -> data.toString()
            null -> "null"
            else -> data.toString()
        }

        val jsCode = """
            if (window.AndroidWebBox) {
                AndroidWebBox.onNativeEvent('$eventName', $dataStr);
            }
        """.trimIndent()

        webView.post {
            webView.evaluateJavascript(jsCode, null)
        }
    }

    /**
     * JavaScript接口
     */
    private inner class JSBridgeInterface {
        @android.webkit.JavascriptInterface
        fun postMessage(message: String) {
            webView.post {
                handleJsCall(message)
            }
        }
    }
}
