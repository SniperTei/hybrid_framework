import Foundation
import Alamofire

/// 网络请求插件
public class NetworkPlugin: BasePlugin {
    private var session: Session?
    private var config: NetworkConfig?
    private var downloadTasks: [String: DownloadRequest] = [:]

    public override func pluginName() -> String {
        return "http"
    }

    public override func exec(action: String, params: [String: Any], callback: PluginCallback) {
        switch action {
        case "GET", "POST", "PUT", "DELETE", "PATCH":
            request(method: HTTPMethod(rawValue: action), params: params, callback: callback)
        case "upload":
            upload(params: params, callback: callback)
        case "download":
            download(params: params, callback: callback)
        case "setConfig":
            setConfig(params: params, callback: callback)
        default:
            callback.error(code: "UNKNOWN_ACTION", message: "Unknown action: \(action)")
        }
    }

    // MARK: - HTTP请求

    private func request(method: HTTPMethod?, params: [String: Any], callback: PluginCallback) {
        guard let method = method else {
            callback.error(code: "INVALID_PARAMS", message: "Invalid HTTP method")
            return
        }

        guard let urlString = optString(params, "url") else {
            callback.error(code: "INVALID_PARAMS", message: "URL is required")
            return
        }

        let headers = parseHeaders(params)
        let timeout = optDouble(params, "timeout", defaultValue: config?.connectTimeout ?? 30.0) ?? 30.0

        // 构建完整URL
        var fullURL = urlString
        if let baseURL = config?.baseURL, !urlString.hasPrefix("http") {
            fullURL = baseURL + urlString
        }

        // 配置Session
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout

        let session = Session(configuration: configuration)
        self.session = session

        // 构建请求
        var request = session.request(fullURL, method: method, headers: headers)

        // 处理参数
        if method == .GET {
            let parameters = buildParameters(params)
            request = session.request(fullURL, parameters: parameters, headers: headers)
        } else {
            if let parameters = buildParameters(params) {
                request = session.request(
                    fullURL,
                    method: method,
                    parameters: parameters,
                    encoding: JSONEncoding.default,
                    headers: headers
                )
            } else {
                request = session.request(fullURL, method: method, headers: headers)
            }
        }

        // 发起请求
        request.validate().responseJSON { response in
            switch response.result {
            case .success(let json):
                if let dict = json as? [String: Any] {
                    callback.success([
                        "data": dict,
                        "statusCode": response.response?.statusCode ?? 0,
                        "headers": self.parseResponseHeaders(response.response)
                    ])
                } else if let array = json as? [Any] {
                    callback.success([
                        "data": array,
                        "statusCode": response.response?.statusCode ?? 0,
                        "headers": self.parseResponseHeaders(response.response)
                    ])
                } else {
                    callback.success([
                        "data": json,
                        "statusCode": response.response?.statusCode ?? 0,
                        "headers": self.parseResponseHeaders(response.response)
                    ])
                }

            case .failure(let error):
                let statusCode = response.response?.statusCode ?? 0
                callback.error(
                    code: statusCode == 0 ? "NETWORK_ERROR" : "HTTP_ERROR_\(statusCode)",
                    message: error.localizedDescription
                )
            }
        }
    }

    // MARK: - 文件上传

    private func upload(params: [String: Any], callback: PluginCallback) {
        guard let urlString = optString(params, "url") else {
            callback.error(code: "INVALID_PARAMS", message: "URL is required")
            return
        }

        guard let filePath = optString(params, "filePath") else {
            callback.error(code: "INVALID_PARAMS", message: "filePath is required")
            return
        }

        let fileURL = URL(fileURLWithPath: filePath.replacingOccurrences(of: "file://", with: ""))

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            callback.error(code: "FILE_NOT_FOUND", message: "File not found")
            return
        }

        let headers = parseHeaders(params)
        let name = optString(params, "name", defaultValue: "file") ?? "file"
        let fileName = optString(params, "fileName", defaultValue: fileURL.lastPathComponent) ?? fileURL.lastPathComponent
        let mimeType = optString(params, "mimeType", defaultValue: "application/octet-stream") ?? "application/octet-stream"

        // 构建完整URL
        var fullURL = urlString
        if let baseURL = config?.baseURL, !urlString.hasPrefix("http") {
            fullURL = baseURL + urlString
        }

