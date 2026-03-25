//
//  NetworkPlugin.swift
//  iOSWebBox
//
//  HTTP network plugin (using URLSession)
//

import Foundation

public class NetworkPlugin: BasePlugin {
    private var session: URLSession?
    private var baseURL: String?
    private var defaultHeaders: [String: String] = [:]

    public override func pluginName() -> String {
        return "http"
    }

    public func onAttach(context: PluginContext) {
        super.onAttach(context: context)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    public override func exec(action: String, params: [String: Any], callback: PluginCallback) {
        switch action {
        case "GET", "POST", "PUT", "DELETE", "PATCH":
            request(method: action, params: params, callback: callback)
        case "upload":
            upload(params: params, callback: callback)
        case "download":
            download(params: params, callback: callback)
        case "setConfig":
            setConfig(params: params, callback: callback)
        default:
            super.exec(action: action, params: params, callback: callback)
        }
    }

    private func setConfig(params: [String: Any], callback: PluginCallback) {
        if let url = optString(params, "baseURL") {
            self.baseURL = url
        }

        if let headers = params["headers"] as? [String: String] {
            self.defaultHeaders = headers
        }

        if let timeout = optInt(params, "timeout") {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = TimeInterval(timeout) / 1000
            session = URLSession(configuration: config)
        }

        callback.success(["success": true])
    }

    private func request(method: String, params: [String: Any], callback: PluginCallback) {
        guard let urlString = optString(params, "url") else {
            callback.error("INVALID_PARAMS", message: "Missing url parameter")
            return
        }

        let url = baseURL.map { urlString.hasPrefix("http") ? urlString : $0 + urlString } ?? urlString
        guard let urlObj = URL(string: url) else {
            callback.error("INVALID_PARAMS", message: "Invalid URL: \(url)")
            return
        }

        var request = URLRequest(url: urlObj)
        request.httpMethod = method

        // Set headers
        if let headers = params["headers"] as? [String: String] {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Add default headers
        for (key, value) in defaultHeaders {
            if request.value(forHTTPHeaderField: key) == nil {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Set body for non-GET requests
        if method != "GET" {
            if let body = params["body"] as? [String: Any] {
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                } catch {
                    callback.error("INVALID_PARAMS", message: "Failed to serialize body: \(error.localizedDescription)")
                    return
                }
            } else if let bodyString = params["body"] as? String {
                request.httpBody = bodyString.data(using: .utf8)
            }
        }

        let task = session?.dataTask(with: request) { data, response, error in
            if let error = error {
                callback.error("NETWORK_ERROR", message: error.localizedDescription)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                callback.error("ERROR", message: "Invalid response")
                return
            }

            let statusCode = httpResponse.statusCode

            var result: [String: Any] = [
                "statusCode": statusCode,
                "headers": httpResponse.allHeaderFields as? [String: String] ?? [:]
            ]

            if let data = data {
                result["data"] = try? JSONSerialization.jsonObject(with: data)

                // Also include raw string
                if let str = String(data: data, encoding: .utf8) {
                    result["dataString"] = str
                }
            }

            if statusCode >= 200 && statusCode < 300 {
                callback.success(result)
            } else {
                callback.error("HTTP_ERROR", message: "HTTP \(statusCode)")
            }
        }

        task?.resume()
    }

    private func upload(params: [String: Any], callback: PluginCallback) {
        guard let urlString = optString(params, "url") else {
            callback.error("INVALID_PARAMS", message: "Missing url parameter")
            return
        }

        let url = baseURL.map { urlString.hasPrefix("http") ? urlString : $0 + urlString } ?? urlString
        guard let urlObj = URL(string: url) else {
            callback.error("INVALID_PARAMS", message: "Invalid URL: \(url)")
            return
        }

        guard let filePath = optString(params, "filePath") else {
            callback.error("INVALID_PARAMS", message: "Missing filePath parameter")
            return
        }

        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            callback.error("INVALID_PARAMS", message: "Failed to read file: \(filePath)")
            return
        }

        var request = URLRequest(url: urlObj)
        request.httpMethod = "POST"

        let fieldName = optString(params, "fieldName") ?? "file"
        let fileName = optString(params, "fileName") ?? (filePath as NSString).lastPathComponent
        let mimeType = optString(params, "mimeType") ?? "application/octet-stream"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let task = session?.dataTask(with: request) { data, response, error in
            if let error = error {
                callback.error("NETWORK_ERROR", message: error.localizedDescription)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                callback.error("ERROR", message: "Invalid response")
                return
            }

            let result: [String: Any] = [
                "statusCode": httpResponse.statusCode,
                "data": data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as Any
            ]

            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                callback.success(result)
            } else {
                callback.error("HTTP_ERROR", message: "HTTP \(httpResponse.statusCode)")
            }
        }

        task?.resume()
    }

    private func download(params: [String: Any], callback: PluginCallback) {
        guard let urlString = optString(params, "url") else {
            callback.error("INVALID_PARAMS", message: "Missing url parameter")
            return
        }

        let url = baseURL.map { urlString.hasPrefix("http") ? urlString : $0 + urlString } ?? urlString
        guard let urlObj = URL(string: url) else {
            callback.error("INVALID_PARAMS", message: "Invalid URL: \(url)")
            return
        }

        let request = URLRequest(url: urlObj)

        let task = self.session?.downloadTask(with: request) { tempURL, response, error in
            if let error = error {
                callback.error("NETWORK_ERROR", message: error.localizedDescription)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                callback.error("ERROR", message: "Invalid response")
                return
            }

            guard let tempURL = tempURL else {
                callback.error("ERROR", message: "Failed to download file")
                return
            }

            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let fileName = self.optString(params, "fileName") ?? (url as NSString).lastPathComponent
            let destPath = (documentsPath as NSString).appendingPathComponent(fileName)

            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: destPath) {
                    try fileManager.removeItem(atPath: destPath)
                }
                try fileManager.moveItem(atPath: tempURL.path, toPath: destPath)

                callback.success([
                    "statusCode": httpResponse.statusCode,
                    "path": destPath,
                    "fileName": fileName
                ])
            } catch {
                callback.error("ERROR", message: "Failed to save file: \(error.localizedDescription)")
            }
        }

        task?.resume()
    }
}
