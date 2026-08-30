<template>
  <div>
    <h1 class="page-title">AI</h1>
    <p class="page-hint">AI 工具箱：识图（Sniper 预留）/ 翻译 / 摘要（LLM）。默认对接 mock 服务（scripts/serve-ai-mock.sh），地址在各工具页内可配置。</p>

    <div class="tool-grid">
      <a v-for="t in tools" :key="t.id" class="tool-card" :href="'#/ai/' + t.id">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"
             stroke-linecap="round" stroke-linejoin="round">
          <path :d="t.icon" />
        </svg>
        <div class="tool-name">{{ t.name }}</div>
        <div class="tool-desc">{{ t.desc }}</div>
      </a>
    </div>

    <div class="card">
      <h3>说明</h3>
      <p class="note">
        LLM 工具走 OpenAI 兼容非流式契约（network.request · 原生网络引擎）。
        原生引擎暂不支持真流式（API_CONTRACT §4.5），打字机效果为 H5 端模拟。
        接真实 LLM 服务时改工具页内的服务地址即可。
      </p>
    </div>
  </div>
</template>

<script setup>
const tools = [
  {
    id: 'detect',
    name: 'AI 识图',
    desc: '图片 URL → 目标检测（YOLO 风格结果）',
    icon: 'M3 8 V5.5 A1.5 1.5 0 0 1 4.5 4 H7 M17 4 H19.5 A1.5 1.5 0 0 1 21 5.5 V8 M21 16 V18.5 A1.5 1.5 0 0 1 19.5 20 H17 M7 20 H4.5 A1.5 1.5 0 0 1 3 18.5 V16 M7 9.5 H11 M7 12.5 H14 M9 9.5 V12.5 M3.5 12.5 H1.5 M22.5 12.5 H20.5 M12 1.5 V3.5',
  },
  {
    id: 'translate',
    name: 'AI 翻译',
    desc: '文本翻译（LLM · 打字机输出）',
    icon: 'M4 5 H10 M7 3 V5 M5.5 5 C5.5 9 7.5 12 11 13 M8 5 C8 9.5 10.5 13.5 14.5 15.5 M13 11 C14 14 17 17.5 20 18.5 M14.5 11 H19 M16.75 8.75 V11 M17.5 16 C18 17.5 19.5 19.5 21 20.5',
  },
  {
    id: 'summarize',
    name: 'AI 摘要',
    desc: '长文摘要（LLM · 打字机输出）',
    icon: 'M6 4 H18 M6 8 H18 M6 12 H13 M16.5 14.5 L18 18 L21.5 19.5 L18 21 L16.5 24.5 L15 21 L11.5 19.5 L15 18 Z M6 16 H11',
  },
]
</script>

<style scoped>
.tool-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 12px;
  margin-bottom: 16px;
}
.tool-card {
  background: var(--c-card);
  border-radius: 12px;
  padding: 20px 14px;
  box-shadow: var(--shadow);
  text-align: center;
  color: var(--c-primary);
  transition: transform 0.12s;
}
.tool-card:active { transform: scale(0.97); }
.tool-card svg { width: 36px; height: 36px; margin-bottom: 10px; }
.tool-name { font-size: 15px; font-weight: 600; color: var(--c-text); margin-bottom: 4px; }
.tool-desc { font-size: 11px; color: var(--c-muted); line-height: 1.5; }
.note { font-size: 12px; color: var(--c-muted); line-height: 1.7; }
</style>
