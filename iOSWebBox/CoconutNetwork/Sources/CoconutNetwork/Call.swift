import Foundation

/// Call — HTTP 请求执行器。持有一次请求的全部上下文
/// （request + config + adapter + interceptors）。
///
/// 执行顺序（照抄 Android Call.kt，三端一致）：
///   1. mock 短路检查（构造时手动 enableMocking 的）
///   2. 请求拦截器链（正序）
///   3. mock 短路检查（拦截器打标的，如 MockInterceptor）
///   4. 拼接完整 URL
///   5. UrlGuard 出站校验（mock 已在前面短路，不出网不受守卫约束）
///   6. adapter 派发（带重试）
///   7. 响应拦截器链（逆序）
///
/// 公开 API 永不 throw：错误一律落 `HttpResponse.error`（对齐 Kotlin）。
struct Call: Sendable {

    let request: HttpRequest
    let config: HttpConfig
    let adapter: IHttpAdapter
    let interceptors: [RequestInterceptor]

    /// 执行请求
    func execute() async -> HttpResponse {
        let startTime = Self.nowMs()

        var currentRequest = request

        // Mock 短路（构造时手动设置）
        if currentRequest.enableMock, let mock = currentRequest.mockResponse {
            return await shortCircuitMock(mock, startTime: startTime)
        }

        // 执行请求拦截器链（正序）
        for interceptor in interceptors {
            currentRequest = await interceptor.onRequest(currentRequest)
        }

        // 再次 mock 短路（拦截器可能打标，如 MockInterceptor）
        if currentRequest.enableMock, let mock = currentRequest.mockResponse {
            return await shortCircuitMock(mock, startTime: startTime)
        }

        // 拼接完整 URL
        let fullUrl = Self.buildFullUrl(currentRequest, config: config)

        // 获取超时/重试配置
        let connectTimeout = currentRequest.connectTimeout > 0 ? currentRequest.connectTimeout : config.connectTimeout
        let readTimeout = currentRequest.readTimeout > 0 ? currentRequest.readTimeout : config.readTimeout
        let retryCount = currentRequest.retryCount >= 0 ? currentRequest.retryCount : config.retryCount

        // 合并公共 headers：config 公共 < request 单次（单次优先）
        var mergedHeaders = config.headers
        for (k, v) in currentRequest.headers { mergedHeaders[k] = v }

        // 构建 AdapterRequest
        let adapterRequest = AdapterRequest(
            method: currentRequest.method.rawValue,
            url: fullUrl,
            headers: mergedHeaders,
            body: currentRequest.body,
            contentType: currentRequest.contentType,
            connectTimeout: connectTimeout,
            readTimeout: readTimeout,
            multiFormDataList: currentRequest.multiFormDataList,
            responseType: currentRequest.responseType
        )

        var response: HttpResponse

        // 出站守卫（scheme 白名单 + allowedDomains 后缀匹配）
        let guardResult = UrlGuard.validate(fullUrl, allowedDomains: config.allowedDomains)
        if !guardResult.allowed {
            NetworkLog.w("HttpClient", "Blocked by UrlGuard: \(fullUrl) (\(guardResult.reason))")
            response = HttpResponse.error(
                code: "\(HttpErrorCode.urlBlocked.rawValue)",
                httpStatus: 0,
                msg: "请求被出站守卫拦截: \(guardResult.reason)"
            )
        } else {
            // 带重试的请求
            response = await executeWithRetry(retryCount: retryCount, adapterRequest: adapterRequest,
                                              responseType: currentRequest.responseType)
        }

        response.costTime = Self.nowMs() - startTime

        // 执行响应拦截器链（逆序）
        var baseResponse = response
        for interceptor in interceptors.reversed() {
            baseResponse = await interceptor.onResponse(baseResponse)
        }

        return baseResponse
    }

    /// 带重试的 adapter 派发：全部失败后映射为网络/超时/SSL 错误
    private func executeWithRetry(retryCount: Int, adapterRequest: AdapterRequest,
                                  responseType: HttpResponseType) async -> HttpResponse {
        var lastError: Error?
        let attempts = max(retryCount, 0)
        for attempt in 0...attempts {
            do {
                return parseResponse(try await adapter.send(adapterRequest), responseType: responseType)
            } catch {
                lastError = error
                if attempt < attempts {
                    try? await Task.sleep(nanoseconds: UInt64(max(config.retryDelay, 0)) * 1_000_000)
                }
            }
        }
        return Self.handleError(lastError ?? NSError(domain: "CoconutNetwork", code: -1,
                                                     userInfo: [NSLocalizedDescriptionKey: "unknown error"]))
    }

    /// Mock 短路：mockResponse 按 MockPayload 形态构造
    private func shortCircuitMock(_ mock: MockPayload, startTime: Int64) async -> HttpResponse {
        var httpStatus = 200
        var code = API_SUCCESS_CODE
        var msg = "mock"
        var data: JSONValue?
        var delayMs: Int64 = 0

        switch mock {
        case .result(let result):
            httpStatus = result.httpStatus
            code = result.code
            msg = result.msg
            data = result.data
            delayMs = result.delayMs
        case .data(let value):
            data = value
        }

        if delayMs > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
        }

