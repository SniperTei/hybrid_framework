/**
 * iOSWebBox JavaScript SDK
 * Cross-platform hybrid framework SDK
 * Compatible with AndroidWebBox
 */

(function() {
    'use strict';

    if (window.AndroidWebBox) {
        return; // Already injected
    }

    const AndroidWebBox = {
        callbacks: {},
        eventListeners: {},

        // Generate unique ID
        generateId: function() {
            return 'cb_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        },

        // Call Native method
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
                // iOS: WKWebView
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.AndroidWebBoxNative) {
                    window.webkit.messageHandlers.AndroidWebBoxNative.postMessage(message);
                }
                // Android: WebView
                else if (window.AndroidWebBoxNative) {
                    window.AndroidWebBoxNative.postMessage(message);
                }
                else {
                    console.error('No native bridge found');
                    if (callback) {
                        callback({ success: false, error: { code: 'NO_BRIDGE', message: 'No native bridge found' } });
                    }
                }
            } catch (e) {
                console.error('JSBridge call error:', e);
                if (callback) {
                    callback({ success: false, error: { code: 'CALL_ERROR', message: e.message } });
                }
            }

            return callbackId;
        },

        // Native callback to JS
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

        // Native event to JS
        onNativeEvent: function(eventName, data) {
            const listeners = this.eventListeners[eventName] || [];
            listeners.forEach(function(callback) {
                callback(data);
            });
        },

        // Event listener
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

    // Shortcut API methods
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
    console.log('iOSWebBox JS SDK initialized');
})();
