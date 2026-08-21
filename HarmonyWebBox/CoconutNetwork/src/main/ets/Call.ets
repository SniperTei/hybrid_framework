/**
 * Call — HTTP 请求执行器
 * 持有一次请求的全部上下文（request + config + adapter + interceptors）
 *
 * 执行顺序：
 *   1. mock 短路检查（构造时手动 enableMocking 的）
 *   2. 请求拦截器链（正序）
 *   3. mock 短路检查（拦截器打标的，如 MockInterceptor）
 *   4. 拼接完整 URL
 *   5. UrlGuard 出站校验（mock 已在前面短路，不出网不受守卫约束）
 *   6. adapter 派发（带重试）
 *   7. 响应拦截器链（逆序）
 */

import { HttpConfig } from './HttpConfig'
import { HttpRequest } from './HttpRequest'
import { HttpResponse } from './HttpResponse'
import { HttpErrorCode } from './HttpError'
import { IHttpAdapter, AdapterRequest, AdapterResponse, HttpResponseType } from './adapter/IHttpAdapter'
import { RequestInterceptor } from './interceptors/RequestInterceptor'
import { MockResult } from './interceptors/MockInterceptor'
import { UrlGuard } from './guard/UrlGuard'
import { Logger } from './utils/Logger'

const TAG = 'HttpClient'

export class Call {
  private request: HttpRequest
  private config: HttpConfig
  private adapter: IHttpAdapter
  private interceptors: RequestInterceptor[]

  constructor(request: HttpRequest, config: HttpConfig, adapter: IHttpAdapter,
    interceptors: RequestInterceptor[]) {
    this.request = request
    this.config = config
    this.adapter = adapter
    this.interceptors = interceptors
  }

  /** 执行请求，返回泛型响应 */
  async execute<T extends Object = Object>(): Promise<HttpResponse<T>> {
    const startTime = Date.now()

    let currentRequest = this.request

    // Mock 短路（构造时手动设置）
    if (currentRequest.enableMock && currentRequest.mockResponse) {
      return this.shortCircuitMock<T>(currentRequest.mockResponse, startTime)
    }

    // 执行请求拦截器链（正序）
    for (const interceptor of this.interceptors) {
      currentRequest = await interceptor.onRequest(currentRequest)
    }

    // 再次 mock 短路（拦截器可能打标，如 MockInterceptor）
    if (currentRequest.enableMock && currentRequest.mockResponse) {
      return this.shortCircuitMock<T>(currentRequest.mockResponse, startTime)
    }

    // 拼接完整 URL
    const fullUrl = this.buildFullUrl(currentRequest)

    // 获取超时/重试配置
    const connectTimeout = currentRequest.connectTimeout > 0 ?
      currentRequest.connectTimeout : this.config.connectTimeout
    const readTimeout = currentRequest.readTimeout > 0 ?
      currentRequest.readTimeout : this.config.readTimeout
    const retryCount = currentRequest.retryCount >= 0 ?
      currentRequest.retryCount : this.config.retryCount

    // 合并公共 headers：config 公共 < request 单次（单次优先）
    const mergedHeaders: Record<string, string> = {}
    const configHeaderKeys = Object.keys(this.config.headers)
    for (const key of configHeaderKeys) {
      mergedHeaders[key] = this.config.headers[key]
    }
    const reqHeaderKeys = Object.keys(currentRequest.headers)
    for (const key of reqHeaderKeys) {
      mergedHeaders[key] = currentRequest.headers[key]
    }

    // 构建 AdapterRequest
    const adapterRequest: AdapterRequest = {
      method: currentRequest.method,
      url: fullUrl,
      headers: mergedHeaders,
      body: currentRequest.body,
      contentType: currentRequest.contentType,
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
      multiFormDataList: currentRequest.multiFormDataList,
      responseType: currentRequest.responseType,
    }

    let response: HttpResponse<T> | null = null

    // 出站守卫（scheme 白名单 + allowedDomains 后缀匹配）
    const guardResult = UrlGuard.validate(fullUrl, this.config.allowedDomains)
    if (!guardResult.allowed) {
      Logger.w(TAG, `Blocked by UrlGuard: ${fullUrl} (${guardResult.reason})`)
      response = HttpResponse.error<T>(String(HttpErrorCode.URL_BLOCKED), 0,
        `请求被出站守卫拦截: ${guardResult.reason}`)
    } else {
      // 带重试的请求
      let lastError: Error | null = null
      for (let attempt = 0; attempt <= retryCount; attempt++) {
        try {
          const adapterResp = await this.adapter.sendRequest(adapterRequest)
          response = this.parseResponse<T>(adapterResp, currentRequest.responseType)
          break
        } catch (err) {
          lastError = err as Error
          if (attempt < retryCount) {
            await this.delay(this.config.retryDelay)
          }
        }
      }

      if (!response) {
        response = this.handleError<T>(lastError!)
      }
    }

    response.costTime = Date.now() - startTime

    // 执行响应拦截器链（逆序）
    let baseResponse: HttpResponse = response as HttpResponse
    for (let i = this.interceptors.length - 1; i >= 0; i--) {
      baseResponse = await this.interceptors[i].onResponse(baseResponse)
    }
    response = baseResponse as HttpResponse<T>

    return response
  }

