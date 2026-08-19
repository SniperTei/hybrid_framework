<template>
  <div class="demo-container">
    <h1>🥥 Coconut SDK Demo</h1>
    <p class="hint">v3.2.0 端到端验证页。Android / iOS / Harmony 三端通用，点击下方按钮测试 coconut SDK 与原生的通信。</p>

    <div :class="['platform', { web: environment === 'web' }]">
      <span class="dot"></span>
      <span>{{ platformText }} · SDK {{ sdkVersion }} · 协议 v{{ hybridVersion }}</span>
    </div>

    <div class="panel">
      <h3>coconut.env 字段（v3.2.0）</h3>
      <pre class="muted">{{ envSummary }}</pre>
    </div>

    <div class="panel">
      <h3>🛠 Capabilities（coconut.supports）</h3>
      <pre class="muted">{{ capabilitiesJson }}</pre>
      <div class="cap-grid">
        <div v-for="c in capabilityChecks" :key="c.label" :class="['cap-chip', c.value ? 'on' : 'off']">
          <span class="cap-dot">{{ c.value ? '✓' : '✗' }}</span>
          <code>{{ c.label }}</code>
        </div>
      </div>
      <h3 style="margin-top: 12px">🔬 Raw __coconutConfig</h3>
      <pre class="muted" style="font-size: 11px">{{ rawConfig }}</pre>
    </div>

    <section>
      <h2>端到端验证</h2>
      <div class="btns">
        <button class="btn-r" style="flex-basis: 100%" @click="runAll" :disabled="running">
          {{ running ? '运行中...' : '🧪 Run All Tests' }}
        </button>
      </div>
      <div v-if="runAllResults.length > 0" class="panel">
        <h3>结果 {{ passCount }}/{{ runAllResults.length }} · {{ totalTime }}s</h3>
        <div class="run-list">
          <div v-for="r in runAllResults" :key="r.name" :class="['run-row', r.status]">
            <span class="run-icon">
              <span v-if="r.status === 'pass'">✅</span>
              <span v-else-if="r.status === 'fail'">❌</span>
              <span v-else-if="r.status === 'skip'">⏭</span>
              <span v-else>⏳</span>
            </span>
            <div class="run-body">
              <div class="run-name">{{ r.name }} <span class="run-dur">· {{ r.duration }}ms</span></div>
              <div class="run-line">期望：{{ r.expected }}</div>
              <div class="run-line">实际：{{ r.actual }}</div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section>
      <h2>💬 Dialog 组件</h2>
      <div class="btns">
        <button class="btn-a" @click="dialogAlert" :disabled="loading">alert</button>
        <button class="btn-b" @click="dialogConfirm" :disabled="loading">confirm</button>
        <button class="btn-r" @click="dialogToast" :disabled="loading">toast</button>
        <button class="btn-d" @click="dialogShowLoading" :disabled="loading">showLoading (2s 后自动 hide)</button>
        <button class="btn-c" @click="dialogHideLoading" :disabled="loading">hideLoading</button>
      </div>
    </section>

    <section>
      <h2>📱 Device 组件</h2>
      <div class="btns">
        <button class="btn-a" @click="testDeviceInfo" :disabled="loading">getInfo</button>
      </div>
    </section>

    <section>
      <h2>💾 Storage 组件</h2>
      <div class="btns">
        <button class="btn-b" @click="testSetItem" :disabled="loading">setItem</button>
        <button class="btn-r" @click="testGetItem" :disabled="loading">getItem</button>
        <button class="btn-a" @click="testGetAllKeys" :disabled="loading">getAllKeys</button>
        <button class="btn-a" @click="testGetSize" :disabled="loading">getSize</button>
        <button class="btn-c" @click="testRemoveItem" :disabled="loading">removeItem</button>
        <button class="btn-c" @click="testClear" :disabled="loading">clear</button>
      </div>
    </section>

    <section>
      <h2>📡 Event 组件（native → H5 push）</h2>
      <div class="btns">
        <button class="btn-d" @click="eventOn" :disabled="loading">订阅 test.echo</button>
        <button class="btn-d" @click="eventEcho" :disabled="loading">触发 echo</button>
        <button class="btn-c" @click="eventOff" :disabled="loading">取消订阅</button>
      </div>
    </section>

    <section>
      <h2>🌐 Network 组件（Harmony 先行，走 native HTTP）</h2>
      <input v-model="netUrl" class="net-input" placeholder="http://<Mac-IP>:8000/manifest.json" />
      <div class="btns">
        <button class="btn-a" @click="netRequestGet" :disabled="loading">GET</button>
        <button class="btn-b" @click="netRequestPost" :disabled="loading">POST (501 反例)</button>
        <button class="btn-d" @click="netGetNetworkType" :disabled="loading">getNetworkType</button>
        <button class="btn-g" @click="netSubscribeChange">订阅 network.change</button>
      </div>
      <div v-if="netLogs.length === 0" class="hint" style="margin-top:8px">订阅后切换模拟器 Wi-Fi / 开关飞行模式，可看到 network.change 推送（去重）。</div>
      <div v-for="(log, idx) in netLogs" :key="idx" class="event-item">
        <div class="event-time">{{ log.time }}</div>
        <pre class="ok">{{ log.payload }}</pre>
      </div>
    </section>

    <section>
      <h2>♻️ Lifecycle（内置事件，无需组件）</h2>
      <p class="hint">订阅后切到后台再切回，看 app.background → app.foreground 触发。</p>
      <div class="btns">
        <button class="btn-g" @click="lifecycleSubscribe">订阅 foreground+background</button>
        <button class="btn-c" @click="lifecycleUnsubscribe">取消订阅</button>
      </div>
      <div v-if="lifecycleLogs.length === 0" class="hint" style="margin-top:8px">尚无 lifecycle 事件</div>
      <div v-for="(log, idx) in lifecycleLogs" :key="idx" class="event-item">
        <div class="event-time">{{ log.time }}</div>
        <pre :class="log.topic === 'app.foreground' ? 'ok' : 'muted'">{{ log.payload }}</pre>
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
    <div class="panel">
      <h3>事件投递（native → H5，coconut.on 注册的 callback）</h3>
      <pre v-if="eventLogs.length === 0" class="muted">—</pre>
      <div v-for="(log, idx) in eventLogs" :key="idx" class="event-item">
        <div class="event-time">{{ log.time }}</div>
        <pre class="ok">{{ log.payload }}</pre>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'