        var resp = HttpResponse()
        resp.httpStatus = httpStatus
        resp.statusCode = httpStatus
        resp.code = code
        resp.msg = msg
        resp.data = data
        resp.costTime = Self.nowMs() - startTime
        return resp
    }

    /// 拼接完整 URL（与 Android/ArkTS 对齐：空格编码为 %20 而非 form 的 +，
    /// `&=?#` 等保留字必须编码，自定义 CharacterSet 钉死行为）
    static func buildFullUrl(_ request: HttpRequest, config: HttpConfig) -> String {
        var url = config.baseUrl + request.url
        if !request.params.isEmpty {
            let parts = request.params.map { "\(enc($0.key))=\(enc($0.value))" }
                .sorted { $0 < $1 } // 稳定输出（Dictionary 无序）
            url += (url.contains("?") ? "&" : "?") + parts.joined(separator: "&")
        }
        return url
    }

    private static let queryAllowed: CharacterSet =
        CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-*_"))

    private static func enc(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? s
    }

    /// 解析 AdapterResponse → HttpResponse
    func parseResponse(_ adapterResp: AdapterResponse, responseType: HttpResponseType) -> HttpResponse {
        let httpStatus = adapterResp.httpStatus

        // HTTP 错误
        if httpStatus >= 400 {
            return HttpResponse.error(code: "\(httpStatus)", httpStatus: httpStatus,
                                      msg: Self.httpErrorMessage(httpStatus))
        }

        // bytes 模式：原始字节直通，不做 envelope 嗅探（内容恰为 envelope 形状也直通）
        if responseType == .bytes {
            var resp = HttpResponse.success(httpStatus: httpStatus, data: nil)
            resp.headers = adapterResp.headers
            resp.rawData = adapterResp.rawBody
            return resp
        }

        // 解析业务响应：body 是 object 且含 "code" 字段才视为 envelope
        // { code, statusCode, msg, data, timestamp }，否则按非 envelope 直通
        // （如 manifest.json 等 2xx JSON body，补默认成功码）
        if case .object(let body)? = adapterResp.body, body["code"] != nil {
            let code = body["code"]?.primitiveStringValue ?? ""
            let statusCode = body["statusCode"]?.primitiveStringValue.flatMap(Int.init) ?? httpStatus
            let msg = body["msg"]?.primitiveStringValue ?? ""
            let data = body["data"].flatMap(Self.unwrapNull)
            let timestamp = body["timestamp"]?.primitiveStringValue ?? ""

            var resp = HttpResponse.success(httpStatus: httpStatus, data: data, msg: msg)
            resp.code = code
            resp.statusCode = statusCode
            resp.timestamp = timestamp
            resp.headers = adapterResp.headers
            return resp
        }

        // 非 envelope 响应：body 直通，补默认成功码
        var resp = HttpResponse.success(httpStatus: httpStatus,
                                        data: adapterResp.body.flatMap(Self.unwrapNull))
        resp.headers = adapterResp.headers
        return resp
    }

    /// null 视为无值（对齐 ArkTS 侧 `?? null` 语义）
    static func unwrapNull(_ value: JSONValue?) -> JSONValue? {
        guard case .some(.null) = value else { return value }
        return nil
    }

    /// 处理请求异常：URLError code 优先，localizedDescription 小写匹配兜底
    static func handleError(_ error: Error) -> HttpResponse {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return HttpResponse.error(code: "\(HttpErrorCode.timeoutError.rawValue)", httpStatus: 0,
                                          msg: "请求超时: \(urlError.localizedDescription)")
            case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid, .clientCertificateRejected, .clientCertificateRequired,
                 .secureConnectionFailed:
                return HttpResponse.error(code: "\(HttpErrorCode.sslError.rawValue)", httpStatus: 0,
                                          msg: "SSL错误: \(urlError.localizedDescription)")
            default:
                return HttpResponse.error(code: "\(HttpErrorCode.networkError.rawValue)", httpStatus: 0,
                                          msg: "网络错误: \(urlError.localizedDescription)")
            }
        }

        let msg = (error as? LocalizedError)?.errorDescription
            ?? ((error as NSError).userInfo[NSLocalizedDescriptionKey] as? String)
            ?? String(describing: error)
        let lower = msg.lowercased()
        if lower.contains("timeout") || lower.contains("timed out") {
            return HttpResponse.error(code: "\(HttpErrorCode.timeoutError.rawValue)", httpStatus: 0,
                                      msg: "请求超时: \(msg)")
        }
        if lower.contains("ssl") || lower.contains("certificate") {
            return HttpResponse.error(code: "\(HttpErrorCode.sslError.rawValue)", httpStatus: 0,
                                      msg: "SSL错误: \(msg)")
        }
        return HttpResponse.error(code: "\(HttpErrorCode.networkError.rawValue)", httpStatus: 0,
                                  msg: "网络错误: \(msg)")
    }

    /// HTTP 错误信息表（中文，三端一致）
    static func httpErrorMessage(_ status: Int) -> String {
        switch status {
        case 400: return "请求参数错误"
        case 401: return "未授权"
        case 403: return "禁止访问"
        case 404: return "资源不存在"
        case 405: return "请求方法不允许"
        case 500: return "服务器内部错误"
        case 502: return "网关错误"
        case 503: return "服务不可用"
        default: return "HTTP错误 \(status)"
        }
    }

    private static func nowMs() -> Int64 {
        Int64(DispatchTime.now().uptimeNanoseconds / 1_000_000)
    }
}