        // 上传文件
        session?.upload(fileURL, to: fullURL, method: .post, headers: headers)
            .validate()
            .uploadProgress { progress in
                callback.progress(Int(progress.fractionCompleted * 100))
            }
            .responseJSON { response in
                switch response.result {
                case .success(let json):
                    callback.success([
                        "data": json ?? "",
                        "statusCode": response.response?.statusCode ?? 0
                    ])
                case .failure(let error):
                    callback.error(
                        code: "NETWORK_ERROR",
                        message: error.localizedDescription
                    )
                }
            }
    }

    // MARK: - 文件下载

    private func download(params: [String: Any], callback: PluginCallback) {
        guard let urlString = optString(params, "url") else {
            callback.error(code: "INVALID_PARAMS", message: "URL is required")
            return
        }

        guard let savePath = optString(params, "savePath") else {
            callback.error(code: "INVALID_PARAMS", message: "savePath is required")
            return
        }

        // 构建完整URL
        var fullURL = urlString
        if let baseURL = config?.baseURL, !urlString.hasPrefix("http") {
            fullURL = baseURL + urlString
        }

        let destination: DownloadRequest.Destination = { _, _ in
            let fileURL = URL(fileURLWithPath: savePath.replacingOccurrences(of: "file://", with: ""))
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }

        // 下载文件
        let downloadRequest = session?.download(fullURL, to: destination)
            .validate()
            .downloadProgress { progress in
                callback.progress(Int(progress.fractionCompleted * 100))
            }
            .response { response in
                switch response.result {
                case .success(let fileURL):
                    if let fileURL = fileURL {
                        callback.success([
                            "path": fileURL.path,
                            "statusCode": response.response?.statusCode ?? 0
                        ])
                    } else {
                        callback.success([:])
                    }
                case .failure(let error):
                    callback.error(
                        code: "NETWORK_ERROR",
                        message: error.localizedDescription
                    )
                }
            }

        // 保存下载任务引用
        if let downloadRequest = downloadRequest, let callbackId = optString(params, "callbackId") {
            downloadTasks[callbackId] = downloadRequest
        }
    }

    // MARK: - 配置

    private func setConfig(params: [String: Any], callback: PluginCallback) {
        let builder = NetworkConfig.Builder()

        if let baseURL = optString(params, "baseURL") {
            builder.setBaseURL(baseURL)
        }

        if let connectTimeout = optDouble(params, "connectTimeout") {
            builder.setConnectTimeout(connectTimeout)
        }

        if let readTimeout = optDouble(params, "readTimeout") {
            builder.setReadTimeout(readTimeout)
        }

        if let enableCache = optBool(params, "enableCache") {
            builder.setEnableCache(enableCache)
        }

        config = builder.build()

        // 重新配置Session
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config?.connectTimeout ?? 30.0
        session = Session(configuration: configuration)

        callback.success(["message": "Configuration updated"])
    }

    // MARK: - 辅助方法

    private func parseHeaders(_ params: [String: Any]) -> HTTPHeaders {
        var headers = config?.defaultHeaders ?? HTTPHeaders()

        if let headersDict = optDict(params, "headers") {
            for (key, value) in headersDict {
                if let stringValue = value as? String {
                    headers.add(name: key, value: stringValue)
                }
            }
        }

        return headers
    }

    private func parseResponseHeaders(_ response: HTTPURLResponse?) -> [String: String] {
        guard let response = response else {
            return [:]
        }

        return response.allHeaderFields as? [String: String] ?? [:]
    }

    private func buildParameters(_ params: [String: Any]) -> [String: Any]? {
        // 移除特殊参数
        var cleanParams = params
        cleanParams.removeValue(forKey: "url")
        cleanParams.removeValue(forKey: "headers")
        cleanParams.removeValue(forKey: "timeout")
        cleanParams.removeValue(forKey: "callbackId")

        return cleanParams.isEmpty ? nil : cleanParams
    }

    /// 取消下载任务
    public func cancelDownload(callbackId: String) {
        downloadTasks[callbackId]?.cancel()
        downloadTasks.removeValue(forKey: callbackId)
    }

    public override func onDetach() {
        super.onDetach()
        session?.cancelAllRequests()
        downloadTasks.removeAll()
    }
}
