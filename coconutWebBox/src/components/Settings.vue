<template>
  <div class="demo-container">
    <h1>⚙️ 设置</h1>
    <p class="hint">真实业务页试点：storage 持久化 / dialog 二次确认 / navigator 关闭回传 / 热更新全链路。</p>

    <div :class="['platform', { web: environment === 'web' }]">
      <span class="dot"></span>
      <span>{{ platformText }}</span>
    </div>

    <!-- ========== 关于 ========== -->
    <section>
      <h2>关于</h2>
      <div class="panel">
        <pre class="muted">{{ aboutText }}</pre>
      </div>
      <div class="btns">
        <button class="btn-a" @click="loadAppInfo" :disabled="loading">应用信息（device.getAppInfo）</button>
        <button class="btn-b" @click="showDevice = !showDevice">{{ showDevice ? '收起设备信息' : '展开设备信息（device.getInfo）' }}</button>
      </div>
      <div v-if="showDevice && deviceInfo" class="panel" style="margin-top: 10px">
        <pre class="muted">{{ deviceInfo }}</pre>
      </div>
    </section>

    <!-- ========== 检查更新 ========== -->
    <section>
      <h2>检查更新</h2>
      <div v-if="!updateSupported" class="panel">
        <pre class="muted">{{ updateUnsupportedText }}</pre>
      </div>
      <template v-else>
        <input v-model="manifestUrl" class="net-input" placeholder="manifest.json URL" />
        <p class="hint" style="margin-bottom: 8px">{{ manifestHint }}</p>
        <div class="btns">
          <button class="btn-a" @click="checkUpdate" :disabled="loading">检查更新</button>
          <button v-if="checkResult && checkResult.available" class="btn-r" @click="applyUpdate" :disabled="loading">
            安装更新（{{ checkResult.remoteVersion }}）
          </button>
          <button class="btn-c" @click="rollbackUpdate" :disabled="loading">回滚上一版本</button>
        </div>
        <div v-if="updateStatus" class="panel" style="margin-top: 10px">
          <pre :class="updateIsError ? 'err' : 'ok'">{{ updateStatus }}</pre>
        </div>
      </template>
    </section>

    <!-- ========== 存储管理 ========== -->
    <section>
      <h2>存储管理</h2>
      <div class="panel">
        <h3>占用 {{ storageCount }} 项</h3>
        <pre class="muted">{{ storageKeysText }}</pre>
      </div>
      <div class="btns">
        <button class="btn-b" @click="refreshStorage" :disabled="loading">刷新</button>
        <button class="btn-c" @click="clearStorage" :disabled="loading">清空全部（二次确认）</button>
      </div>
    </section>

    <!-- ========== 偏好开关 ========== -->
    <section>
      <h2>偏好</h2>
      <div class="pref-row" v-for="p in prefs" :key="p.key">
        <div class="pref-label">
          <div class="pref-name">{{ p.label }}</div>
          <div class="pref-key">{{ p.key }}</div>
        </div>
        <button :class="['toggle', { on: p.value }]" @click="togglePref(p)" :aria-pressed="p.value">
          <span class="knob"></span>
        </button>
      </div>
      <p class="hint" style="margin-top: 8px">开关经 storage.setItem 落盘；重进容器回显。有变更时「保存并关闭」会回传 changed 列表。</p>
    </section>

    <!-- ========== 关闭回传 ========== -->
    <section>
      <h2>关闭回传</h2>
      <div class="btns">
        <button class="btn-d" style="flex-basis: 100%" @click="saveAndClose" :disabled="loading">
          保存并关闭{{ changedKeys.length ? `（回传 ${changedKeys.length} 项变更）` : '' }}
        </button>
      </div>
    </section>

    <div class="panel">
      <h3>最近一次请求（H5 → 原生）</h3>
      <pre class="muted">{{ lastRequest || '—' }}</pre>
    </div>
    <div class="panel">
      <h3>原生返回的响应（原生 → H5）</h3>
      <pre :class="responseClass">{{ lastResponse || '—' }}</pre>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'

const loading = ref(false)
const environment = ref('web')
const lastRequest = ref('')
const lastResponse = ref('')
const lastIsError = ref(false)

