// coconut.on 多订阅 fan-out 层
//
// coconut.js 的 handlers 是 Record<topic, single handler>：同 topic 第二次
// coconut.on 会覆盖第一次。app 内多个页面（HomeTab 网络卡 / DiscoverTab
// 事件流）都要订 network.change —— 这里对每 topic 只注册一个 native handler，
// 本地 Set fan-out 给任意多个监听者。
const listeners = {}

function makeFanoutHandler(topic) {
  return (data) => {
    listeners[topic].forEach(fn => {
      try { fn(data) } catch (e) { console.error(`event handler error [${topic}]:`, e) }
    })
  }
}

function ensureSub(topic) {
  if (listeners[topic]) return
  listeners[topic] = new Set()
  const c = window.coconut
  if (c && c.on) {
    c.on(topic, makeFanoutHandler(topic))
  }
}

// 订阅 native 推送事件；返回取消函数
export function onEvent(topic, fn) {
  ensureSub(topic)
  listeners[topic].add(fn)
  return () => listeners[topic].delete(fn)
}

// config 到位后重试失败的原生订阅（Harmony 注入竞态：mount 时 c.on 可能
// 300004，ensureSub 的本地守卫挡住重试）。重复 c.on 的覆盖语义在这里无害：
// 新旧 handler 等价（同一 fan-out Set），幂等。
export function resubscribeNative() {
  const c = window.coconut
  if (!c || !c.on) return
  for (const topic of Object.keys(listeners)) {
    if (listeners[topic].size > 0) c.on(topic, makeFanoutHandler(topic))
  }
}

export function fmtEventTime(ts = Date.now()) {
  const d = new Date(ts)
  const p = n => String(n).padStart(2, '0')
  return `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`
}
