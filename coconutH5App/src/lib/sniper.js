// Sniper YOLO API 客户端（bridge network 引擎全链路）
//
// 契约（对齐 AndroidWebBox SniperYoloAPIActivity.kt）：
//   POST {base}/users/test-login            → data.access_token
//   GET  {base}/foods/?count=N   (Bearer)  → data: foods 数组
//   GET  {base}/foods/{id}       (Bearer)  → data: 单条（404 → 业务失败 envelope）
// envelope（bridge network.request 返回）：{success, httpStatus, code, msg, data, costTime}
import { pcall } from './pcall'

export const SNIPER_BASE_KEY = 'h5app.api_base'
// 各端默认地址语义（真实 base 用配置覆盖）：
//   iOS sim : localhost 即 Mac
//   Android : 10.0.2.2 是宿主 loopback（或 adb reverse）
//   Harmony : 127.0.0.1 需先 hdc rport tcp:<port> tcp:<port>
export const DEFAULT_SNIPER_BASE = 'http://127.0.0.1:8041'

export function sniperPlaceholder() {
  const env = window.coconut?.environment
  if (env === 'ios') return 'iOS sim：localhost 即 Mac'
  if (env === 'android') return 'Android 模拟器：10.0.2.2 或 adb reverse'
  if (env === 'harmony') return 'Harmony：127.0.0.1 需先 hdc rport'
  return 'Sniper API base URL'
}

// 优先级：URL query（e2e 注入缝）> storage 落盘 > 默认
export async function resolveSniperBase() {
  const q = new URLSearchParams(location.search).get('apiBase')
  if (q) return q
  const r = await pcall('storage', 'getItem', { key: SNIPER_BASE_KEY })
  if (!r.err && r.data && r.data.value) return r.data.value
  return DEFAULT_SNIPER_BASE
}

export async function saveSniperBase(v) {
  await pcall('storage', 'setItem', { key: SNIPER_BASE_KEY, value: v })
}

// ---- 模块级登录态（token 内存态；forward 出去的详情页是新 WebView 实例，
//      不共享本模块状态，需自行 login）----
let token = null
export function resetToken() { token = null }

async function rawRequest(base, method, path, { params, body, auth } = {}) {
  const r = await pcall('network', 'request', {
    url: `${base.replace(/\/$/, '')}${path}`,
    method,
    params: params || undefined,
    body: body || undefined,
    headers: auth && token ? { Authorization: `Bearer ${token}` } : undefined,
    timeoutMs: 15000,
  })
  if (r.err) return { ok: false, transport: true, message: `${r.err.code} ${r.err.message}` }
  const d = r.data || {}
  return {
    ok: d.success === true,
    httpStatus: d.httpStatus,
    message: d.msg || d.message,
    data: d.data,
  }
}

export async function login(base) {
  const r = await rawRequest(base, 'POST', '/users/test-login', { method: 'POST' })
  if (r.ok && r.data && r.data.access_token) {
    token = r.data.access_token
    return { ok: true }
  }
  return { ok: false, message: r.message || '未取到 access_token' }
}

// 列表：未登录/401 自动 (re)login 一次再试
export async function getFoods(base, count = 20) {
  if (!token) {
    const l = await login(base)
    if (!l.ok) return l
  }
  let r = await rawRequest(base, 'GET', '/foods/', { params: { count: String(count) }, auth: true })
  if (!r.ok && (r.httpStatus === 401 || r.httpStatus === 403)) {
    const l = await login(base)
    if (!l.ok) return l
    r = await rawRequest(base, 'GET', '/foods/', { params: { count: String(count) }, auth: true })
  }
  if (r.ok) return { ok: true, data: Array.isArray(r.data) ? r.data : (r.data?.items || []) }
  return r
}

export async function getFood(base, id) {
  if (!token) {
    const l = await login(base)
    if (!l.ok) return l
  }
  return rawRequest(base, 'GET', `/foods/${id}`, { auth: true })
}
