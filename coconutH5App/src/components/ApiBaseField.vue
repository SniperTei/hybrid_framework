<script setup>
// 可折叠服务地址配置行：URL query 注入（e2e 缝）> storage 落盘 > 默认值。
// v-model 绑定当前生效地址；展开修改 + 保存（storage.set）。
import { ref, onMounted } from 'vue'
import { pcall } from '../lib/pcall'

const props = defineProps({
  storageKey: { type: String, required: true },
  queryKey: { type: String, required: true },
  defaultValue: { type: String, required: true },
  hint: { type: String, default: '' },
})
const model = defineModel({ type: String, required: true })

const open = ref(false)
const draft = ref('')
const saved = ref(false)

onMounted(async () => {
  const q = new URLSearchParams(location.search).get(props.queryKey)
  if (q) { model.value = q; return } // query 注入不落盘（一次性）
  const r = await pcall('storage', 'getItem', { key: props.storageKey })
  if (!r.err && r.data && r.data.value) model.value = r.data.value
})

function edit() {
  draft.value = model.value
  open.value = true
}

async function save() {
  const v = draft.value.trim().replace(/\/$/, '')
  if (!v) return
  model.value = v
  open.value = false
  await pcall('storage', 'setItem', { key: props.storageKey, value: v })
  saved.value = true
  setTimeout(() => { saved.value = false }, 1500)
}
</script>

<template>
  <div class="abf">
    <div class="abf-row" @click="open ? null : edit()">
      <span class="abf-label">服务地址</span>
      <code class="abf-value">{{ model }}</code>
      <button v-if="!open" class="abf-edit" @click.stop="edit">修改</button>
    </div>
    <div v-if="open" class="abf-edit-area">
      <input v-model="draft" class="input" :placeholder="hint" @keyup.enter="save" />
      <div class="abf-btns">
        <button class="btn btn-a abf-save" @click="save">保存</button>
        <button class="btn btn-c abf-save" @click="open = false">取消</button>
      </div>
      <p v-if="hint" class="abf-hint">{{ hint }} · iOS ATS 拦非 localhost 明文 HTTP</p>
    </div>
    <div v-else-if="saved" class="abf-saved">已保存（storage 落盘）</div>
  </div>
</template>

<style scoped>
.abf {
  background: var(--c-card);
  border-radius: 10px;
  padding: 10px 14px;
  margin-bottom: 12px;
  box-shadow: var(--shadow);
}
.abf-row {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.abf-label { flex: none; font-size: 12px; color: var(--c-muted); }
.abf-value {
  flex: 1;
  min-width: 0;
  font-size: 12px;
  font-family: "SF Mono", Menlo, monospace;
  color: var(--c-text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.abf-edit {
  flex: none;
  border: none;
  background: none;
  color: var(--c-primary);
  font-size: 13px;
  padding: 4px;
}
.abf-edit-area { margin-top: 10px; }
.abf-btns { display: flex; gap: 10px; margin-top: 8px; }
.abf-save { min-width: 0; flex: 1; height: 38px; font-size: 14px; }
.abf-hint { font-size: 11px; color: var(--c-muted); margin-top: 6px; line-height: 1.5; }
.abf-saved { font-size: 11px; color: #00b42c; margin-top: 6px; }
</style>
