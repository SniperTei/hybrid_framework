import Foundation
import Network

public class NetworkComponent: BaseComponent {

    override public var name: String { "network" }
    override public var version: String { "2.0.0" }
    override public var pluginDescription: String { "Network status and native HTTP proxy component" }

    private var extraHeaders: [String: String] = [:]

    override public func handle(function: String, params: [String: Any]?) async throws -> [String: Any] {
        switch function {
        case "getType": return getNetworkType()
        case "getState": return getNetworkState()
        case "isConnected": return isConnected()
        case "request": return try await httpRequest(params)
        case "get": return try await httpGet(params)
        case "post": return try await httpPost(params)
        default: try functionNotSupportedError(function)
        }
    }

    private func getNetworkType() -> [String: Any] {
        let type: String
        if let connection = NetworkMonitor.shared.currentType {
            switch connection {
            case .wifi: type = "wifi"
            case .cellular: type = "cellular"
            case .vpn: type = "vpn"
            }
        } else {
            type = "none"
        }
        return success(["type": type])
    }

    private func getNetworkState() -> [String: Any] {
        let connected = NetworkMonitor.shared.isConnected
        let type: String
        if let connection = NetworkMonitor.shared.currentType {
            switch connection {
            case .wifi: type = "wifi"
            case .cellular: type = "cellular"
            case .vpn: type = "vpn"
            }
        } else {
            type = connected ? "unknown" : "none"
        }
        return success(["isConnected": connected, "type": type])
    }

    private func isConnected() -> [String: Any] {
        return success(["isConnected": NetworkMonitor.shared.isConnected])
    }

    private func httpRequest(_ params: [String: Any]?) async throws -> [String: Any] {
        let url = getParam(params, "url")
        if url.isEmpty { try error("200007", "url is required") }

        let method = getParam(params, "method", "GET").uppercased()
        let timeout = getIntParam(params, "timeout", 15000)
        let contentType = getParam(params, "contentType", "application/json")
        let body = getParam(params, "body", "")

        var headers = extraHeaders
        if let h5Headers = params?["headers"] as? [String: Any] {
            for (k, v) in h5Headers {
                if let str = v as? String { headers[k] = str }
            }
        }

        Logger.shared.d(name, "Native request: \(method) \(url)")

        do {
            guard let requestUrl = URL(string: url) else {
                try error("200007", "Invalid URL: \(url)")
            }

            var request = URLRequest(url: requestUrl)
            request.httpMethod = method
            request.timeoutInterval = Double(timeout) / 1000.0

            for (k, v) in headers {
                request.setValue(v, forHTTPHeaderField: k)
            }

            if method != "GET" && !body.isEmpty {
                request.httpBody = body.data(using: .utf8)
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseBody = String(data: data, encoding: .utf8) ?? ""

            var responseHeaders: [String: String] = [:]
            if let httpRes = response as? HTTPURLResponse {
                for (key, value) in httpRes.allHeaderFields {
                    if let keyStr = key as? String, let valueStr = value as? String {
                        responseHeaders[keyStr] = valueStr
                    }
                }
            }

            Logger.shared.d(name, "Response: \(statusCode) (\(responseBody.count) bytes)")

            return success([
                "statusCode": statusCode,
                "body": responseBody,
                "headers": "\(responseHeaders)"
            ])
        } catch {
            Logger.shared.e(name, "Request failed: \(url)", error)
            return success([
                "statusCode": -1,
                "error": error.localizedDescription
            ])
        }
    }

    private func httpGet(_ params: [String: Any]?) async throws -> [String: Any] {
        var merged = params ?? [:]
        merged["method"] = "GET"
        return try await httpRequest(merged)
    }

    private func httpPost(_ params: [String: Any]?) async throws -> [String: Any] {
        var merged = params ?? [:]
        merged["method"] = "POST"
        return try await httpRequest(merged)
    }

    public func addExtraHeader(_ key: String, _ value: String) {
        extraHeaders[key] = value
    }

    override public func onCleanup() async {
        extraHeaders.removeAll()
    }
}

class NetworkMonitor {
    static let shared = NetworkMonitor()

    enum ConnectionType {
        case wifi, cellular, vpn
    }

    private(set) var isConnected = false
    private(set) var currentType: ConnectionType?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.coconut.networkmonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            if path.usesInterfaceType(.wifi) {
                self?.currentType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                self?.currentType = .cellular
            } else if path.usesInterfaceType(.other) {
                self?.currentType = .vpn
            } else {
                self?.currentType = nil
            }
        }
        monitor.start(queue: queue)
    }
}
