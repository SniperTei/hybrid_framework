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