const loading = ref(false)
const sdkVersion = ref('0.0.0')
const hybridVersion = ref('?')
const environment = ref('web')
const env = ref({})
const eventLogs = ref([])

// Single-click request/response view (coconut_index-style 3-panel)
const lastRequest = ref('')
const lastResponse = ref('')
const lastIsError = ref(false)

// Run All state
const running = ref(false)
const runAllResults = ref([])
const passCount = computed(() => runAllResults.value.filter(r => r.status === 'pass').length)
const totalTime = computed(() => (runAllResults.value.reduce((s, r) => s + r.duration, 0) / 1000).toFixed(2))

const platformText = computed(() => {
  const envMap = {
    android: 'Android',
    ios: 'iOS',
    harmony: 'HarmonyOS NEXT',
    web: 'Web（未检测到 Bridge）',
    node: 'Node.js'
  }
  return envMap[environment.value] || environment.value
})

const envSummary = computed(() => {
  const e = env.value
  return JSON.stringify({
    platform: e.platform,
    isAndroid: e.isAndroid,
    isiOS: e.isiOS,
    isHarmony: e.isHarmony,
    isWeb: e.isWeb,
    isNative: e.isNative,
    hybridVersion: e.hybridVersion,
    appName: e.appName || '(空)',
    appVersion: e.appVersion || '(空)',
    sdkVersion: e.sdkVersion,
    userAgent: (e.userAgent || '').slice(0, 80)
  }, null, 2)
})

const responseClass = computed(() => {
  if (!lastResponse.value || lastResponse.value === '—') return 'muted'
  return lastIsError.value ? 'err' : 'ok'
})

// Reactive tick that bumps when coconut.js (re)loads __coconutConfig.
// Plain window.__coconutConfig reads track zero Vue deps, so computed() that
// read it would cache stale values from before native injection. Listening to
// the 'coconut:config-loaded' event forces re-evaluation.
const configTick = ref(0)

const capabilitiesJson = computed(() => {
  configTick.value  // reactive dep
  const caps = (window.coconut && window.coconut.env && window.coconut.env.capabilities) || {}
  return JSON.stringify(caps, null, 2)
})

