import { RequestInterceptor } from './RequestInterceptor'
import { HttpRequest, HttpMethod } from '../HttpRequest'
import { HttpResponse } from '../HttpResponse'
import { Logger } from '../utils/Logger'

const TAG = 'MockInterceptor'

/**
 * Mock 规则
 * url 精确匹配；以 '*' 结尾 = 前缀匹配（显式声明，避免误命中）
 */
export interface MockRule {
  /** 匹配的 URL（相对或绝对均可，与 request.url 按字符串比对）；以 '*' 结尾 = 前缀匹配 */
  url: string
  /** 匹配的 HTTP 方法；不填 = 任意方法 */
  method?: HttpMethod
  /** mock 的 HTTP 状态码，默认 200 */
  httpStatus?: number
  /** mock 的业务码，默认 '000000' */
  code?: string
  /** mock 的消息 */
  msg?: string
  /** mock 的数据 */
  data?: Object
  /** 模拟耗时（毫秒），用于测试慢网络 */
  delayMs?: number
}

/**
 * Mock 结果载体（拦截器命中后挂到 request.mockResponse，由 Call 短路消费）
 */
export class MockResult {
  httpStatus: number = 200
  code: string = '000000'
  msg: string = 'mock'
  data: Object | null = null
  delayMs: number = 0
}

/**
 * Mock 拦截器
 * 开发调试用：命中规则时给 request 打 mock 标记，Call.execute 看到标记直接短路，不进 adapter
 *
 * 用法：
 *   const mock = new MockInterceptor()
 *   mock.addRule({ url: '/api/user', method: HttpMethod.GET, data: { name: 'test' } })
 *   mock.addRule({ url: '/api/login*', httpStatus: 500, code: '500000', msg: 'mock fail' })
 *   client.addInterceptor(mock)
 *
 * 注意：mock 短路发生在 UrlGuard 之前（mock 请求不出网），且生产包不建议注册。
 */
export class MockInterceptor implements RequestInterceptor {
  private rules: MockRule[] = []

  /** 注册 Mock 规则（链式） */
  addRule(rule: MockRule): MockInterceptor {
    this.rules.push(rule)
    return this
  }

  /** 清除所有 Mock 规则 */
  clearAll(): void {
    this.rules = []
  }

  async onRequest(request: HttpRequest): Promise<HttpRequest> {
    const rule = this.match(request)
    if (rule === null) {
      return request
    }

    Logger.i(TAG, `Mock hit: ${rule.method ?? '*'} ${rule.url}`)

    const result = new MockResult()
    result.httpStatus = rule.httpStatus ?? 200
    result.code = rule.code ?? '000000'
    result.msg = rule.msg ?? 'mock'
    result.data = rule.data ?? null
    result.delayMs = rule.delayMs ?? 0

    request.enableMock = true
    request.mockResponse = result
    return request
  }

  async onResponse(response: HttpResponse): Promise<HttpResponse> {
    return response
  }

  /** 匹配规则：URL 精确 / '*' 前缀 + 方法校验（不填 = 任意） */
  private match(request: HttpRequest): MockRule | null {
    const methodStr = request.method.toString().toUpperCase()
    for (const rule of this.rules) {
      if (rule.method !== undefined && rule.method.toString().toUpperCase() !== methodStr) {
        continue
      }
      const pattern = rule.url
      if (pattern.endsWith('*')) {
        if (request.url.startsWith(pattern.substring(0, pattern.length - 1))) {
          return rule
        }
      } else if (request.url === pattern) {
        return rule
      }
    }
    return null
  }
}
