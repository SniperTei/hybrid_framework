# coconutH5App — 真实业务试点（Phase 4）：4 tab 移动端 H5 App

Vue 3 + Vite 移动端 app，跑手机 + pad，7 个 coconut 组件全部真实场景化（不再是按钮点测）。
与 `coconutWebBox`（测试面板）平级，作为独立离线包模块 `h5app` 分发三端。

## 4 Tab

| Tab | 内容 | 组件场景 |
|-----|------|----------|
| 首页 | 容器仪表盘：应用/设备卡 + 网络实时卡 + 能力矩阵 | `env` / `device.getInfo` / `device.getAppInfo` / `network.getNetworkType` + `on('network.change')` |
| 发现 | Sniper API 食物列表 → forward 详情页；事件订阅流 | `network.request` 全链路 / `navigator.forward` / `close` 回传 → `on('nav.result')` / `storage` 已读水位 / `dialog.confirm` |
| AI | 工具箱宫格：识图 / 翻译 / 摘要 | `network.request`（OpenAI 兼容非流式契约 + H5 打字机） |
| 我的 | profile + 存储占用 + 设置入口 | `storage.getSize` / `navigator.forward` |

全屏二级页（无 tab）：`#/detail?id=..`（详情，close 回传）、`#/settings`（设置，从 coconutWebBox Settings.vue 移植）、`#/ai/<tool>`（AI 工具）。

## Pad 适配

- `<768px`：底部 tab bar（flex:1 + `padding-bottom: env(safe-area-inset-bottom)` 避让 home indicator）
- `≥768px`：左侧 200px 侧边导航，内容区 `max-width: 960px` 居中
- 断点只在 `src/style.css` 出现一次；用 `min-width`（不用 orientation——折叠屏/分屏下 orientation 不可靠）

## Dev / 构建

```bash
npm install
npm run dev      # http://localhost:5175（strictPort，与 coconutWebBox 5174 错开）
npm run build
```

- 离线包约束同 coconutWebBox：`base './'` + iife + classic script + 无 hash 文件名（见 `vite.config.js` 注释）
- `public/coconut.js` 源头在 **coconutWebBox/public/**（源头唯一）；`build-offline-package.sh` 有 drift 硬门禁（不一致 exit 1）
- 离线包分发：`bash scripts/build-offline-package.sh --module h5app`（三端 demo 首页「H5 App」按钮开 `coconut://h5app/index.html`）

## 服务地址配置（query > storage > 默认）

每个网络相关页面有可折叠「服务地址」配置（`ApiBaseField`），优先级：URL query（e2e 注入缝，如 `?apiBase=…` / `?llmBase=…`）> `storage` 落盘 > 默认。

| key | 用途 | 默认 |
|-----|------|------|
| `h5app.api_base` | Sniper API（发现列表 / 详情） | `http://127.0.0.1:8041` |
| `h5app.llm_base` | AI 工具（OpenAI 兼容） | `http://127.0.0.1:8043`（mock） |

三端 localhost 语义：iOS sim = Mac loopback；Android 模拟器用 `10.0.2.2` 或 `adb reverse`；Harmony 需 `hdc rport tcp:<port> tcp:<port>`。iOS ATS 拦非 localhost 明文 HTTP。

## AI mock 服务

```bash
bash scripts/serve-ai-mock.sh            # :8043，模拟推理延迟
# POST /v1/chat/completions   model=translator|summarizer（OpenAI 兼容非流式）
# POST /v1/images/analyses    image_url → detections（URL 哈希 deterministic）
```

原生 network 组件不支持真流式（API_CONTRACT.md §4.5，流式进度下轮）——打字机效果为 H5 端 `revealText` 模拟；接真实 LLM 时改工具页内服务地址即可（契约已按 OpenAI 兼容对齐）。

## House patterns（沿用 coconutWebBox）

- **configTick**（`lib/configTick.js`）：config 注入晚于 Vue 首渲染（Harmony 实测），读 `window.coconut` 的 computed 必须经 `coconut:config-loaded` 事件强制失效
- **pcall**（`lib/pcall.js`）：error-first callback → Promise
- **events fan-out**（`lib/events.js`）：`coconut.on` 每 topic 单 handler，多页面同订一个 topic 必须 fan-out
- **forward 绝对 URL**（UrlGuard 拦 scheme-less）：`location.origin + location.pathname + '#/…'`
- **storage key 一律 `h5app.` 前缀**，与 demo 模块隔离