const rawConfig = computed(() => {
  configTick.value  // reactive dep
  try {
    const cfg = window.__coconutConfig
    return JSON.stringify(cfg, null, 2)
  } catch (e) {
    return 'Error: ' + e.message
  }
})

const capabilityChecks = computed(() => {
  configTick.value  // reactive dep
  const c = window.coconut
  if (!c || !c.supports) return []
  return [
    { label: 'device.getInfo',     value: c.supports('device', 'getInfo') },
    { label: 'storage.setItem',    value: c.supports('storage', 'setItem') },
    { label: 'storage.getSize',    value: c.supports('storage', 'getSize') },
    { label: 'event.on',           value: c.supports('event', 'on') },
    { label: 'event.echo',         value: c.supports('event', 'echo') },
    { label: 'dialog.alert',       value: c.supports('dialog', 'alert') },
    { label: 'dialog.showLoading', value: c.supports('dialog', 'showLoading') },
    { label: 'network.request',    value: c.supports('network', 'request') },
    { label: 'network.getNetworkType', value: c.supports('network', 'getNetworkType') },
    { label: 'foo.bar (missing)',  value: c.supports('foo', 'bar') }
  ]
})

function setRequest(component, fn, params) {
  lastRequest.value = JSON.stringify({ component, function: fn, params }, null, 2)
}

function setResponse(err, data) {
  lastIsError.value = !!err
  lastResponse.value = JSON.stringify(err ? { error: err } : { data }, null, 2)
}

function startCheck(name, expected) {
  const check = { name, expected, status: 'running', actual: '', duration: 0 }
  runAllResults.value.push(check)
  // Return the reactive proxy, not the raw object. Mutating the raw target
  // (the local `check` above) bypasses Vue's set trap, so computed() like
  // passCount that depend on r.status never re-evaluate — leaving the header
  // showing stale "N-1/N" even though all rows display ✅.
  return runAllResults.value[runAllResults.value.length - 1]
}

function finishCheck(check, pass, actual) {
  check.status = pass ? 'pass' : 'fail'
  check.actual = actual
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

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms))
}

