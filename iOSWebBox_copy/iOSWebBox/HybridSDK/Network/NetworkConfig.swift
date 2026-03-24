import Foundation
import Alamofire

/// 网络配置类
/// 使用Builder模式构建配置
public class NetworkConfig {
    /// 基础URL
    public var baseURL: String?

    /// 连接超时时间(秒)
    public var connectTimeout: TimeInterval

    /// 读取超时时间(秒)
    public var readTimeout: TimeInterval

    /// 是否启用缓存
    public var enableCache: Bool

    /// 默认请求头
    public var defaultHeaders: HTTPHeaders

    /// 请求拦截器列表
    public var requestInterceptors: [RequestInterceptor]

    /// 响应拦截器列表
    public var responseInterceptors: [ResponseInterceptor]

    /// 是否启用重试
    public var enableRetry: Bool

    /// 重试次数
    public var retryCount: Int

    private init(
        baseURL: String?,
        connectTimeout: TimeInterval,
        readTimeout: TimeInterval,
        enableCache: Bool,
        defaultHeaders: HTTPHeaders,
        requestInterceptors: [RequestInterceptor],
        responseInterceptors: [ResponseInterceptor],
        enableRetry: Bool,
        retryCount: Int
    ) {
        self.baseURL = baseURL
        self.connectTimeout = connectTimeout
        self.readTimeout = readTimeout
        self.enableCache = enableCache
        self.defaultHeaders = defaultHeaders
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
        self.enableRetry = enableRetry
        self.retryCount = retryCount
    }

    /// Builder类
    public class Builder {
        private var baseURL: String? = nil
        private var connectTimeout: TimeInterval = 30.0
        private var readTimeout: TimeInterval = 30.0
        private var enableCache: Bool = true
        private var defaultHeaders: HTTPHeaders = HTTPHeaders()
        private var requestInterceptors: [RequestInterceptor] = []
        private var responseInterceptors: [ResponseInterceptor] = []
        private var enableRetry: Bool = true
        private var retryCount: Int = 3

        public init() {}

        public func setBaseURL(_ url: String) -> Builder {
            self.baseURL = url
            return self
        }

        public func setConnectTimeout(_ timeout: TimeInterval) -> Builder {
            self.connectTimeout = timeout
            return self
        }

        public func setReadTimeout(_ timeout: TimeInterval) -> Builder {
            self.readTimeout = timeout
            return self
        }

        public func setEnableCache(_ enabled: Bool) -> Builder {
            self.enableCache = enabled
            return self
        }

        public func setDefaultHeaders(_ headers: HTTPHeaders) -> Builder {
            self.defaultHeaders = headers
            return self
        }

        public func addDefaultHeader(_ name: String, value: String) -> Builder {
            self.defaultHeaders.add(name: name, value: value)
            return self
        }

        public func addRequestInterceptor(_ interceptor: RequestInterceptor) -> Builder {
            self.requestInterceptors.append(interceptor)
            return self
        }

        public func addResponseInterceptor(_ interceptor: ResponseInterceptor) -> Builder {
            self.responseInterceptors.append(interceptor)
            return self
        }

        public func setEnableRetry(_ enabled: Bool) -> Builder {
            self.enableRetry = enabled
            return self
        }

        public func setRetryCount(_ count: Int) -> Builder {
            self.retryCount = count
            return self
        }

        public func build() -> NetworkConfig {
            return NetworkConfig(
                baseURL: baseURL,
                connectTimeout: connectTimeout,
                readTimeout: readTimeout,
                enableCache: enableCache,
                defaultHeaders: defaultHeaders,
                requestInterceptors: requestInterceptors,
                responseInterceptors: responseInterceptors,
                enableRetry: enableRetry,
                retryCount: retryCount
            )
        }
    }
}

/// 响应拦截器协议
public protocol ResponseInterceptor: AnyObject {
    func intercept(response: HTTPURLResponse?, data: Data?, error: Error?)
}