  /** Mock 短路：mockResponse 是 MockResult 则按其字段构造，否则视为纯业务数据 */
  private async shortCircuitMock<T extends Object>(mock: Object,
    startTime: number): Promise<HttpResponse<T>> {
    let httpStatus = 200
    let code = '000000'
    let msg = 'mock'
    let data: Object | null = mock
    let delayMs = 0

    if (mock instanceof MockResult) {
      const result = mock as MockResult
      httpStatus = result.httpStatus
      code = result.code
      msg = result.msg
      data = result.data
      delayMs = result.delayMs
    }

    if (delayMs > 0) {
      await this.delay(delayMs)
    }

    const resp = new HttpResponse<T>()
    resp.httpStatus = httpStatus
    resp.statusCode = httpStatus
    resp.code = code
    resp.msg = msg
    resp.data = data as T
    resp.costTime = Date.now() - startTime
    return resp
  }

  /** 拼接完整 URL */
  private buildFullUrl(request: HttpRequest): string {
    let url = this.config.baseUrl + request.url
    const paramKeys = Object.keys(request.params)
    if (paramKeys.length > 0) {
      const parts: string[] = []
      for (const key of paramKeys) {
        parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(request.params[key])}`)
      }
      url += (url.includes('?') ? '&' : '?') + parts.join('&')
    }
    return url
  }

  /** 解析 AdapterResponse → HttpResponse<T> */
  private parseResponse<T extends Object>(adapterResp: AdapterResponse,
    responseType: HttpResponseType): HttpResponse<T> {
    const httpStatus = adapterResp.httpStatus

    // HTTP 错误
    if (httpStatus >= 400) {
      return HttpResponse.error(String(httpStatus), httpStatus, this.getHttpErrorMessage(httpStatus))
    }

    // bytes 模式：原始字节透传，不做 envelope 嗅探（内容恰为 JSON 也不进 envelope）
    if (responseType === HttpResponseType.BYTES) {
      const bytesResp = HttpResponse.success<T>(httpStatus, null)
      bytesResp.headers = adapterResp.headers
      bytesResp.rawData = adapterResp.rawBody ?? null
      return bytesResp
    }

    // 解析业务响应：有 "code" 字段才视为 envelope { code, statusCode, msg, data, timestamp }，
    // 否则按非 envelope 直通（如 manifest.json 等 2xx JSON body，补默认成功码）
    const responseBody = adapterResp.body as Record<string, Object> | null
    if (responseBody && typeof responseBody === 'object' && responseBody['code'] !== undefined) {
      const code = (responseBody['code'] as string) ?? ''
      const statusCode = (responseBody['statusCode'] as number) ?? httpStatus
      const msg = (responseBody['msg'] as string) ?? ''
      const data = (responseBody['data'] as T) ?? null
      const timestamp = (responseBody['timestamp'] as string) ?? ''

      const resp = HttpResponse.success<T>(httpStatus, data, msg)
      resp.code = code
      resp.statusCode = statusCode
      resp.timestamp = timestamp
      resp.headers = adapterResp.headers
      return resp
    }

    // 非 envelope 响应：body 直通，补默认成功码
    const resp = HttpResponse.success<T>(httpStatus, adapterResp.body as T)
    resp.headers = adapterResp.headers
    return resp
  }

  /** 处理请求异常 */
  private handleError<T extends Object>(error: Error): HttpResponse<T> {
    const msg = error.message ?? 'Unknown error'
    if (msg.includes('timeout') || msg.includes('Timeout')) {
      return HttpResponse.error(String(HttpErrorCode.TIMEOUT_ERROR), 0, `请求超时: ${msg}`)
    }
    if (msg.includes('SSL') || msg.includes('certificate')) {
      return HttpResponse.error(String(HttpErrorCode.SSL_ERROR), 0, `SSL错误: ${msg}`)
    }
    return HttpResponse.error(String(HttpErrorCode.NETWORK_ERROR), 0, `网络错误: ${msg}`)
  }

  /** 获取 HTTP 错误信息 */
  private getHttpErrorMessage(status: number): string {
    const messages: Record<number, string> = {
      400: '请求参数错误',
      401: '未授权',
      403: '禁止访问',
      404: '资源不存在',
      405: '请求方法不允许',
      500: '服务器内部错误',
      502: '网关错误',
      503: '服务不可用',
    }
    return messages[status] ?? `HTTP错误 ${status}`
  }

  /** 延迟 */
  private delay(ms: number): Promise<void> {
    return new Promise<void>(resolve => setTimeout(resolve, ms))
  }
}