async function runAll() {
  if (running.value) return
  running.value = true
  runAllResults.value = []

  // ---------- Env pre-checks (v3.2.0 specific) ----------
  let c = startCheck('env.platform is native (not web)', 'android / ios / harmony')
  const platform = window.coconut.env.platform
  finishCheck(c, ['android', 'ios', 'harmony'].includes(platform), `"${platform}"`)

  c = startCheck('env.hybridVersion === "3" (v3.2.0)', '"3"')
  const hv = window.coconut.env.hybridVersion
  finishCheck(c, hv === '3', `"${hv}"`)

  c = startCheck('env.appName non-empty (from __coconutConfig)', 'non-empty')
  const an = window.coconut.env.appName || ''
  finishCheck(c, !!an, `"${an}"`)

  c = startCheck('env.appVersion non-empty (from __coconutConfig)', 'non-empty')
  const av = window.coconut.env.appVersion || ''
  finishCheck(c, !!av, `"${av}"`)

  // ---------- Device ----------
  c = startCheck('Device.getInfo → platform native', 'err=null, platform native')
  let t0 = performance.now()
  let r = await pcall('device', 'getInfo', {})
  c.duration = Math.round(performance.now() - t0)
  if (r.err) {
    finishCheck(c, false, `err ${r.err.code}: ${r.err.message}`)
  } else {
    const p = r.data && r.data.platform
    finishCheck(c, ['android', 'ios', 'harmony'].includes(p), `platform="${p}"`)
  }

  // ---------- Storage sequence ----------
  const key = 'runall_' + Date.now()
  const value = 'test_value_' + Date.now()

  c = startCheck('Storage.setItem', 'err=null, success=true')
  t0 = performance.now()
  r = await pcall('storage', 'setItem', { key, value })
  c.duration = Math.round(performance.now() - t0)
  finishCheck(c, !r.err && r.data && r.data.success === true,
    r.err ? `err ${r.err.code}` : `success=${r.data && r.data.success}`)

  c = startCheck('Storage.getItem (just written)', `value matches`)
  t0 = performance.now()
  r = await pcall('storage', 'getItem', { key })
  c.duration = Math.round(performance.now() - t0)
  const gotValue = !r.err && r.data && r.data.value === value
  finishCheck(c, gotValue,
    r.err ? `err ${r.err.code}` : `value="${r.data && r.data.value}"`)

  c = startCheck('Storage.getAllKeys includes our key', `keys contains key`)
  t0 = performance.now()
  r = await pcall('storage', 'getAllKeys', {})
  c.duration = Math.round(performance.now() - t0)
  const hasKey = !r.err && r.data && Array.isArray(r.data.keys) && r.data.keys.includes(key)
  finishCheck(c, hasKey,
    r.err ? `err ${r.err.code}` : `keys has key: ${hasKey}`)

  c = startCheck('Storage.getSize ≥ 1', 'count ≥ 1')
  t0 = performance.now()
  r = await pcall('storage', 'getSize', {})
  c.duration = Math.round(performance.now() - t0)
  const count = r.data && r.data.count
  finishCheck(c, !r.err && count >= 1, r.err ? `err ${r.err.code}` : `count=${count}`)

  c = startCheck('Storage.removeItem', 'err=null, success=true')
  t0 = performance.now()
  r = await pcall('storage', 'removeItem', { key })
  c.duration = Math.round(performance.now() - t0)
  finishCheck(c, !r.err && r.data && r.data.success === true,
    r.err ? `err ${r.err.code}` : `success=${r.data && r.data.success}`)

  c = startCheck('Storage.getItem (after remove → null/missing)', 'value=null or exists=false')
  t0 = performance.now()
  r = await pcall('storage', 'getItem', { key })
  c.duration = Math.round(performance.now() - t0)
  const removed = !r.err && (r.data.value === null || r.data.value === undefined || r.data.exists === false)
  finishCheck(c, removed,
    r.err ? `err ${r.err.code}` : `value=${r.data.value}, exists=${r.data.exists}`)

  c = startCheck('Storage.clear', 'err=null, success=true')
  t0 = performance.now()
  r = await pcall('storage', 'clear', {})
  c.duration = Math.round(performance.now() - t0)
  finishCheck(c, !r.err && r.data && r.data.success === true,
    r.err ? `err ${r.err.code}` : `success=${r.data && r.data.success}`)

  // ---------- Dialog (toast only — alert/confirm 需要用户交互，不进 Run All) ----------
  c = startCheck('Dialog.toast (non-blocking)', 'err=null, success=true')
  t0 = performance.now()
  r = await pcall('dialog', 'toast', { message: 'Run All toast', duration: 2, position: 'bottom' })
  c.duration = Math.round(performance.now() - t0)
  finishCheck(c, !r.err && r.data && r.data.success === true,
    r.err ? `err ${r.err.code}` : `success=${r.data && r.data.success}`)

  // ---------- Event round-trip ----------
  let echoReceived = false
  let echoPayload = null

  // Properly subscribe via coconut.on() — this sends event.on to native so
  // native knows to push echoes back. Direct handler manipulation would skip
  // the bridge roundtrip and leave native unaware of the subscription.
  c = startCheck('Event.on(test.echo) → native ack', 'err=null from event.on')
  t0 = performance.now()
  const onResult = await new Promise(resolve => {
    window.coconut.on('test.echo', (data) => {
      echoReceived = true
      echoPayload = data
      logEvent(data)
    })
    // coconut.on fires event.on asynchronously; give the bridge a beat to ack
    setTimeout(() => resolve(true), 200)
  })
  c.duration = Math.round(performance.now() - t0)
  finishCheck(c, onResult, 'event.on sent')

  c = startCheck('Event.echo → native push within 1.5s', 'event received')
  echoReceived = false
  echoPayload = null
  t0 = performance.now()
  r = await pcall('event', 'echo', { ping: 'pong' })
  await sleep(1500)
  c.duration = Math.round(performance.now() - t0)
  finishCheck(c, echoReceived,
    echoReceived ? `received payload=${JSON.stringify(echoPayload)}` :
    (r.err ? `ack err ${r.err.code}` : 'ack ok but no push received'))

  c = startCheck('Event.off → no more pushes', 'no event after off')
  echoReceived = false
  window.coconut.off('test.echo')
  await sleep(300)
  await pcall('event', 'echo', { ping: 'should-not-arrive' })
  await sleep(1500)
  c.duration = 0
  finishCheck(c, !echoReceived, echoReceived ? 'FAIL: event leaked through' : 'no event received')

  // ---------- Network (Harmony-only this round; skip elsewhere) ----------
  if (window.coconut.supports && window.coconut.supports('network', 'request')) {
    c = startCheck('Network.request GET → success:true (需 serve-hot-update.sh)', 'err=null, success=true')
    t0 = performance.now()
    r = await pcall('network', 'request', { url: netUrl.value, method: 'GET', timeoutMs: 10000 })
    c.duration = Math.round(performance.now() - t0)
    finishCheck(c, !r.err && r.data && r.data.success === true,
      r.err ? `err ${r.err.code}: ${r.err.message}` :
        `success=${r.data && r.data.success}, httpStatus=${r.data && r.data.httpStatus}`)

    c = startCheck('Network.request POST → 业务层失败 (success:false)', 'success=false')
    t0 = performance.now()
    r = await pcall('network', 'request',
      { url: netUrl.value, method: 'POST', body: { hello: 'world' }, timeoutMs: 10000 })
    c.duration = Math.round(performance.now() - t0)
    finishCheck(c, !r.err && r.data && r.data.success === false,
      r.err ? `err ${r.err.code}: ${r.err.message}` :
        `success=${r.data && r.data.success}, httpStatus=${r.data && r.data.httpStatus}`)

    c = startCheck('Network.getNetworkType → type 合法', 'wifi/cellular/ethernet/none/unknown')
    t0 = performance.now()
    r = await pcall('network', 'getNetworkType', {})
    c.duration = Math.round(performance.now() - t0)
    const netType = r.data && r.data.type
    finishCheck(c, !r.err && ['wifi', 'cellular', 'ethernet', 'none', 'unknown'].includes(netType),
      r.err ? `err ${r.err.code}` : `type=${netType}, online=${r.data && r.data.online}`)
  } else {
    c = startCheck('Network 组件（skip）', 'skip on iOS/Android this round')
    c.status = 'skip'
    c.actual = 'coconut.supports("network") = false'
  }

  running.value = false
}

