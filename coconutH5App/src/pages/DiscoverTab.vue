<template>
  <div>
    <h1 class="page-title">发现</h1>
    <p class="page-hint">远端数据（Sniper API · bridge 网络引擎全链路）+ 事件订阅流。</p>

    <ApiBaseField v-model="apiBase" :storage-key="SNIPER_BASE_KEY" query-key="apiBase"
      :default-value="DEFAULT_SNIPER_BASE" :hint="placeholderHint" />

    <!-- ========== 区块 1：远端列表 → 详情 ========== -->
    <div class="card">
      <h3>食物清单（GET /foods/）</h3>

      <div v-if="listState === 'loading'" class="list-state">加载中…</div>

      <div v-else-if="listState === 'error'" class="list-state err">
        <pre class="err">{{ listError }}</pre>
        <button class="btn btn-a retry-btn" @click="loadList">重试</button>
      </div>

      <div v-else-if="listState === 'empty'" class="list-state">（列表为空）</div>

      <div v-else class="food-list">
        <div v-for="f in foods" :key="f.id" class="food-row" @click="openDetail(f)">
          <div class="food-main">
            <div class="food-title">{{ f.title || f.name || `#${f.id}` }}</div>
            <div class="food-sub">{{ f.maker || '—' }} · id={{ f.id }}</div>
          </div>
          <div class="food-star">{{ '★'.repeat(starOf(f)) }}</div>
          <span class="food-arrow">›</span>
        </div>
      </div>

      <div class="btns" style="margin-top: 10px">
        <button class="btn btn-b" @click="loadList" :disabled="listState === 'loading'">刷新列表</button>
      </div>
      <p class="sec-hint">点行 navigator.forward 打开详情（新容器）；详情关闭时 close 回传 → 下方事件流出现 nav.result。</p>
    </div>

    <!-- ========== 区块 2：事件订阅流 ========== -->
    <div class="card">
      <h3>事件流（coconut.on）<span v-if="unreadCount" class="unread-badge">{{ unreadCount }} 条新</span></h3>

      <div class="btns" style="margin-bottom: 10px">
        <button class="btn btn-d" @click="sendEcho">test.echo 自验证</button>
        <button class="btn btn-b" @click="markAllRead" :disabled="!unreadCount">全部已读</button>
        <button class="btn btn-c" @click="clearEvents">清空</button>
      </div>

      <div v-if="events.length === 0" class="list-state">
        订阅中：test.echo / app.foreground / app.background / network.change / nav.result<br />
        切后台再回来看看，或点上方按钮自验证。
      </div>

      <div v-for="e in events" :key="e.id" :class="['event-item', { unread: e.ts > lastReadTs }]">
        <div class="event-head">
          <span class="event-topic">{{ e.topic }}</span>
          <span class="event-time">{{ e.time }}</span>
        </div>
        <pre class="muted">{{ e.payload }}</pre>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import ApiBaseField from '../components/ApiBaseField.vue'
import { pcall, pcallBoot } from '../lib/pcall'
import { onEvent, fmtEventTime } from '../lib/events'
import {
  SNIPER_BASE_KEY, DEFAULT_SNIPER_BASE, sniperPlaceholder,
  getFoods, resetToken,
} from '../lib/sniper'

const READ_TS_KEY = 'h5app.last_read_ts'

const apiBase = ref(DEFAULT_SNIPER_BASE)
const placeholderHint = computed(sniperPlaceholder)

// ---- 列表 ----
const foods = ref([])
const listState = ref('idle') // idle | loading | error | empty | loaded
const listError = ref('')

async function loadList() {
  listState.value = 'loading'
  listError.value = ''
  const r = await getFoods(apiBase.value, 20)
  if (r.ok) {
    foods.value = r.data
    listState.value = r.data.length ? 'loaded' : 'empty'
  } else {
    resetToken()
    listError.value = `列表加载失败：${r.message || '未知错误'}\n（检查上方服务地址；三端 localhost 语义不同，见提示）`
    listState.value = 'error'
  }
}

function starOf(f) {
  const s = Number(f.star ?? f.stars ?? 0)
  return Math.max(0, Math.min(5, isNaN(s) ? 0 : s))
}

