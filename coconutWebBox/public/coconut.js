/**
 * 🥥 Coconut SDK - JavaScript Client
 *
 * 与 Android / iOS / HarmonyOS 原生交互的统一 JS 客户端
 * 支持环境：android (sync) / ios (async) / harmony (async) / web (mock)
 * 安全特性：Bridge Token 防护
 *
 * @version 2.3.0
 */

(function (global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined'
        ? module.exports = factory()
        : typeof define === 'function' && define.amd
        ? define(factory)
        : (global.Coconut = factory());
}(this, (function () {
    'use strict';

    /**
     * Coconut SDK 主类
     */
    var Coconut = function () {
        this.version = '2.3.0';
        this.debug = false;
        this.defaultTimeout = 30000;
        this.isInitialized = false;
        this.requestId = 0;
        this.callbacks = {};
        this.timers = {};
        this.subscriptions = {};        // subscriptionId -> { topic, callback }
        this.subscriptionSeq = 0;
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

            // 检测是否在 WebView 中
            var ua = env.userAgent.toLowerCase();
            env.isWebView = (
                /android/.test(ua) && /wv/.test(ua) || // Android WebView
                /iphone|ipad|ipod/.test(ua) && !/safari/.test(ua) || // iOS WebView
                env.isAndroid || env.isiOS // 通过 CoconutBridge 检测
            );

            // 浏览器类型检测
            env.isChrome = /chrome/.test(ua) && !/edge/.test(ua);
            env.isSafari = /safari/.test(ua) && !/chrome/.test(ua);
            env.isFirefox = /firefox/.test(ua);
            env.isEdge = /edge/.test(ua) || /edg/.test(ua);
            env.isWeChat = /micromessenger/.test(ua);
            env.isAlipay = /alipay/.test(ua);

            // 操作系统检测
            env.isWindows = /windows/.test(ua);
            env.isMac = /macintosh|mac os x/.test(ua);
            env.isLinux = /linux/.test(ua) && !/android/.test(ua);
            env.isMobile = /android|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(ua);
            env.isTablet = /ipad|android(?!.*mobile)|tablet/i.test(ua);
            env.isDesktop = !env.isMobile && !env.isTablet;

            // iOS 设备类型
            if (env.isiOS) {
                env.isIPhone = /iphone/.test(ua);
                env.isIPad = /ipad/.test(ua);
                env.isIPod = /ipod/.test(ua);
            }

            // Android 设备信息
            if (env.isAndroid) {
                var match = ua.match(/android\s([0-9\.]+)/);
                env.androidVersion = match ? match[1] : 'unknown';
            }
        }

        // 屏幕信息
        if (typeof window !== 'undefined' && window.screen) {
            env.screenWidth = window.screen.width || 0;
            env.screenHeight = window.screen.height || 0;
            env.devicePixelRatio = window.devicePixelRatio || 1;

            // 视口信息
            if (window.innerWidth && window.innerHeight) {
                env.viewportWidth = window.innerWidth;
                env.viewportHeight = window.innerHeight;
            }
        }

        // 触摸支持
        if (typeof window !== 'undefined') {
            env.isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
        }

        // 存储支持
        if (typeof window !== 'undefined') {
            env.localStorage = typeof window.localStorage !== 'undefined';
            env.sessionStorage = typeof window.sessionStorage !== 'undefined';
        }

        return env;
    };

    /**
     * 初始化 SDK
     */
    Coconut.prototype.init = function (options) {
        options = options || {};
        if (options.debug) {
            this.debug = true;
            this.log('🥥 Coconut SDK v' + this.version);
            this.log('📱 Environment: ' + this.environment);
        }
        if (options.timeout) {
            this.defaultTimeout = options.timeout;
        }
        this.isInitialized = true;
        this._loadSecurityConfig();
        return this;
    };

    /**
     * 加载安全配置
     * 从 window.__coconutConfig 读取原生注入的 bridgeToken
     */
    Coconut.prototype._loadSecurityConfig = function () {
        if (typeof window !== 'undefined' && window.__coconutConfig) {
            this._securityConfig = window.__coconutConfig;
            if (this.debug) {
                this.log('🔒 Security config loaded: token=' +
                    (this._securityConfig.token ? '***' : 'none'));
            }
        } else {
            this._securityConfig = null;
        }
    };

    /**
     * 为请求附加 bridgeToken（同步）
     */
    Coconut.prototype._applySecurity = function (request) {
        // 延迟加载：首次调用时如果还没拿到原生注入的配置，再读一次
        if (!this._securityConfig && typeof window !== 'undefined' && window.__coconutConfig) {
            this._loadSecurityConfig();
        }

        var config = this._securityConfig;
        if (config && config.token) {
            request.bridgeToken = config.token;
        }
    };

    /**
     * 调用原生方法（回调方式）
     */
    Coconut.prototype.call = function (method, params, callback, timeout) {
        if (!this.isInitialized) {
            this.init({});
        }

        var self = this;
        var requestId = this.generateRequestId();
        var request = {
            method: method,
            params: params || {},
            id: requestId
        };

        var to = timeout || this.defaultTimeout;

        if (callback) {
            this.callbacks[requestId] = callback;
        }

        this.timers[requestId] = setTimeout(function () {
            self.cleanupRequest(requestId);
            if (callback) {
                callback({
                    id: requestId,
                    code: '200004',
                    message: 'Timeout after ' + to + 'ms',
                    result: null
                }, true);
            }
        }, to);

        this._applySecurity(request);
        this._sendBridgeRequest(request);

        if (this.debug) {
            this.log('📤 Call:', method, params);
        }
    };

    /**
     * 调用原生方法（Promise 方式）
     */
    Coconut.prototype.callAsync = function (method, params) {
        var self = this;
        return new Promise(function (resolve, reject) {
            self.call(method, params, function (response, isError) {
                if (isError) {
                    reject(response);
                } else {
                    resolve(response);
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
                    // 响应经 window.__coconutIOSCallback 异步回来
                } else {
                    throw new Error('CoconutBridge not found');
                }
            } else if (this.environment === 'harmony') {
                if (window.CoconutHarmonyBridge && window.CoconutHarmonyBridge.call) {
                    window.CoconutHarmonyBridge.call(requestJson);
                    // 响应经 window.__coconutHarmonyCallback 异步回来
                } else {
                    throw new Error('CoconutHarmonyBridge not found');
                }
            } else {
                // Web 环境模拟
                this.handleWebMock(request);
            }
        } catch (error) {
            this.error('Error sending request:', error);
            var errorCallback = this.callbacks[request.id];
            if (errorCallback) {
                errorCallback({
                    id: request.id,
                    code: '100005',
                    message: error.message,
                    result: null
                }, true);
                this.cleanupRequest(request.id);
            }
        }
    };

    /**
     * 处理 Web 环境模拟
     */
    Coconut.prototype.handleWebMock = function (request) {
        var self = this;
        setTimeout(function () {
            var mockResponse = {
                id: request.id,
                code: '000000',
                message: 'success (web mock)',
                result: {}
            };

            if (request.method === 'device.getInfo') {
                mockResponse.result = {
                    platform: 'web',
                    model: 'Mock Browser',
                    version: '1.0.0'
                };
            } else if (request.method === 'storage.getItem') {
                mockResponse.result = { key: request.params.key, value: null };
            } else if (request.method === 'storage.setItem') {
                mockResponse.result = { key: request.params.key, success: true };
            } else if (request.method === 'storage.removeItem') {
                mockResponse.result = { key: request.params.key, success: true };
            } else if (request.method === 'storage.clear') {
                mockResponse.result = { success: true };
            } else if (request.method === 'event.subscribe') {
                mockResponse.result = {
                    subscriptionId: request.params.subscriptionId,
                    topic: request.params.topic
                };
            } else if (request.method === 'event.unsubscribe') {
                mockResponse.result = { success: true };
            } else if (request.method === 'event.echo') {
                mockResponse.result = { scheduled: true, topic: 'test.echo' };
                // Simulate native emit after 500ms
                setTimeout(function () {
                    if (typeof window !== 'undefined' && window.__coconutEvent) {
                        var evt = {
                            subscriptionId: request.params.__testSubId || 'sub_mock',
                            topic: 'test.echo',
                            data: request.params
                        };
                        // Don't leak the internal marker
                        delete evt.data.__testSubId;
                        window.__coconutEvent(JSON.stringify(evt));
                    }
                }, 500);
            }

            self.handleResponse(JSON.stringify(mockResponse));
        }, 100);
    };

    /**
     * 处理原生响应
     */
    Coconut.prototype.handleResponse = function (responseJson) {
        try {
            var response = JSON.parse(responseJson);

            if (this.debug) {
                this.log('📥 Response:', response);
            }

            var requestId = response.id;
            var callback = this.callbacks[requestId];

            if (callback) {
                var isError = response.code !== '000000';

                callback(response, isError);
                this.cleanupRequest(requestId);
            }
        } catch (error) {
            this.error('Error handling response:', error);
        }
    };

    /**
     * 订阅原生事件
     *
     * 同步生成 subscriptionId 并立即注册本地 callback，然后异步向 native
     * 注册。这样 iOS/Harmony 异步响应窗口内的事件不会丢失 —— 即使
     * native 还没来得及登记 subscriptionId，本地 callback 已经在了，
     * native 端最终 emit 到时本地能正确路由。
     *
     * @param {string} topic - 事件主题（精确字符串匹配，无通配符）
     * @param {function} callback - 收到事件时的回调，签名 (event)
     *   event = { subscriptionId, topic, data }
     * @returns {string} subscriptionId —— 用于 unsubscribe
     */
    Coconut.prototype.subscribe = function (topic, callback) {
        if (!this.isInitialized) {
            this.init({});
        }
        if (typeof topic !== 'string' || topic.length === 0) {
            throw new Error('subscribe: topic must be a non-empty string');
        }
        if (typeof callback !== 'function') {
            throw new Error('subscribe: callback must be a function');
        }

        var subscriptionId = 'sub_' + Date.now() + '_' + (++this.subscriptionSeq);

        // 1) 本地登记 callback —— 必须先于 native 注册，避免响应窗口事件丢失
        this.subscriptions[subscriptionId] = { topic: topic, callback: callback };

        // 2) 异步向 native 注册（不阻塞订阅返回）
        this.call('event.subscribe', {
            topic: topic,
            subscriptionId: subscriptionId
        }, function (resp) {
            if (resp && resp.code !== '000000' && this.debug) {
                this.log('⚠️ subscribe ack failed for', subscriptionId, resp);
            }
        }.bind(this));

        if (this.debug) {
            this.log('📡 Subscribed:', subscriptionId, '->', topic);
        }

        return subscriptionId;
    };

    /**
     * 取消订阅
     *
     * @param {string} subscriptionId - subscribe() 返回的 id
     */
    Coconut.prototype.unsubscribe = function (subscriptionId) {
        if (!subscriptionId || !this.subscriptions[subscriptionId]) {
            return;
        }
        delete this.subscriptions[subscriptionId];

        // 通知 native 释放（即使 native 已清空也无害）
        this.call('event.unsubscribe', { subscriptionId: subscriptionId });

        if (this.debug) {
            this.log('🚫 Unsubscribed:', subscriptionId);
        }
    };

    /**
     * 处理原生推送的事件（由 window.__coconutEvent 调用）
     *
     * 事件 payload 格式：{ subscriptionId, topic, data }
     */
    Coconut.prototype.handleEvent = function (eventJson) {
        try {
            var event = JSON.parse(eventJson);
            var entry = event && this.subscriptions[event.subscriptionId];

            if (entry && typeof entry.callback === 'function') {
                entry.callback(event);
            }
        } catch (error) {
            this.error('Error handling event:', error);
        }
    };

    /**
     * 清理请求相关资源
     */
    Coconut.prototype.cleanupRequest = function (requestId) {
        delete this.callbacks[requestId];
        if (this.timers[requestId]) {
            clearTimeout(this.timers[requestId]);
            delete this.timers[requestId];
        }
    };

    /**
     * 生成请求 ID
     */
    Coconut.prototype.generateRequestId = function () {
        return 'req_' + Date.now() + '_' + (++this.requestId);
    };

    /**
     * 日志输出
     */
    Coconut.prototype.log = function () {
        if (this.debug && console && console.log) {
            var args = ['[Coconut]'].concat(Array.prototype.slice.call(arguments));
            console.log.apply(console, args);
        }
    };

    Coconut.prototype.error = function () {
        if (console && console.error) {
            var args = ['[Coconut]'].concat(Array.prototype.slice.call(arguments));
            console.error.apply(console, args);
        }
    };

    // 创建单例
    var CoconutSDK = new Coconut();

    /**
     * 快捷方法 - 设备组件
     */
    Coconut.prototype.device = {
        getInfo: function (callback) {
            return CoconutSDK.call('device.getInfo', {}, callback);
        }
    };

    /**
     * 快捷方法 - 存储组件
     */
    Coconut.prototype.storage = {
        setItem: function (key, value, callback) {
            return CoconutSDK.call('storage.setItem', { key: key, value: value }, callback);
        },
        getItem: function (key, callback) {
            return CoconutSDK.call('storage.getItem', { key: key }, callback);
        },
        removeItem: function (key, callback) {
            return CoconutSDK.call('storage.removeItem', { key: key }, callback);
        },
        clear: function (callback) {
            return CoconutSDK.call('storage.clear', {}, callback);
        },
        getAllKeys: function (callback) {
            return CoconutSDK.call('storage.getAllKeys', {}, callback);
        },
        getLength: function (callback) {
            return CoconutSDK.call('storage.getLength', {}, callback);
        }
    };

    // iOS / Harmony 异步响应回调入口（持久注册，由原生 evaluateJavaScript 调用）
    if (typeof window !== 'undefined') {
        window.__coconutIOSCallback = function (responseJson) {
            CoconutSDK.handleResponse(responseJson);
        };
        window.__coconutHarmonyCallback = function (responseJson) {
            CoconutSDK.handleResponse(responseJson);
        };
        // 原生事件推送入口（native → H5，三端共用同一回调名）
        window.__coconutEvent = function (eventJson) {
            CoconutSDK.handleEvent(eventJson);
        };
    }

    // 自动初始化
    if (typeof window !== 'undefined') {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', function () {
                CoconutSDK.init({ debug: false });
            });
        } else {
            CoconutSDK.init({ debug: false });
        }
    }

    return CoconutSDK;

})));
