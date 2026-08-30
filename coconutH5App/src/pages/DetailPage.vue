<template>
  <div class="detail-wrap">
    <h1 class="page-title">详情</h1>
    <p class="page-hint">GET /foods/{{ foodId }}（bridge 网络引擎 · 独立容器自行登录）</p>

    <div v-if="state === 'loading'" class="card"><pre class="muted">加载中…</pre></div>

    <div v-else-if="state === 'error'" class="card">
      <h3>业务失败</h3>
      <pre class="err">{{ errorMsg }}</pre>
      <div class="btns" style="margin-top: 10px">
        <button class="btn btn-a" @click="load">重试</button>
      </div>
    </div>

    <template v-else>
      <div class="card">
        <h3>食物 #{{ foodId }}</h3>
        <div class="detail-rows">
          <div class="d-row"><span class="d-k">名称</span><span class="d-v">{{ food.title || food.name || '—' }}</span></div>
          <div class="d-row"><span class="d-k">制作人</span><span class="d-v">{{ food.maker || '—' }}</span></div>
          <div class="d-row"><span class="d-k">评分</span><span class="d-v star">{{ '★'.repeat(star) }}{{ '☆'.repeat(5 - star) }}</span></div>
        </div>
      </div>
      <div class="card">
        <h3>原始数据</h3>
        <pre class="muted">{{ rawJson }}</pre>
      </div>
    </template>

    <div class="btns" style="margin-top: 16px">
      <button class="btn btn-a" @click="back">返回（navigator.back）</button>
      <button class="btn btn-d" @click="closeWithResult">关闭并回传</button>
    </div>
    <p class="page-hint" style="margin-top: 10px">
      「关闭并回传」= navigator.close({{ closePayloadPreview }}) → 上一容器事件流的 nav.result。
    </p>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import {
  resolveSniperBase, getFood,
} from '../lib/sniper'

// forward 打开的新容器：独立 WebView 实例，模块状态不共享 → 自行 login
const foodId = (() => {
  const h = window.location.hash
  const q = h.split('?')[1] || ''
  return new URLSearchParams(q).get('id') || ''
})()

const state = ref('loading')
const errorMsg = ref('')
const food = ref({})
const rawJson = ref('')
const apiBase = ref('')

const star = computed(() => {
  const s = Number(food.value.star ?? food.value.stars ?? 0)
  return Math.max(0, Math.min(5, isNaN(s) ? 0 : s))
})
const closePayloadPreview = computed(() => JSON.stringify({ visitedId: foodId, from: 'detail' }))

async function load() {
  state.value = 'loading'
  const r = await getFood(apiBase.value, foodId)
  if (r.ok) {
    food.value = r.data || {}
    rawJson.value = JSON.stringify(r.data, null, 2)
    state.value = 'loaded'
  } else {
    errorMsg.value = `${r.message || '未知错误'}${r.httpStatus ? `（HTTP ${r.httpStatus}）` : ''}`
    state.value = 'error'
  }
}

function back() {
  window.coconut.navigator.back(() => {})
}

function closeWithResult() {
  window.coconut.navigator.close({ visitedId: foodId, from: 'detail', ts: Date.now() }, () => {})
}

onMounted(async () => {
  apiBase.value = await resolveSniperBase()
  if (!foodId) {
    errorMsg.value = 'URL 缺少 id 参数（#/detail?id=…）'
    state.value = 'error'
    return
  }
  load()
})
</script>

<style scoped>
.detail-wrap { max-width: 720px; margin: 0 auto; padding: 20px 16px 48px; }
.detail-rows { display: flex; flex-direction: column; }
.d-row { display: flex; padding: 8px 0; border-bottom: 1px solid var(--c-border); font-size: 15px; }
.d-row:last-child { border-bottom: none; }
.d-k { flex: none; width: 64px; color: var(--c-muted); font-size: 13px; }
.d-v.star { color: #ff7d00; letter-spacing: 2px; }
</style>
