<template>
  <div class="tool-wrap">
    <div class="tool-head">
      <button class="back-btn" @click="goBack">‹ 返回</button>
      <h1 class="page-title">AI 翻译</h1>
    </div>
    <p class="page-hint">POST /v1/chat/completions（OpenAI 兼容非流式）· 打字机为 H5 端模拟</p>

    <ApiBaseField v-model="apiBase" :storage-key="LLM_BASE_KEY" query-key="llmBase"
      :default-value="DEFAULT_LLM_BASE" :hint="placeholderHint" />

    <div class="card">
      <h3>原文（中文 → 英文）</h3>
      <textarea v-model="input" class="ta" rows="4" maxlength="2000"
        placeholder="输入要翻译的文本…" @keyup.ctrl.enter="run"></textarea>
      <div class="ta-meta">{{ input.length }} / 2000</div>
      <div class="btns" style="margin-top: 10px">
        <button class="btn btn-a" @click="run" :disabled="loading || !input.trim()">
          {{ loading ? '翻译中…' : '翻译' }}
        </button>
        <button v-if="output && !loading" class="btn btn-b" @click="run">重新翻译</button>
      </div>
    </div>

    <div v-if="errorMsg" class="card">
      <h3>失败</h3>
      <pre class="err">{{ errorMsg }}</pre>
    </div>

    <div v-if="output !== null" class="card">
      <h3>译文{{ typing ? '（生成中…）' : ` · ${output.length} 字 · ${duration}ms` }}</h3>
      <p class="output" :class="{ caret: typing }">{{ output }}</p>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onUnmounted } from 'vue'
import ApiBaseField from '../../components/ApiBaseField.vue'
import { LLM_BASE_KEY, DEFAULT_LLM_BASE, llmPlaceholder, chatComplete, revealText } from '../../lib/llm'

const apiBase = ref(DEFAULT_LLM_BASE)
const placeholderHint = computed(llmPlaceholder)

const input = ref('混合框架的 bridge 把原生能力透传给 H5，让一套代码跑在三端容器里。')
const loading = ref(false)
const typing = ref(false)
const output = ref(null)
const errorMsg = ref('')
const duration = ref(0)
let cancelReveal = null

async function run() {
  if (loading.value) return
  loading.value = true
  errorMsg.value = ''
  output.value = null
  if (cancelReveal) { cancelReveal(); cancelReveal = null }

  const messages = [
    { role: 'system', content: '你是翻译助手，把用户输入的中文翻译成英文，只输出译文。' },
    { role: 'user', content: input.value.trim() },
  ]
  const t0 = performance.now()
  const r = await chatComplete(apiBase.value, { model: 'translator', messages })
  duration.value = Math.round(performance.now() - t0)
  loading.value = false

  if (!r.ok) { errorMsg.value = r.message; return }
  // 打字机（H5 模拟流式；原生引擎支持流式后可切真流式）
  output.value = ''
  typing.value = true
  cancelReveal = revealText(r.content, partial => { output.value = partial }, { chunk: 2, interval: 30 })
  const unwatch = setInterval(() => {
    if (output.value.length >= r.content.length) { typing.value = false; clearInterval(unwatch) }
  }, 60)
}

function goBack() { window.location.hash = '#/ai' }

onUnmounted(() => { if (cancelReveal) cancelReveal() })
</script>

<style scoped>
.tool-wrap { max-width: 720px; margin: 0 auto; padding: 20px 16px 48px; }
.tool-head { display: flex; align-items: center; gap: 12px; }
.back-btn { border: none; background: none; color: var(--c-primary); font-size: 15px; padding: 6px 4px 6px 0; }
.ta {
  width: 100%; resize: vertical; padding: 10px 12px; font-size: 14px; line-height: 1.6;
  border: 1px solid #dcdfe6; border-radius: 8px; background: var(--c-card); color: var(--c-text);
  font-family: inherit; outline: none;
}
.ta:focus { border-color: var(--c-primary); }
.ta-meta { font-size: 11px; color: var(--c-muted); text-align: right; margin-top: 4px; }
.output { font-size: 15px; line-height: 1.8; white-space: pre-wrap; word-break: break-all; min-height: 28px; }
.output.caret::after { content: '▌'; color: var(--c-primary); animation: blink 0.8s infinite; }
@keyframes blink { 50% { opacity: 0; } }
</style>
