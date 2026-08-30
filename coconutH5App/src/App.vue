<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import TabShell from './components/TabShell.vue'
import DetailPage from './pages/DetailPage.vue'
import SettingsPage from './pages/SettingsPage.vue'
import AiDetectPage from './pages/ai/DetectPage.vue'
import AiTranslatePage from './pages/ai/TranslatePage.vue'
import AiSummarizePage from './pages/ai/SummarizePage.vue'

// 两层 hash 路由（单 bundle，无 vue-router 依赖）：
//   #/settings            → SettingsPage（全屏，无 tab）
//   #/detail?id=..        → DetailPage（全屏，无 tab；forward 只能靠 URL 寻址容器）
//   #/ai/<tool>           → AI 工具二级页（全屏，无 tab）
//   #/home|discover|ai|mine → TabShell（tab hash 子路由）
const AI_TOOL_PAGES = {
  detect: AiDetectPage,
  translate: AiTranslatePage,
  summarize: AiSummarizePage,
}

const hash = ref(window.location.hash)
function onHashChange() { hash.value = window.location.hash }

onMounted(() => {
  window.addEventListener('hashchange', onHashChange)
  // coconut.init 全 app 只调一次（绑定 visibilitychange → app.foreground/background）
  const coconut = window.coconut
  if (coconut && !coconut.isInitialized) {
    try { coconut.init({ debug: true }) } catch (e) { console.error('coconut init failed:', e) }
  }
})
onUnmounted(() => window.removeEventListener('hashchange', onHashChange))

function aiTool(h) {
  const m = h.match(/^#\/ai\/([a-z]+)/)
  return m && AI_TOOL_PAGES[m[1]] ? m[1] : null
}
</script>

<template>
  <SettingsPage v-if="hash.startsWith('#/settings')" />
  <DetailPage v-else-if="hash.startsWith('#/detail')" />
  <component :is="AI_TOOL_PAGES[aiTool(hash)]" v-else-if="aiTool(hash)" />
  <TabShell v-else :hash="hash" />
</template>
