/**
 * HTTP 全局配置
 * 启动时创建一次，传入 HttpClient
 * 不依赖任何 SDK
 */
export class HttpConfig {
  /** 服务器基础地址 */
  baseUrl: string = ''
  /** 公共请求头（所有请求都会带上，单次请求同名 header 覆盖） */
  headers: Record<string, string> = {}
  /** 连接超时（毫秒） */
  connectTimeout: number = 15000
  /** 读取超时（毫秒） */
  readTimeout: number = 30000
  /** 重试次数 */
  retryCount: number = 2
  /** 重试间隔（毫秒） */
  retryDelay: number = 1000
  /** 启用日志 */
  enableLog: boolean = false
  /** 日志中脱敏的 Header 字段 */
  sensitiveHeaders: string[] = ['Authorization', 'Cookie']
  /** 日志中脱敏的参数字段 */
  sensitiveParams: string[] = ['password', 'token', 'secret']
  /**
   * 出站域名白名单（SSRF 守卫）
   * 空 = 放行所有 host；非空 = host 需精确命中或为其子域名（host === d || host.endsWith('.' + d)）
   */
  allowedDomains: string[] = []
}
