<template>
  <div class="settings-wrap">
    <h1 class="page-title">⚙️ 设置</h1>
    <p class="page-hint">storage 持久化 / dialog 二次确认 / navigator 关闭回传 / 热更新全链路。</p>

    <div :class="['platform-chip', { web: environment === 'web' }]">
      <span class="dot"></span>
      <span>{{ platformText }}</span>
    </div>

    <!-- ========== 关于 ========== -->
    <div class="card">
      <h3>关于</h3>
      <pre class="muted">{{ aboutText }}</pre>
      <div class="btns" style="margin-top: 10px">
        <button class="btn btn-a" @click="loadAppInfo" :disabled="loading">应用信息（device.getAppInfo）</button>
        <button class="btn btn-b" @click="showDevice = !showDevice">{{ showDevice ? '收起设备信息' : '展开设备信息（device.getInfo）' }}</button>
      </div>
      <div v-if="showDevice && deviceInfo" class="device-pre">
        <pre class="muted">{{ deviceInfo }}</pre>
      </div>
    </div>

    <!-- ========== 检查更新 ========== -->
    <div class="card">
      <h3>检查更新</h3>
      <div v-if="!updateSupported">
        <pre class="muted">{{ updateUnsupportedText }}</pre>
      </div>
      <template v-else>
        <input v-model="manifestUrl" class="input" placeholder="manifest.json URL" />
        <p class="field-hint">{{ manifestHint }}</p>
        <div class="btns">
          <button class="btn btn-a" @click="checkUpdate" :disabled="loading">检查更新</button>
          <button v-if="checkResult && checkResult.available" class="btn btn-r" @click="applyUpdate" :disabled="loading">
            安装更新（{{ checkResult.remoteVersion }}）
          </button>
          <button class="btn btn-c" @click="rollbackUpdate" :disabled="loading">回滚上一版本</button>
        </div>
      </template>
      <div v-if="updateStatus" class="status-pre">
        <pre :class="updateIsError ? 'err' : 'ok'">{{ updateStatus }}</pre>
      </div>
    </div>

    <!-- ========== 存储管理 ========== -->
    <div class="card">
      <h3>存储管理 · 占用 {{ storageCount }} 项</h3>
      <pre class="muted">{{ storageKeysText }}</pre>
      <div class="btns" style="margin-top: 10px">
        <button class="btn btn-b" @click="refreshStorage" :disabled="loading">刷新</button>
        <button class="btn btn-c" @click="clearStorage" :disabled="loading">清空全部（二次确认）</button>
      </div>
    </div>

    <!-- ========== 偏好开关 ========== -->
    <div class="card">
      <h3>偏好</h3>
      <div class="pref-row" v-for="p in prefs" :key="p.key">
        <div class="pref-label">
          <div class="pref-name">{{ p.label }}</div>
          <div class="pref-key">{{ p.key }}</div>
        </div>
        <button :class="['toggle', { on: p.value }]" @click="togglePref(p)" :aria-pressed="p.value">
          <span class="knob"></span>
        </button>
      </div>
      <p class="field-hint">开关经 storage.setItem 落盘；重进容器回显。有变更时「保存并关闭」会回传 changed 列表。</p>
    </div>

    <!-- ========== 关闭回传 ========== -->
    <div class="card">
      <h3>关闭回传</h3>
      <div class="btns">
        <button class="btn btn-d" style="flex-basis: 100%" @click="saveAndClose" :disabled="loading">
          保存并关闭{{ changedKeys.length ? `（回传 ${changedKeys.length} 项变更）` : '' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
// 从 coconutWebBox Settings.vue 移植（真实业务试点 Phase 1 首版页面）：
// storage key 加 h5app. 前缀与 demo 模块隔离；样式改用全局 card/btns 体系
import { ref, computed, onMounted } from 'vue'
import { pcall, pcallBoot } from '../lib/pcall'
import { useConfigTick } from '../lib/configTick'

const loading = ref(false)
const environment = ref('web')

const configTick = useConfigTick()

// ---- 关于 ----
const showDevice = ref(false)
const deviceInfo = ref('')
const appInfo = ref(null)
const aboutText = computed(() => {
  void configTick.value
  const e = window.coconut?.env || {}
  const lines = [
    `应用：${e.appName || '(未知)'} ${e.appVersion || ''}`,
    `SDK：v${e.sdkVersion || '?'} · 协议 v${e.hybridVersion || '?'}`
  ]
  if (appInfo.value) {
    lines.push(`包名：${appInfo.value.packageName || '?'}`)
    lines.push(`构建号：${appInfo.value.buildNumber || '?'}`)
  }
  return lines.join('\n')
})

const platformText = computed(() => {
  const envMap = { android: 'Android', ios: 'iOS', harmony: 'HarmonyOS NEXT', web: 'Web（未检测到 Bridge）' }
  return envMap[environment.value] || environment.value
})

// ---- 检查更新 ----
// 默认 127.0.0.1：iOS simulator 的 localhost 即 Mac loopback；
// Harmony 模拟器不共享 Mac loopback，需先 `hdc rport tcp:8000 tcp:8000`；
// Android 模拟器请改 Mac 局域网 IP（或 adb reverse）。
const manifestUrl = ref('http://127.0.0.1:8000/manifest.json')
const updateStatus = ref('')
const updateIsError = ref(false)
const checkResult = ref(null)
const updateSupported = computed(() => {
  void configTick.value
  const c = window.coconut
  return !!(c && c.supports && c.supports('update', 'check'))
})
const updateUnsupportedText = computed(() => {
  void configTick.value
  if (window.coconut?.env?.isiOS) {
    return '当前平台不支持：iOS 受 App Store 审核约束（2.5.2 可执行代码条款），\nupdate 组件为空实现（方法在，业务层返回不支持）。'
  }
  return '当前宿主未注册 update 组件（coconut.supports("update", "check") = false）'
})
const manifestHint = computed(() => {
  if (environment.value === 'ios') return 'iOS simulator：localhost 即 Mac，直接可用'
  if (environment.value === 'harmony') return 'Harmony 模拟器：先 hdc rport tcp:8000 tcp:8000（设备 localhost → Mac）'
  if (environment.value === 'android') return 'Android 模拟器：localhost 是设备自身，改 Mac 局域网 IP 或 adb reverse tcp:8000 tcp:8000'
  return ''
})

async function checkUpdate() {
  updateStatus.value = '检查中...'
  updateIsError.value = false
  checkResult.value = null
  const r = await pcall('update', 'check', { manifestUrl: manifestUrl.value })
  if (r.err) {
    updateIsError.value = true
    updateStatus.value = `检查失败：${r.err.code} ${r.err.message}`
    return
  }
  const d = r.data || {}
  if (d.success === false) {
    updateIsError.value = true
    updateStatus.value = `不支持：${d.message || '业务层返回不支持'}`
    return
  }
  checkResult.value = d
  if (d.available) {
    updateStatus.value = `有新版本：${d.currentVersion} → ${d.remoteVersion}`
    // dialog.confirm 二次确认
    const confirmed = await new Promise(resolve => {
      window.coconut.dialog.confirm(
        '发现新版本', `当前 ${d.currentVersion}，远程 ${d.remoteVersion}，是否安装？`, '安装', '暂不',
        (err, res) => resolve(!err && res && (res.confirm === true || res.confirmed === true || res.success === true))
      )
    })
    if (confirmed) await applyUpdate()
  } else {
    updateStatus.value = `已是最新版本（${d.currentVersion}）`
  }
}

async function applyUpdate() {
  updateStatus.value = '下载安装中...'
  updateIsError.value = false
  const r = await pcall('update', 'apply', {})
  if (r.err) {
    updateIsError.value = true
    updateStatus.value = `安装失败：${r.err.code} ${r.err.message}`
    return
  }
  const d = r.data || {}
  if (d.success === false) {
    updateIsError.value = true
    updateStatus.value = `安装失败：${d.message || '业务层失败'}`
    return
  }
  updateStatus.value = `已安装 v${d.version || checkResult.value?.remoteVersion || '?'}（重启容器生效）`
  window.coconut.dialog.toast('更新完成，重启容器生效', 2, 'bottom', () => {})
}

async function rollbackUpdate() {
  updateStatus.value = '回滚中...'
  updateIsError.value = false
  const r = await pcall('update', 'rollback', {})
  if (r.err || (r.data && r.data.success === false)) {
    updateIsError.value = true
    const m = r.err ? `${r.err.code} ${r.err.message}` : r.data.message
    updateStatus.value = `回滚失败：${m || '无可回滚版本'}`
    return
  }
  updateStatus.value = `已回滚到 v${(r.data && r.data.version) || '?'}（重启容器生效）`
}

// ---- 存储管理 ----
const storageKeys = ref([])
const storageCount = ref(0)
const storageKeysText = computed(() =>
  storageKeys.value.length ? storageKeys.value.join('\n') : '（空）')

async function refreshStorage() {
  loading.value = true
  const r = await pcallBoot('storage', 'getAllKeys', {})
  if (!r.err && r.data) storageKeys.value = r.data.keys || []
  const s = await pcallBoot('storage', 'getSize', {})
  if (!s.err && s.data) storageCount.value = s.data.count ?? storageKeys.value.length
  loading.value = false
}

async function clearStorage() {
  const confirmed = await new Promise(resolve => {
    window.coconut.dialog.confirm(
      '清空存储', `确定清空全部 ${storageCount.value} 项数据？此操作不可恢复。`, '清空', '取消',
      (err, res) => resolve(!err && res && (res.confirm === true || res.confirmed === true || res.success === true))
    )
  })
  if (!confirmed) {
    window.coconut.dialog.toast('已取消', 1, 'center', () => {})
    return
  }
  loading.value = true
  const r = await pcall('storage', 'clear', {})
  loading.value = false
  if (!r.err && r.data && r.data.success) {
    window.coconut.dialog.toast('已清空', 1, 'center', () => {})
    await refreshStorage()
    await loadPrefs()  // 偏好也被清了，回显默认值
  }
}

// ---- 偏好开关（h5app. 前缀与 demo 模块隔离）----
const prefs = ref([
  { key: 'h5app.settings.push', label: '消息推送', value: true, initial: true },
  { key: 'h5app.settings.image', label: '图片自动加载', value: true, initial: true }
])
const changedKeys = computed(() => prefs.value.filter(p => p.value !== p.initial).map(p => p.key))

async function loadPrefs() {
  for (const p of prefs.value) {
    const r = await pcallBoot('storage', 'getItem', { key: p.key })
    if (!r.err && r.data && r.data.value !== null && r.data.value !== undefined) {
      // 布尔以字符串落盘（storage value 语义为 string），'false' / '0' 视为关
      const v = String(r.data.value)
      p.value = !(v === 'false' || v === '0')
    }
    p.initial = p.value
  }
}

async function togglePref(p) {
  const next = !p.value
  const r = await pcall('storage', 'setItem', { key: p.key, value: String(next) })
  if (!r.err && r.data && r.data.success) {
    p.value = next
    refreshStorage()  // keys 面板即时反映落盘
  }
}

// ---- 关闭回传 ----
function saveAndClose() {
  const result = { from: 'h5app-settings', changed: changedKeys.value, ts: Date.now() }
  window.coconut.navigator.close(result, () => {})
}

// ---- 通用 ----
async function loadAppInfo() {
  loading.value = true
  const r = await pcall('device', 'getAppInfo', {})
  loading.value = false
  if (!r.err && r.data) appInfo.value = r.data
}

async function loadDeviceInfo() {
  const r = await pcallBoot('device', 'getInfo', {})
  if (!r.err && r.data) deviceInfo.value = JSON.stringify(r.data, null, 2)
}

onMounted(async () => {
  const coconut = window.coconut
  if (!coconut) return
  if (coconut.environment) environment.value = String(coconut.environment)
  loadDeviceInfo()
  await loadPrefs()
  await refreshStorage()
})
</script>

<style scoped>
.settings-wrap { max-width: 720px; margin: 0 auto; padding: 20px 16px 48px; }
.field-hint { font-size: 12px; color: var(--c-muted); line-height: 1.5; margin: 8px 0; }
.device-pre, .status-pre { margin-top: 10px; }
.device-pre pre, .status-pre pre {
  font-size: 12px; white-space: pre-wrap; word-break: break-all;
  background: #f7f8fa; padding: 10px; border-radius: 6px;
  font-family: "SF Mono", Menlo, Consolas, monospace; margin: 0;
}
.status-pre pre.ok  { color: #00b42c; }
.status-pre pre.err { color: #f53f3f; }

.pref-row {
  display: flex; align-items: center; justify-content: space-between;
  padding: 12px 0;
  border-bottom: 1px solid var(--c-border);
}
.pref-row:last-of-type { border-bottom: none; }
.pref-name { font-size: 15px; font-weight: 500; }
.pref-key { font-size: 11px; color: var(--c-muted); font-family: "SF Mono", Menlo, monospace; margin-top: 2px; }
.toggle {
  flex: none; width: 52px; height: 30px; min-width: 52px;
  border-radius: 999px; background: #dcdfe6; position: relative;
  transition: background .2s; border: none;
}
.toggle.on { background: #00b42c; }
.toggle .knob {
  position: absolute; top: 3px; left: 3px; width: 24px; height: 24px;
  border-radius: 50%; background: #fff; transition: left .2s;
  display: block;
}
.toggle.on .knob { left: 25px; }
</style>
