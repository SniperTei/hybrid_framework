<template>
  <div class="tool-wrap">
    <div class="tool-head">
      <button class="back-btn" @click="goBack">‹ 返回</button>
      <h1 class="page-title">AI 识图</h1>
    </div>
    <p class="page-hint">图片 URL → 目标检测（POST /v1/images/analyses · bridge 网络引擎）</p>

    <ApiBaseField v-model="apiBase" :storage-key="LLM_BASE_KEY" query-key="llmBase"
      :default-value="DEFAULT_LLM_BASE" :hint="placeholderHint" />

    <div class="card">
      <h3>图片</h3>
      <input v-model="imageUrl" class="input" placeholder="https://…/food.jpg" @keyup.enter="detect" />
      <div v-if="previewOk" class="img-preview"><img :src="imageUrl" alt="预览" /></div>
      <div class="btns" style="margin-top: 10px">
        <button class="btn btn-a" @click="detect" :disabled="loading || !imageUrl.trim()">
          {{ loading ? '识别中…' : '开始识别' }}
        </button>
      </div>
    </div>

    <div v-if="state === 'error'" class="card">
      <h3>识别失败</h3>
      <pre class="err">{{ errorMsg }}</pre>
    </div>

    <div v-if="detections.length" class="card">
      <h3>检测结果（{{ detections.length }} 个目标 · {{ costMs }}ms）</h3>
      <div v-for="(d, i) in detections" :key="i" class="det-row">
        <span class="det-label">{{ d.label }}</span>
        <div class="det-bar"><div class="det-fill" :style="{ width: pct(d.confidence) }"></div></div>
        <span class="det-conf">{{ (d.confidence * 100).toFixed(1) }}%</span>
        <span class="det-box">box {{ fmtBox(d.box) }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import ApiBaseField from '../../components/ApiBaseField.vue'
import { LLM_BASE_KEY, DEFAULT_LLM_BASE, llmPlaceholder, analyzeImage } from '../../lib/llm'

const apiBase = ref(DEFAULT_LLM_BASE)
const placeholderHint = computed(llmPlaceholder)

const imageUrl = ref('https://raw.githubusercontent.com/pytorch/pytorch/main/docs/source/_static/img/pytorch-logo.png')
const loading = ref(false)
const state = ref('idle')
const errorMsg = ref('')
const detections = ref([])
const costMs = ref(0)

const previewOk = computed(() => /^https?:\/\//.test(imageUrl.value.trim()))

function pct(c) { return `${Math.max(2, Math.round(c * 100))}%` }
function fmtBox(b) { return b ? `[${b.x}, ${b.y}, ${b.w}, ${b.h}]` : '—' }

async function detect() {
  loading.value = true
  state.value = 'idle'
  detections.value = []
  const t0 = performance.now()
  const r = await analyzeImage(apiBase.value, imageUrl.value.trim())
  costMs.value = Math.round(performance.now() - t0)
  loading.value = false
  if (r.ok) {
    detections.value = r.detections
    state.value = 'loaded'
  } else {
    errorMsg.value = r.message
    state.value = 'error'
  }
}

function goBack() { window.location.hash = '#/ai' }
</script>

<style scoped>
.tool-wrap { max-width: 720px; margin: 0 auto; padding: 20px 16px 48px; }
.tool-head { display: flex; align-items: center; gap: 12px; }
.back-btn {
  border: none; background: none; color: var(--c-primary);
  font-size: 15px; padding: 6px 4px 6px 0;
}
.img-preview { margin-top: 10px; border-radius: 8px; overflow: hidden; background: #f7f8fa; }
.img-preview img { display: block; width: 100%; max-height: 220px; object-fit: contain; }
.det-row { display: flex; align-items: center; gap: 8px; padding: 8px 0; border-bottom: 1px solid var(--c-border); }
.det-row:last-child { border-bottom: none; }
.det-label { flex: none; width: 84px; font-size: 13px; font-weight: 600; }
.det-bar { flex: 1; height: 8px; border-radius: 4px; background: #f0f1f3; overflow: hidden; }
.det-fill { height: 100%; background: linear-gradient(90deg, #3370ff, #00b42c); }
.det-conf { flex: none; width: 52px; text-align: right; font-size: 12px; font-family: "SF Mono", Menlo, monospace; }
.det-box { flex: none; font-size: 11px; color: var(--c-muted); font-family: "SF Mono", Menlo, monospace; }
</style>
