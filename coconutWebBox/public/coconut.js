/**
 * 🥥 Coconut SDK - JavaScript Client
 *
 * Coconut SDK 的 JavaScript 客户端，用于与 Android 原生代码交互
 *
 * @version 1.0.0
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
        this.version = '1.0.0';
        this.debug = false;
        this.defaultTimeout = 30000;
        this.isInitialized = false;
        this.requestId = 0;
        this.callbacks = {};
        this.timers = {};
        this.environment = this.detectEnvironment();
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
        return this;
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
                    error: 'Timeout after ' + to + 'ms'
                }, true);
            }
        }, to);

        this.sendRequest(request);

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
    Coconut.prototype.sendRequest = function (request) {
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
            } else {
                // Web 环境模拟
                this.handleWebMock(request);
            }
        } catch (error) {
            this.error('Error sending request:', error);
            var errorCallback = this.callbacks[request.id];
            if (errorCallback) {
                errorCallback({
                    error: error.message
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
                result: {
                    code: '000000',
                    message: 'success (web mock)',
                    data: {}
                }
            };

            if (request.method === 'device.getInfo') {
                mockResponse.result.data = {
                    platform: 'web',
                    model: 'Mock Browser',
                    version: '1.0.0'
                };
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
                var isError = false;
                if (response.error) {
                    isError = true;
                } else if (response.result && response.result.code !== '000000') {
                    isError = true;
                }

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
        }
    };

    // 创建单例
    var CoconutSDK = new Coconut();

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
