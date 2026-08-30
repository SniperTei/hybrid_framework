#!/usr/bin/env node
//
// ai-mock-server.mjs — coconutH5App AI 工具 mock 服务（node 零依赖）
//
// 端点：
//   POST /v1/chat/completions   OpenAI 兼容非流式。model=translator|summarizer
//                               决定 mock 行为（其他 model 走 translator 分支）
//   POST /v1/images/analyses    识图（自定义契约）：{image_url} → {detections:[...]}
//                               deterministic：同 URL 同结果（字符串哈希做种子）
//
// 约定：原生 network 组件不支持真流式（API_CONTRACT §4.5），本服务也只返回
// 完整 JSON；打字机效果由 H5 端 revealText 模拟。接真实 LLM 时改 H5 工具页
// 内的服务地址即可（OpenAI 兼容契约对齐）。
//
// Flags:
//   --port <n>    监听端口（默认 8043）
//   --delay <ms>  模拟推理延迟基数（默认 600，实际 = delay + 随机 0~400ms）
//   --quiet       只输出错误
//
// 退出码：0 = Ctrl-C 正常退出 / 1 = 端口占用 / 2 = 参数错误

import http from 'node:http'
import crypto from 'node:crypto'

const args = process.argv.slice(2)
function argNum(flag, dflt) {
  const i = args.indexOf(flag)
  if (i === -1) return dflt
  const v = Number(args[i + 1])
  if (!Number.isFinite(v) || v < 0) { console.error(`✗ Invalid value for ${flag}`); process.exit(2) }
  return v
}
const QUIET = args.includes('--quiet')
const PORT = argNum('--port', 8043)
const DELAY = argNum('--delay', 600)

const log = (...a) => { if (!QUIET) console.log(...a) }
const sleep = ms => new Promise(r => setTimeout(r, ms))
const hash = s => crypto.createHash('md5').update(s).digest()[0] // 0-255 种子

// ---- mock 内容生成 ----

function lastUserContent(messages) {
  for (let i = messages.length - 1; i >= 0; i--) {
    if (messages[i].role === 'user') return String(messages[i].content || '')
  }
  return ''
}

function translatorReply(text) {
  return `【mock 译文】（${text.length} 字）${text}\n\n— 来自 ai-mock-server（接真实 LLM 后此处为模型输出）`
}

function summarizerReply(text) {
  const trimmed = text.trim()
  const sentences = trimmed.split(/(?<=[。！？!?.])\s*/).filter(Boolean)
  const first = sentences[0] || trimmed.slice(0, 40)
  const last = sentences.length > 1 ? sentences[sentences.length - 1] : ''
  return [
    `【mock 摘要】全文 ${trimmed.length} 字、${sentences.length || 1} 句。`,
    `要点：${first}`,
    last && last !== first ? `收尾：${last}` : '',
    '— 来自 ai-mock-server（接真实 LLM 后此处为模型输出）',
  ].filter(Boolean).join('\n')
}

function chatCompletion(body) {
  const text = lastUserContent(body.messages || [])
  const model = body.model || 'translator'
  const content = model === 'summarizer' ? summarizerReply(text) : translatorReply(text)
  return {
    id: `mock-${Date.now()}`,
    object: 'chat.completion',
    created: Math.floor(Date.now() / 1000),
    model,
    choices: [{ index: 0, message: { role: 'assistant', content }, finish_reason: 'stop' }],
    usage: { prompt_tokens: Math.ceil(text.length / 2), completion_tokens: Math.ceil(content.length / 2), total_tokens: Math.ceil((text.length + content.length) / 2) },
  }
}

// 识图：deterministic 伪随机（URL 哈希种子），标签表与 foods 业务呼应
const LABELS = ['苹果 apple', '香蕉 banana', '汉堡 burger', '披萨 pizza', '热狗 hotdog', '番茄 tomato', '西兰花 broccoli', '橙子 orange']

function rng(seed) { // mulberry32
  let a = seed
  return () => {
    a |= 0; a = (a + 0x6D2B79F5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function imageAnalysis(body) {
  const url = String(body.image_url || '')
  const rand = rng(hash(url))
  const n = 1 + Math.floor(rand() * 4) // 1-4 个目标
  const detections = []
  for (let i = 0; i < n; i++) {
    const x = Math.round(rand() * 400) / 10       // 0-40.0
    const y = Math.round(rand() * 400) / 10
    const w = Math.round((5 + rand() * 30) * 10) / 10
    const h = Math.round((5 + rand() * 30) * 10) / 10
    detections.push({
      label: LABELS[Math.floor(rand() * LABELS.length)],
      confidence: Math.round((0.55 + rand() * 0.43) * 1000) / 1000, // 0.55-0.98
      box: { x, y, w, h },
    })
  }
  return { image_url: url, model: body.model || 'mock-yolo', detections, cost_ms: Math.round(20 + rand() * 60) }
}

// ---- HTTP 基础设施 ----

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = []
    req.on('data', c => chunks.push(c))
    req.on('end', () => resolve(Buffer.concat(chunks).toString()))
    req.on('error', reject)
  })
}

function sendJson(res, status, obj) {
  const body = JSON.stringify(obj)
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  })
  res.end(body)
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') { // CORS preflight（纯浏览器直连场景）
    sendJson(res, 204, {})
    return
  }
  if (req.method !== 'POST') {
    sendJson(res, 405, { error: { message: `method ${req.method} not allowed` } })
    return
  }

  let body
  try {
    body = JSON.parse(await readBody(req) || '{}')
  } catch {
    sendJson(res, 400, { error: { message: 'invalid JSON body' } })
    return
  }

  const started = Date.now()
  let payload
  if (req.url === '/v1/chat/completions') payload = chatCompletion(body)
  else if (req.url === '/v1/images/analyses') payload = imageAnalysis(body)
  else {
    sendJson(res, 404, { error: { message: `no route: ${req.url}` } })
    return
  }

  await sleep(DELAY + Math.round(Math.random() * 400)) // 模拟推理延迟
  log(`← ${req.url} · ${Date.now() - started}ms · ${req.socket.remoteAddress}`)
  sendJson(res, 200, payload)
})

server.on('error', (e) => {
  if (e.code === 'EADDRINUSE') {
    console.error(`✗ Port ${PORT} already in use`)
    process.exit(1)
  }
  console.error('✗', e.message)
  process.exit(1)
})

server.listen(PORT, '0.0.0.0', () => {
  log(`🤖 ai-mock-server on http://0.0.0.0:${PORT}`)
  log(`   POST /v1/chat/completions   (model=translator|summarizer)`)
  log(`   POST /v1/images/analyses    (deterministic by URL hash)`)
  log(`   模拟器访问：iOS localhost / Android 10.0.2.2 / Harmony hdc rport tcp:${PORT}`)
})

process.on('SIGINT', () => { log('\nbye'); process.exit(0) })