// ---- 关于 ----
const showDevice = ref(false)
const deviceInfo = ref('')
const appInfo = ref(null)
const aboutText = computed(() => {
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
  const c = window.coconut
  return !!(c && c.supports && c.supports('update', 'check'))
})
const updateUnsupportedText = computed(() => {
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
  const r = await pcall('storage', 'getAllKeys', {})
  if (!r.err && r.data) storageKeys.value = r.data.keys || []
  const s = await pcall('storage', 'getSize', {})
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

// ---- 偏好开关 ----
const prefs = ref([
  { key: 'settings.push', label: '消息推送', value: true, initial: true },
  { key: 'settings.image', label: '图片自动加载', value: true, initial: true }
])
const changedKeys = computed(() => prefs.value.filter(p => p.value !== p.initial).map(p => p.key))

async function loadPrefs() {
  for (const p of prefs.value) {
    const r = await pcall('storage', 'getItem', { key: p.key })
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
  const result = { from: 'settings', changed: changedKeys.value, ts: Date.now() }
  setRequest('navigator', 'close', { result })
  window.coconut.navigator.close(result, (err, data) => setResponse(err, data))
}

// ---- 通用 ----
const responseClass = computed(() => {
  if (!lastResponse.value || lastResponse.value === '—') return 'muted'
  return lastIsError.value ? 'err' : 'ok'
})

function setRequest(component, fn, params) {
  lastRequest.value = JSON.stringify({ component, function: fn, params }, null, 2)
}

function setResponse(err, data) {
  lastIsError.value = !!err
  lastResponse.value = JSON.stringify(err ? { error: err } : { data }, null, 2)
}

function pcall(component, fn, params) {
  setRequest(component, fn, params)
  return new Promise(resolve => {
    window.coconut.call(component, fn, params || {}, (err, data) => {
      setResponse(err, data)
      resolve({ err, data })
    })
  })
}

async function loadAppInfo() {
  loading.value = true
  const r = await pcall('device', 'getAppInfo', {})
  loading.value = false
  if (!r.err && r.data) appInfo.value = r.data
}

async function loadDeviceInfo() {
  const r = await pcall('device', 'getInfo', {})
  if (!r.err && r.data) deviceInfo.value = JSON.stringify(r.data, null, 2)
}

onMounted(async () => {
  const coconut = window.coconut
  if (!coconut) {
    lastResponse.value = 'coconut.js 未加载'
    lastIsError.value = true
    return
  }
  try {
    coconut.init({ debug: true })
    environment.value = String(coconut.environment || coconut.env?.platform || 'unknown')
  } catch (e) {
    console.error('初始化出错:', e)
  }
  loadDeviceInfo()
  await loadPrefs()
  await refreshStorage()
})
</script>

<style scoped>
/* 与 Demo.vue 同一套视觉（容器/panel/按钮），另加偏好开关行 */
.demo-container {
  font-family: -apple-system, "PingFang SC", "Helvetica Neue", sans-serif;
  padding: 20px 16px 48px;
  background: #f5f6f8;
  color: #1f2329;
  min-height: 100vh;
}

h1 { font-size: 20px; margin-bottom: 4px; font-weight: 700; }
.hint { font-size: 13px; color: #8a8f99; margin-bottom: 12px; line-height: 1.5; }

.platform {
  display: inline-flex; align-items: center; gap: 6px;
  background: #eef4ff; color: #3370ff; border: 1px solid #cfe0ff;
  padding: 6px 14px; border-radius: 999px; font-size: 13px; font-weight: 600;
  margin-bottom: 16px;
}
.platform.web { background: #fff3e8; color: #ff7d00; border-color: #ffd6a8; }
.dot { width: 8px; height: 8px; border-radius: 50%; background: currentColor; }

section { margin-bottom: 20px; }
section > h2 {
  font-size: 13px; color: #8a8f99; font-weight: 600;
  text-transform: uppercase; letter-spacing: .5px; margin-bottom: 10px;
}
.btns { display: flex; flex-wrap: wrap; gap: 10px; }
.net-input {
  width: 100%; box-sizing: border-box; height: 40px; margin-bottom: 10px;
  padding: 0 12px; font-size: 13px; font-family: "SF Mono", Menlo, monospace;
  border: 1px solid #dcdfe6; border-radius: 8px; background: #fff; color: #1f2329;
  outline: none;
}
.net-input:focus { border-color: #3370ff; }
button {
  flex: 1; min-width: calc(50% - 5px); height: 46px;
  font-size: 15px; border: none; border-radius: 10px;
  color: #fff; cursor: pointer; transition: opacity .15s;
  font-weight: 500;
}
button:active:not(:disabled) { opacity: .8; }
button:disabled { opacity: .5; cursor: not-allowed; }
.btn-a { background: #3370ff; }
.btn-b { background: #00b42c; }
.btn-r { background: #ff7d00; }
.btn-d { background: #722ed1; }
.btn-c { background: #f53f3f; }

.panel {
  background: #fff; border-radius: 10px; padding: 14px;
  margin-bottom: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.04);
}
.panel h3 { font-size: 13px; color: #8a8f99; margin-bottom: 8px; font-weight: 600; }
.panel pre {
  font-size: 12px; white-space: pre-wrap; word-break: break-all;
  background: #f7f8fa; padding: 10px; border-radius: 6px; min-height: 24px;
  font-family: "SF Mono", Menlo, Consolas, monospace; color: #1f2329;
  margin: 0;
}
.panel pre.ok    { color: #00b42c; }
.panel pre.err   { color: #f53f3f; }
.panel pre.muted { color: #8a8f99; }

/* 偏好开关行 */
.pref-row {
  display: flex; align-items: center; justify-content: space-between;
  background: #fff; border-radius: 10px; padding: 14px;
  margin-bottom: 10px; box-shadow: 0 1px 3px rgba(0,0,0,0.04);
}
.pref-name { font-size: 15px; font-weight: 500; }
.pref-key { font-size: 11px; color: #8a8f99; font-family: "SF Mono", Menlo, monospace; margin-top: 2px; }
.toggle {
  flex: none; width: 52px; height: 30px; min-width: 52px;
  border-radius: 999px; background: #dcdfe6; position: relative;
  transition: background .2s;
}
.toggle.on { background: #00b42c; }
.toggle .knob {
  position: absolute; top: 3px; left: 3px; width: 24px; height: 24px;
  border-radius: 50%; background: #fff; transition: left .2s;
  display: block;
}
.toggle.on .knob { left: 25px; }
</style>
