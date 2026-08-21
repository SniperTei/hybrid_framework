import { HttpConfig } from './HttpConfig'
import { HttpRequest, RequestOptions, HttpClientContext, HttpMethod } from './HttpRequest'
import { HttpResponse } from './HttpResponse'
import { Call } from './Call'
import { RequestInterceptor } from './interceptors/RequestInterceptor'
import { IHttpAdapter } from './adapter/IHttpAdapter'
import { HarmonyHttpAdapter } from './adapter/HarmonyHttpAdapter'

/**
 * HTTP 客户端 — Call 的工厂
 * 持有全局配置、适配器、拦截器
 */
export class HttpClient implements HttpClientContext {
  /** 全局默认 Adapter，启动时设置一次即可 */
  private static defaultAdapter: IHttpAdapter | null = null

  /** 设置全局默认 Adapter（不设则用 HarmonyHttpAdapter） */
  static setDefaultAdapter(adapter: IHttpAdapter): void {
    HttpClient.defaultAdapter = adapter
  }

  private config: HttpConfig
  private adapter: IHttpAdapter
  private interceptors: RequestInterceptor[] = []

  constructor(config: HttpConfig, adapter?: IHttpAdapter) {
    this.config = config
    this.adapter = adapter ?? HttpClient.defaultAdapter ?? new HarmonyHttpAdapter()
  }

  /** 创建请求（绑定了 this 的 config + adapter + interceptors） */
  newRequest(url: string, options?: RequestOptions): HttpRequest {
    return new HttpRequest(url, options, this)
  }

  /** 添加拦截器 */
  addInterceptor(interceptor: RequestInterceptor): void {
    this.interceptors.push(interceptor)
  }

  /** 获取全局配置 */
  getConfig(): HttpConfig {
    return this.config
  }

  /** 获取适配器 */
  getAdapter(): IHttpAdapter {
    return this.adapter
  }

  /** 获取拦截器列表 */
  getInterceptors(): RequestInterceptor[] {
    return this.interceptors
  }

  /**
   * 向后兼容：直接执行请求
   * 内部创建 Call 并 execute
   */
  async execute<T extends Object = Object>(request: HttpRequest): Promise<HttpResponse<T>> {
    // 如果 request 没有 context，临时绑定
    const call = new Call(request, this.config, this.adapter, this.interceptors)
    return call.execute<T>()
  }

  // ============ 一发式便利 API（native 消费者主入口）============
  // 内部统一走 newRequest().buildCall().execute()，拦截器/UrlGuard/重试/header 合并全链路生效

  /** 一发式请求（method 由 options 指定，缺省 GET） */
  async request<T extends Object = Object>(url: string, options?: RequestOptions): Promise<HttpResponse<T>> {
    const method = options?.method ?? HttpMethod.GET
    const merged = this.mergeOptions(options ?? null, method, null)
    return this.newRequest(url, merged).buildCall().execute<T>()
  }

  /** 一发式 GET */
  async get<T extends Object = Object>(url: string, options?: RequestOptions): Promise<HttpResponse<T>> {
    const merged = this.mergeOptions(options ?? null, HttpMethod.GET, null)
    return this.newRequest(url, merged).buildCall().execute<T>()
  }

  /** 一发式 POST（显式 body 参数优先于 options.body） */
  async post<T extends Object = Object>(url: string, body?: Object,
    options?: RequestOptions): Promise<HttpResponse<T>> {
    const merged = this.mergeOptions(options ?? null, HttpMethod.POST, body ?? null)
    return this.newRequest(url, merged).buildCall().execute<T>()
  }

  /** 一发式 PUT（显式 body 参数优先于 options.body） */
  async put<T extends Object = Object>(url: string, body?: Object,
    options?: RequestOptions): Promise<HttpResponse<T>> {
    const merged = this.mergeOptions(options ?? null, HttpMethod.PUT, body ?? null)
    return this.newRequest(url, merged).buildCall().execute<T>()
  }

  /** 一发式 DELETE */
  async delete<T extends Object = Object>(url: string, options?: RequestOptions): Promise<HttpResponse<T>> {
    const merged = this.mergeOptions(options ?? null, HttpMethod.DELETE, null)
    return this.newRequest(url, merged).buildCall().execute<T>()
  }

  /**
   * 合并 options 并覆写 method/body（ArkTS 禁 object spread，逐字段拷贝）
   * 5 个一发式 helper 共用，防漏字段
   */
  private mergeOptions(options: RequestOptions | null, method: HttpMethod,
    body: Object | null): RequestOptions {
    const merged: RequestOptions = {}
    if (options !== null) {
      if (options.method !== undefined) {
        merged.method = options.method
      }
      if (options.headers !== undefined) {
        merged.headers = options.headers
      }
      if (options.params !== undefined) {
        merged.params = options.params
      }
      if (options.body !== undefined) {
        merged.body = options.body
      }
      if (options.tag !== undefined) {
        merged.tag = options.tag
      }
      if (options.connectTimeout !== undefined) {
        merged.connectTimeout = options.connectTimeout
      }
      if (options.readTimeout !== undefined) {
        merged.readTimeout = options.readTimeout
      }
      if (options.multiFormDataList !== undefined) {
        merged.multiFormDataList = options.multiFormDataList
      }
      if (options.responseType !== undefined) {
        merged.responseType = options.responseType
      }
    }
    merged.method = method
    if (body !== null) {
      merged.body = body
    }
    return merged
  }
}
