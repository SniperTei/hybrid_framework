// error-first callback → Promise 封装（house pattern，同 coconutWebBox Demo/Settings）
// 返回 { err, data }：err 非空 = bridge 层失败（超时/安全拦截）；
// err 空但 data.success === false = 业务层失败（平台不支持等，见 API_CONTRACT §2）
import { whenConfigReady } from './configTick'

export function pcall(component, fn, params) {
  return new Promise(resolve => {
    window.coconut.call(component, fn, params || {}, (err, data) => {
      resolve({ err, data })
    })
  })
}

// mount 即调用的 bridge 请求专用：forward 新容器里 config（含 token）注入晚于
// 页面 mount，首轮 300004（Invalid bridge token）。等 coconut:config-loaded
// （coconut.js v3.5.1 轮询补发）后重试一次；已就绪时零开销直通。
export async function pcallBoot(component, fn, params) {
  let r = await pcall(component, fn, params)
  if (r.err && String(r.err.code) === '300004') {
    await whenConfigReady()
    r = await pcall(component, fn, params)
  }
  return r
}

// pcall 业务失败语义化封装：err / data.success===false 都归一为 { ok:false, message }
export async function pcallBiz(component, fn, params) {
  const r = await pcall(component, fn, params)
  if (r.err) return { ok: false, message: `${r.err.code} ${r.err.message}` }
  const d = r.data
  if (d && d.success === false) return { ok: false, message: d.message || '业务层返回不支持' }
  return { ok: true, data: d }
}