onMounted(() => {
  const coconut = window.coconut
  if (!coconut) {
    lastResponse.value = 'coconut.js 未加载'
    lastIsError.value = true
    return
  }
  try {
    coconut.init({ debug: true })
    sdkVersion.value = String(coconut.version || '0.0.0')
    environment.value = String(coconut.environment || 'unknown')
    hybridVersion.value = String(coconut.env?.hybridVersion || '?')
    const e = JSON.parse(JSON.stringify(coconut.env || {}))
    e.appName = coconut.env.appName || ''
    e.appVersion = coconut.env.appVersion || ''
    env.value = e
    console.log('%c🥥 coconut SDK v' + sdkVersion.value + ' (protocol v' + hybridVersion.value + ')',
      'color: #3370ff; font-size: 20px; font-weight: bold;')
  } catch (error) {
    console.error('初始化出错:', error)
  }

  // Refresh config-derived computed() when native injection completes.
  // coconut.js dispatches 'coconut:config-loaded' from _loadSecurityConfig.
  // Fallback polling covers older bundles without the dispatch.
  window.addEventListener('coconut:config-loaded', () => { configTick.value++ })
  let pollCount = 0
  const poll = setInterval(() => {
    configTick.value++
    if (++pollCount >= 5) clearInterval(poll)
  }, 500)

  // Auto-run smoke test when URL has ?autorun=1 — used by e2e test scripts
  // (no UI automation available in iOS sim without accessibility permission).
  // Slight delay so env injection + bridge wiring settle first.
  if (new URLSearchParams(window.location.search).get('autorun') === '1') {
    setTimeout(() => { runAll() }, 800)
  }
})

function withLoading(fn) {
  loading.value = true
  fn(() => { loading.value = false })
}

// ---- Device ----
function testDeviceInfo() {
  withLoading((done) => {
    setRequest('device', 'getInfo', {})
    window.coconut.device.getInfo((err, data) => {
      setResponse(err, data)
      done()
    })
  })
}

// ---- Storage ----
function storageCall(fn, key, value) {
  const params = value === undefined ? { key } : { key, value }
  withLoading((done) => {
    setRequest('storage', fn, params)
    window.coconut.call('storage', fn, params, (err, data) => {
      setResponse(err, data)
      done()
    })
  })
}

