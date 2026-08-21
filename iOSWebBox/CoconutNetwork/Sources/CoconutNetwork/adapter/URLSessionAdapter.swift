import Foundation

/// 基于 URLSession 的默认 Adapter 实现（纯 Foundation，零第三方依赖）。
///
/// 超时说明：URLRequest 只有单一 `timeoutInterval`（闲置计时器），无独立的
/// connect/read 概念 —— 这里取 readTimeout 赋值；connectTimeout 由 URLSession
/// 层 TCP 建连超时兜底（约 60s），与 Android HttpURLConnection 双超时存在文档
/// 记录的差异。
///
/// `init(session:)` 可注入测试 session（MockURLProtocol）。
public final class URLSessionAdapter: IHttpAdapter {

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: AdapterRequest) async throws -> AdapterResponse {
        guard let url = URL(string: request.url) else {
            throw URLError(.badURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        urlRequest.timeoutInterval = Double(max(request.readTimeout, 0)) / 1000.0

        let hasBody = !request.multiFormDataList.isEmpty || request.body != nil
        if hasBody && request.method != "GET" {
            let (payload, contentType) = Self.buildPayload(request)
            if request.headers["Content-Type"] == nil {
                urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
            urlRequest.httpBody = payload
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            guard let key = key as? String else { continue }
            let valueString = (value as? String) ?? String(describing: value)
            if let existing = headers[key] {
                headers[key] = existing + "," + valueString
            } else {
                headers[key] = valueString
            }
        }

        // bytes 模式：原始字节直通，不解析为 JSONValue
        if request.responseType == .bytes {
            return AdapterResponse(httpStatus: http.statusCode, headers: headers,
                                   body: nil, rawBody: data)
        }

        let contentTypeHeader = http.value(forHTTPHeaderField: "Content-Type") ?? ""
        let body = Self.parseBody(contentTypeHeader, data)
        return AdapterResponse(httpStatus: http.statusCode, headers: headers, body: body)
    }

    /// 构造请求负载：multipart 或 JSON body → (data, contentType)
    static func buildPayload(_ request: AdapterRequest) -> (Data, String) {
        if !request.multiFormDataList.isEmpty {
            let boundary = "coconut-\(UUID().uuidString)"
            let data = Self.buildMultipart(request.multiFormDataList, boundary: boundary)
            return (data, "multipart/form-data; boundary=\(boundary)")
        }
        let bodyData = request.body?.serialized() ?? Data()
        return (bodyData, request.contentType)
    }

    private static func buildMultipart(_ items: [FormDataItem], boundary: String) -> Data {
        var out = Data()
        func append(_ string: String) { out.append(Data(string.utf8)) }
        for item in items {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(item.name)\"; filename=\"\(item.remoteFileName ?? "file")\"\r\n")
            append("Content-Type: \(item.contentType)\r\n\r\n")
            out.append(item.data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        return out
    }

    /// JSON 响应解析为 JSONValue；非 JSON 包装为字符串基元（Adapter 契约）
    static func parseBody(_ contentType: String, _ data: Data) -> JSONValue? {
        let text = String(data: data, encoding: .utf8) ?? ""
        if contentType.lowercased().contains("json") {
            return JSONValue.parse(Data(text.utf8)) ?? .string(text)
        }
        return .string(text)
    }
}
