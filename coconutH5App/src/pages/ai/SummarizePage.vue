<template>
  <div class="tool-wrap">
    <div class="tool-head">
      <button class="back-btn" @click="goBack">‹ 返回</button>
      <h1 class="page-title">AI 摘要</h1>
    </div>
    <p class="page-hint">POST /v1/chat/completions（OpenAI 兼容非流式）· 打字机为 H5 端模拟</p>

    <ApiBaseField v-model="apiBase" :storage-key="LLM_BASE_KEY" query-key="llmBase"
      :default-value="DEFAULT_LLM_BASE" :hint="placeholderHint" />

    <div class="card">
      <h3>长文</h3>
      <textarea v-model="input" class="ta" rows="8" maxlength="5000"
        placeholder="粘贴需要摘要的长文…" @keyup.ctrl.enter="run"></textarea>
      <div class="ta-meta">{{ input.length }} / 5000</div>
      <div class="btns" style="margin-top: 10px">
        <button class="btn btn-a" @click="run" :disabled="loading || !input.trim()">
          {{ loading ? '摘要中…' : '生成摘要' }}
        </button>
        <button v-if="output && !loading" class="btn btn-b" @click="run">重新生成</button>
      </div>
    </div>

    <div v-if="errorMsg" class="card">
      <h3>失败</h3>
      <pre class="err">{{ errorMsg }}</pre>
    </div>

    <div v-if="output !== null" class="card">
      <h3>摘要{{ typing ? '（生成中…）' : ` · ${duration}ms` }}</h3>
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

const SAMPLE = `移动混合开发框架的核心矛盾是「一套代码」与「平台差异」之间的张力。传统 WebView 方案把全部业务搬进 H5，付出的是性能与原生能力可达性的代价；原生方案则在每个平台重复实现业务逻辑。桥接层（bridge）是折中之路：H5 承载界面与交互，原生提供设备能力、网络引擎与容器管理，两端通过消息协议通信。实践中真正的难点不在通信本身，而在契约治理——版本对齐、能力探测、错误语义、安全边界，任何一处含糊都会在三端的某台真机上变成不可复现的偶发问题。`

const input = ref(SAMPLE)
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
    { role: 'system', content: '你是摘要助手，用两到三句话概括用户输入的长文，只输出摘要。' },
    { role: 'user', content: input.value.trim() },
  ]
  const t0 = performance.now()
  const r = await chatComplete(apiBase.value, { model: 'summarizer', messages })
  duration.value = Math.round(performance.now() - t0)
  loading.value = false

  if (!r.ok) { errorMsg.value = r.message; return }
  output.value = ''
  typing.value = true
  cancelReveal = revealText(r.content, partial => { output.value = partial }, { chunk: 3, interval: 24 })
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