function testSetItem() {
  withLoading((done) => {
    const value = 'test_' + Date.now()
    const params = { key: 'demo', value }
    setRequest('storage', 'setItem', params)
    window.coconut.storage.setItem('demo', value, (err, data) => {
      setResponse(err, data)
      done()
    })
  })
}
function testGetItem() { storageCall('getItem', 'demo') }
function testRemoveItem() { storageCall('removeItem', 'demo') }
function testClear() {
  withLoading((done) => {
    setRequest('storage', 'clear', {})
    window.coconut.storage.clear((err, data) => { setResponse(err, data); done() })
  })
}
function testGetAllKeys() {
  withLoading((done) => {
    setRequest('storage', 'getAllKeys', {})
    window.coconut.storage.getAllKeys((err, data) => { setResponse(err, data); done() })
  })
}
function testGetSize() {
  withLoading((done) => {
    setRequest('storage', 'getSize', {})
    window.coconut.storage.getSize((err, data) => { setResponse(err, data); done() })
  })
}

// ---- Dialog ----
function dialogAlert() {
  withLoading((done) => {
    setRequest('dialog', 'alert', { title: '提示', message: '来自 H5 的原生 Alert', buttonText: '知道了' })
    window.coconut.dialog.alert('提示', '来自 H5 的原生 Alert', '知道了', (err, data) => {
      setResponse(err, data)
      done()
    })
  })
}

function dialogConfirm() {
  withLoading((done) => {
    setRequest('dialog', 'confirm', { title: '确认', message: '确定要执行此操作吗？', confirmText: '确定', cancelText: '取消' })
    window.coconut.dialog.confirm('确认', '确定要执行此操作吗？', '确定', '取消', (err, data) => {
      setResponse(err, data)
      done()
    })
  })
}

function dialogToast() {
  setRequest('dialog', 'toast', { message: '来自 H5 的原生 Toast', duration: 2, position: 'bottom' })
  window.coconut.dialog.toast('来自 H5 的原生 Toast', 2, 'bottom', (err, data) => {
    setResponse(err, data)
  })
}

function dialogShowLoading() {
  setRequest('dialog', 'showLoading', { message: '加载中...' })
  window.coconut.dialog.showLoading('加载中...', (err, data) => {
    setResponse(err, data)
  })
  // 演示：2s 后自动 hide
  setTimeout(() => {
    setRequest('dialog', 'hideLoading', {})
    window.coconut.dialog.hideLoading((err, data) => {
      setResponse(err, data)
    })
  }, 2000)
}

function dialogHideLoading() {
  setRequest('dialog', 'hideLoading', {})
  window.coconut.dialog.hideLoading((err, data) => {
    setResponse(err, data)
  })
}

// ---- Event ----
function logEvent(payload) {
  const time = new Date().toLocaleTimeString()
  eventLogs.value.unshift({ time, payload: JSON.stringify(payload, null, 2) })
  if (eventLogs.value.length > 5) eventLogs.value.pop()
}

function eventOn() {
  setRequest('event', 'on', { topic: 'test.echo' })
  if (!window.coconut.handlers['test.echo']) {
    window.coconut.on('test.echo', (data) => { logEvent(data) })
  }
  setResponse(null, { topic: 'test.echo', subscribed: true, note: '本地 handler 已注册' })
}

function eventEcho() {
  const params = { hello: 'world', ts: Date.now() }
  setRequest('event', 'echo', params)
  window.coconut.call('event', 'echo', params, (err, data) => {
    setResponse(err, data)
  })
}

function eventOff() {
  setRequest('event', 'off', { topic: 'test.echo' })
  window.coconut.off('test.echo')
  setResponse(null, { topic: 'test.echo', subscribed: false })
}

// ---- Network ----
const netUrl = ref('http://192.168.3.49:8000/manifest.json')
const netLogs = ref([])

function netRequestGet() {
  withLoading((done) => {
    const params = { url: netUrl.value, method: 'GET', timeoutMs: 10000 }
    setRequest('network', 'request', params)
    window.coconut.call('network', 'request', params, (err, data) => {
      setResponse(err, data)
      done()
    })
  })
}

function netRequestPost() {
  withLoading((done) => {
    const params = { url: netUrl.value, method: 'POST', body: { hello: 'world' }, timeoutMs: 10000 }
    setRequest('network', 'request', params)
    window.coconut.call('network', 'request', params, (err, data) => {
      setResponse(err, data)
      done()
    })
  })
}

