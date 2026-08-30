// coconut.on 多订阅 fan-out 层
//
// coconut.js 的 handlers 是 Record<topic, single handler>：同 topic 第二次
// coconut.on 会覆盖第一次。app 内多个页面（HomeTab 网络卡 / DiscoverTab
// 事件流）都要订 network.change —— 这里对每 topic 只注册一个 native handler，
// 本地 Set fan-out 给任意多个监听者。
const listeners = {}

function ensureSub(topic) {
  if (listeners[topic]) return
  listeners[topic] = new Set()
  const c = window.coconut
  if (c && c.on) {
    c.on(topic, (data) => {
      listeners[topic].forEach(fn => {
        try { fn(data) } catch (e) { console.error(`event handler error [${topic}]:`, e) }
      })
    })
  }
}

// 订阅 native 推送事件；返回取消函数
export function onEvent(topic, fn) {
  ensureSub(topic)
  listeners[topic].add(fn)
  return () => listeners[topic].delete(fn)
}

export function fmtEventTime(ts = Date.now()) {
  const d = new Date(ts)
  const p = n => String(n).padStart(2, '0')
  return `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`
}
