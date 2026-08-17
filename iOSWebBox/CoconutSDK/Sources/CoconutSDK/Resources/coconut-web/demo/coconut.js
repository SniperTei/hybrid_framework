/**
 * 🥥 coconut SDK - JavaScript Client
 *
 * 与 Android / iOS / HarmonyOS 原生交互的统一 JS 客户端
 * 支持环境：android (sync) / ios (async) / harmony (async) / web (mock)
 * 安全特性：Bridge Token 防护
 *
 * API 概览：
 *   coconut.call(component, functionName, params, callback)   —— 一次或多次回调（流式响应）
 *     component    例：'storage' / 'device' / 'event'  ← 对应 native Component.name
 *     functionName 例：'setItem' / 'getInfo' / 'on'     ← 该组件的方法
 *     callback signature: function(error, data)
 *       error = null 成功；error = {code, message} 失败
 *       data  = result object（成功时）
 *     流式响应：native 在 response JSON 里加 `streaming:true` → callback
 *     保留，等下一次同 id 的响应；最终响应（无 streaming）会清理 callback。
 *
 *   coconut.on(topic, callback)              —— 订阅 native 事件（多次触发）
 *     callback signature: function(data)   （事件没有 error 概念）
 *   coconut.off(topic)
 *
 * 环境信息（coconut.env）：
 *   platform / version / sdkVersion / hybridVersion
 *   isAndroid / isiOS / isHarmony / isWeb / isNode / isNative
 *   appName / appVersion            （由 native 经 window.__coconutConfig 注入）
 *   userAgent / language / screen / viewport / ...  （浏览器侧信息）
 *
 * @version 3.3.0
 */