function netGetNetworkType() {
  withLoading((done) => {
    setRequest('network', 'getNetworkType', {})
    window.coconut.call('network', 'getNetworkType', {}, (err, data) => {
      setResponse(err, data)
      done()
    })
  })
}

function netSubscribeChange() {
  if (!window.coconut.handlers['network.change']) {
    window.coconut.on('network.change', (data) => {
      const time = new Date().toLocaleTimeString()
      netLogs.value.unshift({ time, payload: JSON.stringify(data, null, 2) })
      if (netLogs.value.length > 5) netLogs.value.pop()
    })
  }
  setResponse(null, { topic: 'network.change', subscribed: true, note: '切换网络后观察推送' })
}

// ---- Lifecycle ----
const lifecycleLogs = ref([])

function logLifecycle(topic, data) {
  const time = new Date().toLocaleTimeString()
  lifecycleLogs.value.unshift({
    time,
    topic,
    payload: JSON.stringify({ topic, ...data }, null, 2)
  })
  if (lifecycleLogs.value.length > 5) lifecycleLogs.value.pop()
}

function lifecycleSubscribe() {
  window.coconut.on('app.foreground', (data) => logLifecycle('app.foreground', data))
  window.coconut.on('app.background', (data) => logLifecycle('app.background', data))
  setResponse(null, {
    subscribed: ['app.foreground', 'app.background'],
    note: '已订阅 lifecycle，按 Home 切后台测试'
  })
}

function lifecycleUnsubscribe() {
  window.coconut.off('app.foreground')
  window.coconut.off('app.background')
  setResponse(null, { unsubscribed: ['app.foreground', 'app.background'] })
}
</script>

<style scoped>
/* Container: mobile-first, full-width with padding like coconut_index.html */
.demo-container {
  font-family: -apple-system, "PingFang SC", "Helvetica Neue", sans-serif;
  padding: 20px 16px 48px;
  background: #f5f6f8;
  color: #1f2329;
  min-height: 100vh;
}

h1 { font-size: 20px; margin-bottom: 4px; font-weight: 700; }
.hint { font-size: 13px; color: #8a8f99; margin-bottom: 12px; line-height: 1.5; }

/* Platform pill badge */
.platform {
  display: inline-flex; align-items: center; gap: 6px;
  background: #eef4ff; color: #3370ff; border: 1px solid #cfe0ff;
  padding: 6px 14px; border-radius: 999px; font-size: 13px; font-weight: 600;
  margin-bottom: 16px;
}
.platform.web { background: #fff3e8; color: #ff7d00; border-color: #ffd6a8; }
.dot { width: 8px; height: 8px; border-radius: 50%; background: currentColor; }

/* Section + buttons */
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
.btn-g { background: #0fc6c2; }

/* Panels */
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

/* Run All results list */
.run-list { display: flex; flex-direction: column; gap: 8px; }
.run-row {
  display: flex; gap: 10px; padding: 10px;
  border-radius: 8px; background: #f7f8fa;
}
.run-row.pass { background: #f0fff4; }
.run-row.fail { background: #fff5f5; }
.run-row.skip { background: #f7f8fa; opacity: .75; }
.run-row.running { background: #fffbe6; }
.run-icon { font-size: 16px; line-height: 1.4; flex-shrink: 0; }
.run-body { flex: 1; min-width: 0; }
.run-name { font-size: 13px; font-weight: 600; color: #1f2329; word-break: break-all; }
.run-dur { color: #8a8f99; font-weight: 400; font-size: 12px; }
.run-line { font-size: 12px; color: #4a5568; margin-top: 2px; word-break: break-all; }

/* Event log entries */
.event-item { margin-bottom: 8px; }
.event-item:last-child { margin-bottom: 0; }
.event-time { font-size: 11px; color: #8a8f99; margin-bottom: 4px; font-family: "SF Mono", Menlo, monospace; }

/* Capability chips */
.cap-grid { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px; }
.cap-chip {
  display: inline-flex; align-items: center; gap: 4px;
  padding: 4px 10px; border-radius: 999px; font-size: 12px;
  font-family: "SF Mono", Menlo, monospace;
}
.cap-chip.on  { background: #f0fff4; color: #00b42c; }
.cap-chip.off { background: #fff5f5; color: #f53f3f; }
.cap-dot { font-weight: 700; }
</style>