// forward 开新容器：URL 必须绝对（UrlGuard 拦 scheme-less 相对路径）
function openDetail(f) {
  const url = location.origin + location.pathname + '#/detail?id=' + encodeURIComponent(f.id)
  window.coconut.navigator.forward({ url, header: { title: '详情' } }, () => {})
}

// ---- 事件流 ----
const events = ref([])
let eventSeq = 0
const lastReadTs = ref(0)
const unreadCount = computed(() => events.value.filter(e => e.ts > lastReadTs.value).length)

function appendEvent(topic, data) {
  events.value.unshift({
    id: ++eventSeq,
    topic,
    time: fmtEventTime(),
    ts: Date.now(),
    payload: (() => { try { return JSON.stringify(data, null, 2) } catch { return String(data) } })(),
  })
  if (events.value.length > 50) events.value.length = 50
}

async function sendEcho() {
  const params = { hello: 'discover', ts: Date.now() }
  await pcall('event', 'echo', params)
  // 回包经 native event.push → test.echo handler → appendEvent（不在此直接 append）
}

async function markAllRead() {
  lastReadTs.value = Date.now()
  await pcall('storage', 'setItem', { key: READ_TS_KEY, value: String(lastReadTs.value) })
}

async function clearEvents() {
  const confirmed = await new Promise(resolve => {
    window.coconut.dialog.confirm(
      '清空事件流', `确定清空 ${events.value.length} 条事件记录？`, '清空', '取消',
      (err, res) => resolve(!err && res && (res.confirm === true || res.confirmed === true || res.success === true))
    )
  })
  if (!confirmed) return
  events.value = []
  await markAllRead()
}

onMounted(async () => {
  // 已读水位从 storage 恢复（mount 即调，用 pcallBoot 抗 config 注入竞态）
  const r = await pcallBoot('storage', 'getItem', { key: READ_TS_KEY })
  if (!r.err && r.data && r.data.value) lastReadTs.value = Number(r.data.value) || 0

  // 四类事件订阅（events.js fan-out；nav.result 接住详情/设置页 close 回传）
  onEvent('test.echo', d => appendEvent('test.echo', d))
  onEvent('app.foreground', d => appendEvent('app.foreground', d))
  onEvent('app.background', d => appendEvent('app.background', d))
  onEvent('network.change', d => appendEvent('network.change', d))
  onEvent('nav.result', d => appendEvent('nav.result', d))

  loadList()
})
</script>

<style scoped>
.list-state {
  font-size: 13px;
  color: var(--c-muted);
  line-height: 1.7;
  padding: 12px 0;
  text-align: center;
}
.list-state.err pre { color: #f53f3f; text-align: left; }
.retry-btn { flex: none; min-width: 0; height: 38px; font-size: 14px; margin: 8px auto 0; display: flex; }

.food-list { display: flex; flex-direction: column; }
.food-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 4px;
  border-bottom: 1px solid var(--c-border);
  cursor: pointer;
}
.food-row:last-child { border-bottom: none; }
.food-row:active { background: #f7f8fa; }
.food-main { flex: 1; min-width: 0; }
.food-title { font-size: 15px; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.food-sub { font-size: 12px; color: var(--c-muted); margin-top: 2px; }
.food-star { flex: none; font-size: 12px; color: #ff7d00; }
.food-arrow { flex: none; color: var(--c-muted); font-size: 18px; }

.sec-hint { font-size: 11px; color: var(--c-muted); margin-top: 8px; line-height: 1.5; }

.unread-badge {
  float: right;
  background: #f53f3f;
  color: #fff;
  font-size: 11px;
  border-radius: 999px;
  padding: 2px 8px;
  font-weight: 500;
}
.event-item {
  border: 1px solid var(--c-border);
  border-radius: 8px;
  padding: 8px 10px;
  margin-bottom: 8px;
}
.event-item.unread { border-color: #cfe0ff; background: #f7faff; }
.event-head { display: flex; justify-content: space-between; margin-bottom: 4px; }
.event-topic { font-size: 12px; font-weight: 600; color: var(--c-primary); }
.event-item.unread .event-topic::after {
  content: '●';
  color: #f53f3f;
  font-size: 8px;
  margin-left: 4px;
  vertical-align: middle;
}
.event-time { font-size: 11px; color: var(--c-muted); }
</style>
