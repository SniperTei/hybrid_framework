// SPA 内切页的详情结果传递（detail.result 事件流的来源）：
// DetailPage 返回前写入 pending 槽，DiscoverTab 重新挂载时取走。
// 不能用 CustomEvent 直发——#/detail 打开期间 TabShell 整体卸载，
// DiscoverTab 监听器已不存在；挂载时机是「返回之后」，槽正好对上。
let pending = null

export function setDetailResult(r) { pending = r }

export function takeDetailResult() {
  const r = pending
  pending = null
  return r
}