(function (global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined'
        ? module.exports = factory()
        : typeof define === 'function' && define.amd
        ? define(factory)
        : (global.coconut = factory());
}(this, (function () {
    'use strict';

    /**
     * Bridge protocol major version (coconut.js major = bridge protocol major).
     * Bumped only on backwards-incompatible wire-format / callback-contract changes.
     *   v3: lowercase global, error-first callbacks, streaming responses,
     *       component+function wire split.
     */
    var BRIDGE_PROTOCOL_VERSION = '3';

    /**
     * coconut SDK 主类
     */
    var Coconut = function () {
        this.version = '3.3.0';
        this.debug = false;
        this.defaultTimeout = 30000;
        this.isInitialized = false;
        this.requestId = 0;
        this.callbacks = {};              // requestId -> callback
        this.timers = {};                 // requestId -> timeout handle
        this._timeoutMap = {};            // requestId -> original timeout (for streaming reset)
        this.handlers = {};               // topic -> callback (一个 topic 一个 callback，覆盖式)
        this.environment = this.detectEnvironment();
        this.env = this.createEnv();
        this._securityConfig = null;
    };

    /**
     * 检测运行环境
     */
    Coconut.prototype.detectEnvironment = function () {
        if (typeof window === 'undefined' || !window.document) {
            return 'node';
        }
        if (window.CoconutHarmonyBridge && window.CoconutHarmonyBridge.call) {
            return 'harmony';
        }
        if (window.CoconutBridge) {
            return 'android';
        }
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.CoconutBridge) {
            return 'ios';
        }
        return 'web';
    };

    /**
     * 创建环境信息对象
     */
    Coconut.prototype.createEnv = function () {
        var env = {
            platform: this.environment,
            version: this.version,
            sdkVersion: this.version
        };

        // 平台标识
        env.isAndroid = this.environment === 'android';
        env.isiOS = this.environment === 'ios';
        env.isHarmony = this.environment === 'harmony';
        env.isWeb = this.environment === 'web';
        env.isNode = this.environment === 'node';
        env.isNative = env.isAndroid || env.isiOS || env.isHarmony;

        // 浏览器环境信息
        if (typeof window !== 'undefined' && window.navigator) {
            env.userAgent = window.navigator.userAgent || '';
            env.language = window.navigator.language || '';
            env.cookieEnabled = window.navigator.cookieEnabled || false;
            env.online = window.navigator.onLine || false;

            var ua = env.userAgent.toLowerCase();
            env.isWebView = (
                /android/.test(ua) && /wv/.test(ua) ||
                /iphone|ipad|ipod/.test(ua) && !/safari/.test(ua) ||
                env.isAndroid || env.isiOS
            );

            env.isChrome = /chrome/.test(ua) && !/edge/.test(ua);
            env.isSafari = /safari/.test(ua) && !/chrome/.test(ua);
            env.isFirefox = /firefox/.test(ua);
            env.isEdge = /edge/.test(ua) || /edg/.test(ua);
            env.isWeChat = /micromessenger/.test(ua);
            env.isAlipay = /alipay/.test(ua);

            env.isWindows = /windows/.test(ua);
            env.isMac = /macintosh|mac os x/.test(ua);
            env.isLinux = /linux/.test(ua) && !/android/.test(ua);
            env.isMobile = /android|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(ua);
            env.isTablet = /ipad|android(?!.*mobile)|tablet/i.test(ua);
            env.isDesktop = !env.isMobile && !env.isTablet;

            if (env.isiOS) {
                env.isIPhone = /iphone/.test(ua);
                env.isIPad = /ipad/.test(ua);
                env.isIPod = /ipod/.test(ua);
            }

            if (env.isAndroid) {
                var match = ua.match(/android\s([0-9\.]+)/);
                env.androidVersion = match ? match[1] : 'unknown';
            }
        }

        if (typeof window !== 'undefined' && window.screen) {
            env.screenWidth = window.screen.width || 0;
            env.screenHeight = window.screen.height || 0;
            env.devicePixelRatio = window.devicePixelRatio || 1;

            if (window.innerWidth && window.innerHeight) {
                env.viewportWidth = window.innerWidth;
                env.viewportHeight = window.innerHeight;
            }
        }

        if (typeof window !== 'undefined') {
            env.isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
        }

        if (typeof window !== 'undefined') {
            env.localStorage = typeof window.localStorage !== 'undefined';
            env.sessionStorage = typeof window.sessionStorage !== 'undefined';
        }

        // Bridge protocol version (major). Static — derived from coconut.js major.
        env.hybridVersion = BRIDGE_PROTOCOL_VERSION;

        // App name / version come from native via window.__coconutConfig (injected
        // at onPageFinished). Since native injection may happen AFTER coconut.env
        // is built, expose these as lazy getters so the value is read each access.
        Object.defineProperty(env, 'appName', {
            configurable: true,
            enumerable: true,
            get: function () {
                return (typeof window !== 'undefined' && window.__coconutConfig &&
                    window.__coconutConfig.appName) || '';
            }
        });
        Object.defineProperty(env, 'appVersion', {
            configurable: true,
            enumerable: true,
            get: function () {
                return (typeof window !== 'undefined' && window.__coconutConfig &&
                    window.__coconutConfig.appVersion) || '';
            }
        });
        // Capabilities: {componentName: [method names]} — populated by native
        // at page-finish from ComponentManager.getCapabilities(). Read lazy so
        // H5 sees the post-injection value even though env is built earlier.
        Object.defineProperty(env, 'capabilities', {
            configurable: true,
            enumerable: true,
            get: function () {
                return (typeof window !== 'undefined' && window.__coconutConfig &&
                    window.__coconutConfig.capabilities) || {};
            }
        });

        return env;
    };

    /**
     * 初始化 SDK
     */
    Coconut.prototype.init = function (options) {
        options = options || {};
        if (options.debug) {
            this.debug = true;
            this.log('🥥 coconut SDK v' + this.version);
            this.log('📱 Environment: ' + this.environment);
        }
        if (options.timeout) {
            this.defaultTimeout = options.timeout;
        }
        this.isInitialized = true;
        this._loadSecurityConfig();
        this._setupLifecycle();
        return this;
    };

    /**
     * 注册 app.foreground / app.background lifecycle 事件
     *
     * 走 document.visibilitychange —— 现代 WebView（WKWebView iOS 9+、Chromium
     * Android、Harmony ArkWeb）在 app 切换前后台时都会触发。WebView JS 在
     * background 后立刻 suspend，所以同步派发（不走 setTimeout）。
     *
     * 通过同一条 handlers 路径派发，H5 用 coconut.on('app.foreground', cb)
     * 就能订阅，跟 native 推送的事件统一接口。
     *
     * 限制：visibilitychange 不覆盖 webview 销毁场景，没有 app.destroy。
     */
    Coconut.prototype._setupLifecycle = function () {
        if (this._lifecycleBound) return;
        this._lifecycleBound = true;
        var self = this;
        if (typeof document === 'undefined') return;
        document.addEventListener('visibilitychange', function () {
            var topic = document.hidden ? 'app.background' : 'app.foreground';
            var handler = self.handlers[topic];
            if (typeof handler === 'function') {
                try {
                    handler({ topic: topic, timestamp: Date.now() });
                } catch (e) {
                    self.error('Lifecycle handler error:', e);
                }
            }
        });
    };

    Coconut.prototype._loadSecurityConfig = function () {
        if (typeof window !== 'undefined' && window.__coconutConfig) {
            this._securityConfig = window.__coconutConfig;
            if (this.debug) {
                this.log('🔒 Security config loaded: token=' +
                    (this._securityConfig.token ? '***' : 'none'));
            }
            // Notify H5 subscribers (e.g. Vue reactive wrappers) that the
            // config has been (re)loaded. Without this, computed() that read
            // window.__coconutConfig cache stale values from before injection.
            if (typeof window !== 'undefined' && typeof CustomEvent !== 'undefined') {
                try {
                    window.dispatchEvent(new CustomEvent('coconut:config-loaded'));
                } catch (e) { /* no-op */ }
            }
        } else {
            this._securityConfig = null;
        }
    };

    Coconut.prototype._applySecurity = function (request) {
        if (!this._securityConfig && typeof window !== 'undefined' && window.__coconutConfig) {
            this._loadSecurityConfig();
        }
        var config = this._securityConfig;
        if (config && config.token) {
            request.bridgeToken = config.token;
        }
    };

    /**
     * 调用原生方法（回调方式，可流式）
     *
     * Signature: call(component, functionName, params, callback, timeout)
     *   component    例：'storage' / 'device' / 'event'  ← 对应 Component.name
     *   functionName 例：'setItem' / 'getInfo' / 'on'     ← 该 component 的方法
     *
     * Wire 字段：{component, function, params, id, bridgeToken}
     * native 端按 component 名查表，再调用其 function 方法。
     *
     * callback(error, data)：
     *   error = null           成功
     *   error = {code, message} 失败
     *   data  = result object  成功时
     *
     * 流式响应：native 在 response 里带 `streaming:true` 时 callback 会被
     * 触发但**不释放**，下次同 id 响应来时再触发；最终响应（无 streaming
     * 字段）触发 callback 后释放。Timer 每次流式响应都会重置。
     *
     * @param {string} component
     * @param {string} functionName
     * @param {object} params
     * @param {function} callback  error-first: (error, data)
     * @param {number} timeout     毫秒，默认 30000
     */
    Coconut.prototype.call = function (component, functionName, params, callback, timeout) {
        if (!this.isInitialized) {
            this.init({});
        }

        var self = this;
        var requestId = this.generateRequestId();
        var request = {
            component: component,
            function: functionName,
            params: params || {},
            id: requestId
        };

        var to = timeout || this.defaultTimeout;

        if (callback) {
            this.callbacks[requestId] = callback;
            this._timeoutMap[requestId] = to;
            this._armTimer(requestId, to);
        }

        this._applySecurity(request);
        this._sendBridgeRequest(request);

        if (this.debug) {
            this.log('📤 Call:', component + '.' + functionName, params);
        }
    };

    /**
     * 启动 / 重启超时定时器（流式响应每次都会重置）
     */
    Coconut.prototype._armTimer = function (requestId, to) {
        var self = this;
        if (this.timers[requestId]) {
            clearTimeout(this.timers[requestId]);
        }
        this.timers[requestId] = setTimeout(function () {
            var cb = self.callbacks[requestId];
            self._cleanupRequest(requestId);
            if (cb) {
                cb({ code: '200004', message: 'Timeout after ' + to + 'ms' }, undefined);
            }
        }, to);
    };

    /**
     * Promise 版（一次性响应；不适用于流式）。
     * 如果 native 发流式响应，Promise 只 resolve 第一次。
     */
    Coconut.prototype.callAsync = function (component, functionName, params) {
        var self = this;
        return new Promise(function (resolve, reject) {
            self.call(component, functionName, params, function (error, data) {
                if (error) {
                    reject(error);
                } else {
                    resolve(data);
                }
            });
        });
    };

    /**
     * 发送请求到原生
     */
    Coconut.prototype._sendBridgeRequest = function (request) {
        var requestJson = JSON.stringify(request);

        try {
            if (this.environment === 'android') {
                if (window.CoconutBridge && window.CoconutBridge.call) {
                    var responseJson = window.CoconutBridge.call(requestJson);
                    if (responseJson) {
                        this.handleResponse(responseJson);
                    }
                } else {
                    throw new Error('CoconutBridge not found');
                }
            } else if (this.environment === 'ios') {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.CoconutBridge) {
                    window.webkit.messageHandlers.CoconutBridge.postMessage(requestJson);
                } else {
                    throw new Error('CoconutBridge not found');
                }
            } else if (this.environment === 'harmony') {
                if (window.CoconutHarmonyBridge && window.CoconutHarmonyBridge.call) {
                    window.CoconutHarmonyBridge.call(requestJson);
                } else {
                    throw new Error('CoconutHarmonyBridge not found');
                }
            } else {
                this.handleWebMock(request);
            }
        } catch (error) {
            this.error('Error sending request:', error);
            var cb = this.callbacks[request.id];
            if (cb) {
                cb({ code: '100005', message: error.message }, undefined);
                this._cleanupRequest(request.id);
            }
        }
    };

    /**
     * Web 环境模拟（开发用）
     */
    Coconut.prototype.handleWebMock = function (request) {
        var self = this;
        setTimeout(function () {
            var code = '000000';
            var result = {};
            var key = request.component + '.' + request.function;

            if (key === 'device.getInfo') {
                result = { platform: 'web', model: 'Mock Browser', version: '1.0.0' };
            } else if (key === 'storage.getItem') {
                result = { key: request.params.key, value: null };
            } else if (key === 'storage.setItem') {
                result = { key: request.params.key, success: true };
            } else if (key === 'storage.removeItem') {
                result = { key: request.params.key, success: true };
            } else if (key === 'storage.clear') {
                result = { success: true };
            } else if (key === 'event.on') {
                result = { topic: request.params.topic };
            } else if (key === 'event.off') {
                result = { topic: request.params.topic, success: true };
            } else if (key === 'event.echo') {
                result = { scheduled: true, topic: 'test.echo' };
                setTimeout(function () {
                    if (typeof window !== 'undefined' && window.__coconutEvent) {
                        var evt = { topic: 'test.echo', data: request.params };
                        window.__coconutEvent(JSON.stringify(evt));
                    }
                }, 500);
            }

            self.handleResponse(JSON.stringify({
                id: request.id,
                code: code,
                message: 'success (web mock)',
                result: result
            }));
        }, 100);
    };

    /**
     * 处理原生响应（支持流式）
     *
     * Response JSON 形如：
     *   { id, code, message, result, streaming? }
     *
     * streaming === true：触发 callback、重置 timer、不删 callback
     * 其他情况：触发 callback、删 callback + timer
     */
    Coconut.prototype.handleResponse = function (responseJson) {
        try {
            var resp = JSON.parse(responseJson);

            if (this.debug) {
                this.log('📥 Response:', resp);
            }

            var cb = this.callbacks[resp.id];
            if (!cb) {
                // 没有 callback（可能已超时清理），忽略
                return;
            }

            var isSuccess = resp.code === '000000';

            if (isSuccess) {
                // 成功：error=null, data=result
                cb(null, resp.result);
            } else {
                // 失败：error={code, message}, data=undefined
                cb({ code: resp.code, message: resp.message }, undefined);
            }

            if (resp.streaming === true) {
                // 流式响应：保留 callback，重置 timer
                var existingTo = this._timeoutMap[resp.id] || this.defaultTimeout;
                this._armTimer(resp.id, existingTo);
            } else {
                // 最终响应：清理
                this._cleanupRequest(resp.id);
            }
        } catch (error) {
            this.error('Error handling response:', error);
        }
    };

    /**
     * 订阅 native 事件（多次触发）
     *
     * callback(data) —— 事件没有 error 概念
     *
     * 一个 topic 一个 callback：第二次 on 同 topic 会覆盖第一次，
     * 并 console.warn。
     *
     * @param {string} topic
     * @param {function} callback  signature: (data)
     */
    Coconut.prototype.on = function (topic, callback) {
        if (!this.isInitialized) {
            this.init({});
        }
        if (typeof topic !== 'string' || topic.length === 0) {
            throw new Error('on: topic must be a non-empty string');
        }
        if (typeof callback !== 'function') {
            throw new Error('on: callback must be a function');
        }

        if (this.handlers.hasOwnProperty(topic)) {
            console.warn('[coconut] on: topic "' + topic + '" already subscribed, replacing previous handler');
        }

        this.handlers[topic] = callback;

        this.call('event', 'on', { topic: topic }, function (err) {
            if (err && this.debug) {
                this.log('⚠️ on ack failed for', topic, err);
            }
        }.bind(this));

        if (this.debug) {
            this.log('📡 On:', topic);
        }
    };

    /**
     * 取消订阅（未订阅的 topic 也是 no-op）
     */
    Coconut.prototype.off = function (topic) {
        if (!topic || !this.handlers.hasOwnProperty(topic)) {
            return;
        }
        delete this.handlers[topic];

        this.call('event', 'off', { topic: topic });

        if (this.debug) {
            this.log('🚫 Off:', topic);
        }
    };

    /**
     * 能力探测：当前 native 版本是否支持某个组件的某个方法
     *
     * 数据来源：native 注入的 `window.__coconutConfig.capabilities`
     * 形如 `{device:['getInfo',...], storage:[...], event:[...]}`。
     * 纯前端查表，不发 bridge call，可同步调用。
     *
     * @param {string} component   例：'storage'
     * @param {string} functionName 例：'setItem'
     * @return {boolean}
     */
    Coconut.prototype.supports = function (component, functionName) {
        if (typeof component !== 'string' || typeof functionName !== 'string') {
            return false;
        }
        var caps = this.env.capabilities || {};
        var methods = caps[component];
        return Array.isArray(methods) && methods.indexOf(functionName) !== -1;
    };

    /**
     * 处理 native 推送的事件（由 window.__coconutEvent 调用）
     *
     * 事件 payload：{ topic, data }
     * callback 收到的是 data 字段（事件无 error 概念）
     */
    Coconut.prototype.handleEvent = function (eventJson) {
        try {
            var event = JSON.parse(eventJson);
            var topic = event && event.topic;
            var cb = topic && this.handlers[topic];

            if (typeof cb === 'function') {
                cb(event.data);
            }
        } catch (error) {
            this.error('Error handling event:', error);
        }
    };

    /**
     * 清理请求相关资源（callback + timer）
     */
    Coconut.prototype._cleanupRequest = function (requestId) {
        delete this.callbacks[requestId];
        if (this.timers[requestId]) {
            clearTimeout(this.timers[requestId]);
            delete this.timers[requestId];
        }
        if (this._timeoutMap && this._timeoutMap[requestId]) {
            delete this._timeoutMap[requestId];
        }
    };

    Coconut.prototype.generateRequestId = function () {
        return 'req_' + Date.now() + '_' + (++this.requestId);
    };

    Coconut.prototype.log = function () {
        if (this.debug && console && console.log) {
            var args = ['[coconut]'].concat(Array.prototype.slice.call(arguments));
            console.log.apply(console, args);
        }
    };

    Coconut.prototype.error = function () {
        if (console && console.error) {
            var args = ['[coconut]'].concat(Array.prototype.slice.call(arguments));
            console.error.apply(console, args);
        }
    };

    // 创建单例
    var coconutSDK = new Coconut();

    /**
     * 快捷方法 - 设备组件
     */
    Coconut.prototype.device = {
        getInfo: function (callback) {
            return coconutSDK.call('device', 'getInfo', {}, callback);
        }
    };

    /**
     * 快捷方法 - 存储组件
     */
    Coconut.prototype.storage = {
        setItem: function (key, value, callback) {
            return coconutSDK.call('storage', 'setItem', { key: key, value: value }, callback);
        },
        getItem: function (key, callback) {
            return coconutSDK.call('storage', 'getItem', { key: key }, callback);
        },
        removeItem: function (key, callback) {
            return coconutSDK.call('storage', 'removeItem', { key: key }, callback);
        },
        clear: function (callback) {
            return coconutSDK.call('storage', 'clear', {}, callback);
        },
        getAllKeys: function (callback) {
            return coconutSDK.call('storage', 'getAllKeys', {}, callback);
        },
        getSize: function (callback) {
            return coconutSDK.call('storage', 'getSize', {}, callback);
        }
    };

    /**
     * 快捷方法 - 弹窗组件（v3.3.0）
     *
     * duration 单位为秒；position 可选 'top'|'center'|'bottom'（部分平台忽略）
     */
    Coconut.prototype.dialog = {
        alert: function (title, message, buttonText, callback) {
            return coconutSDK.call('dialog', 'alert', {
                title: title, message: message, buttonText: buttonText
            }, callback);
        },
        confirm: function (title, message, confirmText, cancelText, callback) {
            return coconutSDK.call('dialog', 'confirm', {
                title: title, message: message, confirmText: confirmText, cancelText: cancelText
            }, callback);
        },
        toast: function (message, duration, position, callback) {
            return coconutSDK.call('dialog', 'toast', {
                message: message, duration: duration || 2, position: position || 'bottom'
            }, callback);
        },
        showLoading: function (message, callback) {
            return coconutSDK.call('dialog', 'showLoading', { message: message }, callback);
        },
        hideLoading: function (callback) {
            return coconutSDK.call('dialog', 'hideLoading', {}, callback);
        }
    };

    // 持久注册 native 回调入口
    if (typeof window !== 'undefined') {
        window.__coconutIOSCallback = function (responseJson) {
            coconutSDK.handleResponse(responseJson);
        };
        window.__coconutHarmonyCallback = function (responseJson) {
            coconutSDK.handleResponse(responseJson);
        };
        window.__coconutEvent = function (eventJson) {
            coconutSDK.handleEvent(eventJson);
        };
    }

    // 自动初始化
    if (typeof window !== 'undefined') {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', function () {
                coconutSDK.init({ debug: false });
            });
        } else {
            coconutSDK.init({ debug: false });
        }
    }

    return coconutSDK;

})));
