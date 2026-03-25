//
//  HybridConfig.swift
//  iOSWebBox
//
//  Hybrid framework configuration
//

import Foundation
import WebKit

public class HybridConfig {
    public var defaultURL: String
    public var debugMode: Bool
    public var allowedDomains: [String]
    public var enableCache: Bool
    public var enableDomStorage: Bool
    public var allowFileAccess: Bool
    public var cacheMode: WKWebsiteDataStore

    public init(defaultURL: String = "about:blank",
                debugMode: Bool = false,
                allowedDomains: [String] = [],
                enableCache: Bool = true,
                enableDomStorage: Bool = true,
                allowFileAccess: Bool = true,
                cacheMode: WKWebsiteDataStore = .default()) {
        self.defaultURL = defaultURL
        self.debugMode = debugMode
        self.allowedDomains = allowedDomains
        self.enableCache = enableCache
        self.enableDomStorage = enableDomStorage
        self.allowFileAccess = allowFileAccess
        self.cacheMode = cacheMode
    }

    public func isUrlAllowed(_ url: String) -> Bool {
        if allowedDomains.isEmpty {
            return true
        }

        guard let urlObj = URL(string: url) else { return false }
        let host = urlObj.host ?? ""

        return allowedDomains.contains { host.hasSuffix($0) }
    }

    public class Builder {
        private var defaultURL: String = "about:blank"
        private var debugMode: Bool = false
        private var allowedDomains: [String] = []
        private var enableCache: Bool = true
        private var enableDomStorage: Bool = true
        private var allowFileAccess: Bool = true

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

        public func build() -> HybridConfig {
            return HybridConfig(
                defaultURL: defaultURL,
                debugMode: debugMode,
                allowedDomains: allowedDomains,
                enableCache: enableCache,
                enableDomStorage: enableDomStorage,
                allowFileAccess: allowFileAccess
            )
        }
    }
}
