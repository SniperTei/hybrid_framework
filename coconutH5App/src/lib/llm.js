// LLM 工具客户端（bridge network 引擎 → mock / 未来真实 OpenAI 兼容服务）
//
// ⚠️ 原生 network 组件不支持真流式（API_CONTRACT §4.5：响应统一按 JSON 解析，
// 流式进度下轮）——打字机效果为 H5 端模拟（revealText）。接口按 OpenAI
// chat/completions 非流式契约预留，原生支持流式后可平滑切换。
import { pcall } from './pcall'

export const LLM_BASE_KEY = 'h5app.llm_base'
export const DEFAULT_LLM_BASE = 'http://127.0.0.1:8043'

export function llmPlaceholder() {
  const env = window.coconut?.environment
  if (env === 'ios') return 'iOS sim：localhost 即 Mac（mock: serve-ai-mock.sh）'
  if (env === 'android') return 'Android：10.0.2.2:8043 或 adb reverse'
  if (env === 'harmony') return 'Harmony：需先 hdc rport tcp:8043'
  return 'LLM API base URL（mock 默认 127.0.0.1:8043）'
}

export async function resolveLlmBase() {
  const q = new URLSearchParams(location.search).get('llmBase')
  if (q) return q
  const r = await pcall('storage', 'getItem', { key: LLM_BASE_KEY })
  if (!r.err && r.data && r.data.value) return r.data.value
  return DEFAULT_LLM_BASE
}

export async function saveLlmBase(v) {
  await pcall('storage', 'setItem', { key: LLM_BASE_KEY, value: v })
}

// OpenAI 兼容非流式：{model, messages} → {ok, content}
export async function chatComplete(base, { model, messages }) {
  const r = await pcall('network', 'request', {
    url: `${base.replace(/\/$/, '')}/v1/chat/completions`,
    method: 'POST',
    body: { model, messages, stream: false },
    timeoutMs: 30000,
  })
  if (r.err) return { ok: false, message: `${r.err.code} ${r.err.message}` }
  const d = r.data || {}
  if (d.success !== true) {
    return { ok: false, message: d.msg || d.message || `HTTP ${d.httpStatus}` }
  }
  const content = d.data?.choices?.[0]?.message?.content
  if (typeof content !== 'string') return { ok: false, message: '响应缺少 choices[0].message.content' }
  return { ok: true, content }
}

// 识图（自定义契约，mock 实现；预留真实服务对接）
export async function analyzeImage(base, imageUrl) {
  const r = await pcall('network', 'request', {
    url: `${base.replace(/\/$/, '')}/v1/images/analyses`,
    method: 'POST',
    body: { image_url: imageUrl, model: 'mock-yolo' },
    timeoutMs: 30000,
  })
  if (r.err) return { ok: false, message: `${r.err.code} ${r.err.message}` }
  const d = r.data || {}
  if (d.success !== true) {
    return { ok: false, message: d.msg || d.message || `HTTP ${d.httpStatus}` }
  }
  const detections = d.data?.detections
  if (!Array.isArray(detections)) return { ok: false, message: '响应缺少 detections 数组' }
  return { ok: true, detections }
}

// H5 端打字机：把完整文本按 chunk 渐显，onProgress 收到部分文本
// 返回 cancel 函数（重新生成时打断上一轮）
export function revealText(text, onProgress, { chunk = 2, interval = 30 } = {}) {
  let i = 0
  let cancelled = false
  const timer = setInterval(() => {
    if (cancelled) return
    i = Math.min(text.length, i + chunk)
    onProgress(text.slice(0, i))
    if (i >= text.length) clearInterval(timer)
  }, interval)
  return () => { cancelled = true; clearInterval(timer) }
}
