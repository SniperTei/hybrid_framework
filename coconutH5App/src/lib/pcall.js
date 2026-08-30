// error-first callback → Promise 封装（house pattern，同 coconutWebBox Demo/Settings）
// 返回 { err, data }：err 非空 = bridge 层失败（超时/安全拦截）；
// err 空但 data.success === false = 业务层失败（平台不支持等，见 API_CONTRACT §2）
export function pcall(component, fn, params) {
  return new Promise(resolve => {
    window.coconut.call(component, fn, params || {}, (err, data) => {
      resolve({ err, data })
    })
  })
}

// pcall 业务失败语义化封装：err / data.success===false 都归一为 { ok:false, message }
export async function pcallBiz(component, fn, params) {
  const r = await pcall(component, fn, params)
  if (r.err) return { ok: false, message: `${r.err.code} ${r.err.message}` }
  const d = r.data
  if (d && d.success === false) return { ok: false, message: d.message || '业务层返回不支持' }
  return { ok: true, data: d }
}
