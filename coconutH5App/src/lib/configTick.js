import { ref, onMounted, onUnmounted } from 'vue'

// configTick house pattern（从 coconutWebBox Demo/Settings 抽出）：
// config 注入是异步的（Harmony 实测：_loadSecurityConfig 晚于 Vue 首渲染），
// 读 window.coconut / __coconutConfig 的 computed 没有响应式依赖、永不重算。
// 监听 coconut.js 的 'coconut:config-loaded' 事件（v3.2.0）强制失效。
//
// 用法：
//   const configTick = useConfigTick()
//   const derived = computed(() => { void configTick.value; return readWindow() })
export function useConfigTick() {
  const configTick = ref(0)
  const bump = () => { configTick.value++ }
  onMounted(() => window.addEventListener('coconut:config-loaded', bump))
  onUnmounted(() => window.removeEventListener('coconut:config-loaded', bump))
  return configTick
}

// Promise 版门控：config 已注入立即 resolve；否则等 coconut:config-loaded
// （v3.5.1 轮询自愈会在到位后补发该事件），timeoutMs 兜底 resolve(false)。
// 用于 forward 新容器里 mount 即发的 bridge 调用（config 晚于页面 mount 的竞态，
// Android 实测于 CoconutAndroidApp 详情页）。纯浏览器无注入，走超时兜底。
export function whenConfigReady(timeoutMs = 10000) {
  return new Promise(resolve => {
    if (window.__coconutConfig) return resolve(true)
    const timer = setTimeout(() => resolve(false), timeoutMs)
    window.addEventListener('coconut:config-loaded', () => {
      clearTimeout(timer)
      resolve(true)
    }, { once: true })
  })
}
