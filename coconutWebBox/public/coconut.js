/**
 * 🥥 Coconut SDK - JavaScript Client
 *
 * Coconut SDK 的 JavaScript 客户端，用于与 Android 原生代码交互
 * 支持 Phase 4 安全特性：Bridge Token 防护 & HMAC-SHA256 请求签名
 *
 * @version 1.1.0
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
        this.version = '2.0.0';
        this.debug = false;
        this.defaultTimeout = 30000;
        this.isInitialized = false;
        this.requestId = 0;
        this.callbacks = {};
        this.timers = {};
        this.environment = this.detectEnvironment();
        this.env = this.createEnv();
        this._securityConfig = null; // Phase 4: 缓存安全配置
    };

    /**
     * 检测运行环境
     */
    Coconut.prototype.detectEnvironment = function () {
        if (typeof window === 'undefined' || !window.document) {
            return 'node';
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
        env.isWeb = this.environment === 'web';
        env.isNode = this.environment === 'node';
        env.isNative = env.isAndroid || env.isiOS;

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
     * Phase 4: 加载安全配置
     * 从 window.__coconutConfig 读取 Android 注入的安全参数
     */
    Coconut.prototype._loadSecurityConfig = function () {
        if (typeof window !== 'undefined' && window.__coconutConfig) {
            this._securityConfig = window.__coconutConfig;
            if (this.debug) {
                this.log('🔒 Security config loaded: token=' +
                    (this._securityConfig.token ? '***' : 'none') +
                    ', signing=' + !!this._securityConfig.signingEnabled);
            }
        } else {
            this._securityConfig = null;
        }
    };

    /**
     * Phase 4: 为请求附加安全字段
     * 返回 Promise，因为 HMAC 计算是异步的
     */
    Coconut.prototype._applySecurity = function (request) {
        var self = this;

        // 延迟加载：首次调用时如果还没拿到 Android 注入的配置，再读一次
        if (!this._securityConfig && typeof window !== 'undefined' && window.__coconutConfig) {
            this._loadSecurityConfig();
        }

        var config = this._securityConfig;

        // 无安全配置时直接返回
        if (!config) {
            return Promise.resolve(request);
        }

        // 1. 附加 bridgeToken
        if (config.token) {
            request.bridgeToken = config.token;
        }

        // 2. 签名未启用，直接返回
        if (!config.signingEnabled || !config.sharedSecret) {
            return Promise.resolve(request);
        }

        // 3. 计算 HMAC-SHA256 签名
        var ts = Date.now();
        var nonce = ts.toString(36) + '-' + Math.random().toString(36).substr(2, 9);
        request.timestamp = ts;
        request.nonce = nonce;

        var paramsStr = JSON.stringify(request.params || {});
        var payload = request.method + '|' + request.id + '|' + ts + '|' + nonce + '|' + paramsStr;

        return self._computeHmac(config.sharedSecret, payload).then(function (sig) {
            request.sign = sig;
            if (self.debug) {
                self.log('🔐 Request signed:', request.method);
            }
            return request;
        });
    };

    /**
     * Phase 4: HMAC-SHA256 计算（Web Crypto API）
     */
    Coconut.prototype._computeHmac = function (key, message) {
        try {
            var encoder = new TextEncoder();
            var keyData = encoder.encode(key);
            var msgData = encoder.encode(message);

            return crypto.subtle.importKey(
                'raw', keyData,
                { name: 'HMAC', hash: 'SHA-256' },
                false, ['sign']
            ).then(function (cryptoKey) {
                return crypto.subtle.sign('HMAC', cryptoKey, msgData);
            }).then(function (sig) {
                var arr = Array.from(new Uint8Array(sig));
                return arr.map(function (b) {
                    return b.toString(16).padStart(2, '0');
                }).join('');
            });
        } catch (e) {
            this.error('HMAC computation failed:', e);
            return Promise.reject(e);
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
            jsonrpc: '2.0',
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
                    jsonrpc: '2.0',
                    id: requestId,
                    code: '200004',
                    message: 'Timeout after ' + to + 'ms',
                    result: null
                }, true);
            }
        }, to);

        this._applySecurity(request).then(function (securedRequest) {
            self._sendBridgeRequest(securedRequest);
        }).catch(function (error) {
            self.error('Security apply failed:', error);
            if (callback) {
                callback({ jsonrpc: '2.0', id: requestId, code: '100005', message: 'Security error: ' + error.message, result: null }, true);
                self.cleanupRequest(requestId);
            }
        });

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
     * 发送请求到原生（纯同步桥调用）
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
                    // Response will come back asynchronously via __coconutIOSCallback
                } else {
                    throw new Error('CoconutBridge not found');
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
                    jsonrpc: '2.0',
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
                jsonrpc: '2.0',
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
            } else if (request.method === 'system.getVersion') {
                mockResponse.result = { version: '2.0.0' };
            } else if (request.method === 'system.getComponentVersion') {
                mockResponse.result = { name: request.params.name, version: '1.0.0' };
            } else if (request.method === 'system.getAllComponents') {
                mockResponse.result = { components: ['device', 'network', 'storage', 'system', 'security'] };
            } else if (request.method === 'system.checkCapability') {
                mockResponse.result = { method: request.params.method, supported: true };
            } else if (request.method === 'security.getAuditLog') {
                mockResponse.result = { entries: [], total: 0 };
            } else if (request.method === 'security.getAuditSummary') {
                mockResponse.result = { totalCalls: 0, blockedCalls: 0, lastActivity: null };
            } else if (request.method === 'security.getSecurityConfig') {
                mockResponse.result = { bridgeTokenEnabled: false, signingEnabled: false };
            } else if (request.method === 'security.clearAuditLog') {
                mockResponse.result = { cleared: true };
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

    /**
     * 快捷方法 - 设备组件
     */
    Coconut.prototype.device = {
        getInfo: function (callback) {
            return Coconut.call('device.getInfo', {}, callback);
        }
    };

    /**
     * 快捷方法 - 网络组件
     */
    Coconut.prototype.network = {
        request: function (options, callback) {
            return Coconut.call('network.request', options, callback);
        },
        get: function (url, callback) {
            return Coconut.call('network.request', { url: url, method: 'GET' }, callback);
        },
        post: function (url, data, callback) {
            return Coconut.call('network.request', { url: url, method: 'POST', body: data }, callback);
        },
        put: function (url, data, callback) {
            return Coconut.call('network.request', { url: url, method: 'PUT', body: data }, callback);
        },
        delete: function (url, callback) {
            return Coconut.call('network.request', { url: url, method: 'DELETE' }, callback);
        },
        patch: function (url, data, callback) {
            return Coconut.call('network.request', { url: url, method: 'PATCH', body: data }, callback);
        }
    };

    /**
     * 快捷方法 - 存储组件
     */
    Coconut.prototype.storage = {
        setItem: function (key, value, callback) {
            return Coconut.call('storage.setItem', { key: key, value: value }, callback);
        },
        getItem: function (key, callback) {
            return Coconut.call('storage.getItem', { key: key }, callback);
        },
        removeItem: function (key, callback) {
            return Coconut.call('storage.removeItem', { key: key }, callback);
        },
        clear: function (callback) {
            return Coconut.call('storage.clear', {}, callback);
        },
        getAllKeys: function (callback) {
            return Coconut.call('storage.getAllKeys', {}, callback);
        },
        getLength: function (callback) {
            return Coconut.call('storage.getLength', {}, callback);
        }
    };

    /**
     * 快捷方法 - System 组件
     */
    Coconut.prototype.system = {
        getVersion: function (callback) {
            return Coconut.call('system.getVersion', {}, callback);
        },
        getComponentVersion: function (name, callback) {
            return Coconut.call('system.getComponentVersion', { name: name }, callback);
        },
        getAllComponents: function (callback) {
            return Coconut.call('system.getAllComponents', {}, callback);
        },
        checkCapability: function (method, callback) {
            return Coconut.call('system.checkCapability', { method: method }, callback);
        }
    };

    /**
     * 快捷方法 - Security 组件
     */
    Coconut.prototype.security = {
        getAuditLog: function (options, callback) {
            return Coconut.call('security.getAuditLog', options || {}, callback);
        },
        getAuditSummary: function (callback) {
            return Coconut.call('security.getAuditSummary', {}, callback);
        },
        getSecurityConfig: function (callback) {
            return Coconut.call('security.getSecurityConfig', {}, callback);
        },
        clearAuditLog: function (callback) {
            return Coconut.call('security.clearAuditLog', {}, callback);
        }
    };

    // 创建单例
    var CoconutSDK = new Coconut();

    // iOS bridge callback (called by native side via evaluateJavaScript)
    if (typeof window !== 'undefined') {
        window.__coconutIOSCallback = function (responseJson) {
            if (CoconutSDK && CoconutSDK.handleResponse) {
                CoconutSDK.handleResponse(responseJson);
            }
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
