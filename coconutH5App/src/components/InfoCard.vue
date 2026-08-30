<script setup>
// 通用标题卡片：视觉与 coconutWebBox panel 同语言
defineProps({ title: { type: String, default: '' } })
</script>

<template>
  <div class="card">
    <h3 v-if="title">{{ title }}</h3>
    <slot />
  </div>
</template>
