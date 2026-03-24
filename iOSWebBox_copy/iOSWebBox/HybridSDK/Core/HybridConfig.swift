import Foundation

/// 混合框架配置类
/// 使用Builder模式构建配置
public class HybridConfig {
    /// 默认加载的URL
    public var defaultURL: String

    /// 调试模式
    public var debugMode: Bool

    /// 允许访问的域名白名单
    public var allowedDomains: [String]

    /// 是否启用缓存
    public var enableCache: Bool

    /// 是否启用DOM Storage
    public var enableDomStorage: Bool

    /// 是否允许文件访问
    public var allowFileAccess: Bool

    /// 是否允许Content Access
    public var allowContentAccess: Bool

    /// 是否启用数据库
    public var enableDatabase: Bool

    /// 自定义User-Agent
    public var userAgent: String?

    /// 缓存模式
    public var cacheMode: CacheMode

    /// 混合内容模式
    public var mixedContentMode: MixedContentMode

    public enum CacheMode {
        case defaultMode
        case loadNoCache
        case loadCacheOnly
    }

    public enum MixedContentMode {
        case neverAllow
        case alwaysAllow
        case compatibilityMode
    }

    private init(
        defaultURL: String,
        debugMode: Bool,
        allowedDomains: [String],
        enableCache: Bool,
        enableDomStorage: Bool,
        allowFileAccess: Bool,
        allowContentAccess: Bool,
        enableDatabase: Bool,
        userAgent: String?,
        cacheMode: CacheMode,
        mixedContentMode: MixedContentMode
    ) {
        self.defaultURL = defaultURL
        self.debugMode = debugMode
        self.allowedDomains = allowedDomains
        self.enableCache = enableCache
        self.enableDomStorage = enableDomStorage
        self.allowFileAccess = allowFileAccess
        self.allowContentAccess = allowContentAccess
        self.enableDatabase = enableDatabase
        self.userAgent = userAgent
        self.cacheMode = cacheMode
        self.mixedContentMode = mixedContentMode
    }

    /// 检查URL是否在白名单中
    public func isUrlAllowed(_ url: String) -> Bool {
        // 如果白名单为空,允许所有URL
        if allowedDomains.isEmpty {
            return true
        }

        guard let urlObj = URL(string: url) else {
            return false
        }

        let host = urlObj.host ?? ""

        // 检查是否在白名单中
        for domain in allowedDomains {
            if host == domain || host.hasSuffix("." + domain) {
                return true
            }
        }

        return false
    }

    /// Builder类
    public class Builder {
        private var defaultURL: String = ""
        private var debugMode: Bool = false
        private var allowedDomains: [String] = []
        private var enableCache: Bool = true
        private var enableDomStorage: Bool = true
        private var allowFileAccess: Bool = true
        private var allowContentAccess: Bool = true
        private var enableDatabase: Bool = true
        private var userAgent: String? = nil
        private var cacheMode: CacheMode = .defaultMode
        private var mixedContentMode: MixedContentMode = .compatibilityMode

        public init() {}

        public func setDefaultURL(_ url: String) -> Builder {
            self.defaultURL = url
            return self
        }

        public func setDebugMode(_ enabled: Bool) -> Builder {
            self.debugMode = enabled
            return self
        }

        public func setAllowedDomains(_ domains: [String]) -> Builder {
            self.allowedDomains = domains
            return self
        }

        public func setEnableCache(_ enabled: Bool) -> Builder {
            self.enableCache = enabled
            return self
        }

        public func setEnableDomStorage(_ enabled: Bool) -> Builder {
            self.enableDomStorage = enabled
            return self
        }

        public func setAllowFileAccess(_ allowed: Bool) -> Builder {
            self.allowFileAccess = allowed
            return self
        }

        public func setAllowContentAccess(_ allowed: Bool) -> Builder {
            self.allowContentAccess = allowed
            return self
        }

        public func setEnableDatabase(_ enabled: Bool) -> Builder {
            self.enableDatabase = enabled
            return self
        }

        public func setUserAgent(_ userAgent: String) -> Builder {
            self.userAgent = userAgent
            return self
        }

        public func setCacheMode(_ mode: CacheMode) -> Builder {
            self.cacheMode = mode
            return self
        }

        public func setMixedContentMode(_ mode: MixedContentMode) -> Builder {
            self.mixedContentMode = mode
            return self
        }

        public func build() -> HybridConfig {
            return HybridConfig(
                defaultURL: defaultURL,
                debugMode: debugMode,
                allowedDomains: allowedDomains,
                enableCache: enableCache,
                enableDomStorage: enableDomStorage,
                allowFileAccess: allowFileAccess,
                allowContentAccess: allowContentAccess,
                enableDatabase: enableDatabase,
                userAgent: userAgent,
                cacheMode: cacheMode,
                mixedContentMode: mixedContentMode
            )
        }
    }
}
