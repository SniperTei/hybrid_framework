/**
 * 出站 URL 守卫（SSRF 防护）
 *
 * 规则：
 * - scheme 必须是 http / https（coconut:// / file:// / resource:// / javascript: / 无 scheme 一律拒绝）
 * - allowedDomains 为空 = 放行所有 host
 * - allowedDomains 非空 = host 需精确命中某域名或为其子域名：
 *     host === d || host.endsWith('.' + d)
 *   注意后缀匹配带 '.' 分隔，"api.foo.com.evil.com" 不会命中 "foo.com"
 */

export class UrlGuardResult {
  allowed: boolean = false
  reason: string = ''
}

export class UrlGuard {
  private static readonly ALLOWED_SCHEMES: string[] = ['http', 'https']

  /**
   * 校验出站 URL
   * @param url 完整 URL（含 baseUrl 拼接后的）
   * @param allowedDomains 域名白名单（空 = 放行所有）
   */
  static validate(url: string, allowedDomains: string[]): UrlGuardResult {
    const result = new UrlGuardResult()

    const schemeSep = url.indexOf('://')
    if (schemeSep < 0) {
      result.reason = `missing or invalid scheme (http/https only): '${url}'`
      return result
    }

    const scheme = url.substring(0, schemeSep).toLowerCase()
    if (!UrlGuard.ALLOWED_SCHEMES.includes(scheme)) {
      result.reason = `scheme '${scheme}' is not allowed (http/https only)`
      return result
    }

    const host = UrlGuard.extractHost(url, schemeSep + 3)
    if (host.length === 0) {
      result.reason = 'empty host'
      return result
    }

    if (allowedDomains.length === 0) {
      result.allowed = true
      return result
    }

    for (const domain of allowedDomains) {
      const d = domain.trim().toLowerCase()
      if (d.length === 0) {
        continue
      }
      if (host === d || host.endsWith('.' + d)) {
        result.allowed = true
        return result
      }
    }

    result.reason = `host '${host}' is not in allowedDomains`
    return result
  }

  /** 从 '://' 之后提取 host（到第一个 '/', '?', '#', ':' 为止） */
  private static extractHost(url: string, hostStart: number): string {
    let end = url.length
    const stopChars = ['/', '?', '#', ':']
    for (const ch of stopChars) {
      const idx = url.indexOf(ch, hostStart)
      if (idx >= 0 && idx < end) {
        end = idx
      }
    }
    return url.substring(hostStart, end).toLowerCase()
  }
}
