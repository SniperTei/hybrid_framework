<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import Demo from './components/Demo.vue'
import Settings from './components/Settings.vue'

// 单 bundle hash 路由：#/settings → 设置页（真实业务试点），其余 → Demo
const hash = ref(window.location.hash)
function onHashChange() { hash.value = window.location.hash }
onMounted(() => window.addEventListener('hashchange', onHashChange))
onUnmounted(() => window.removeEventListener('hashchange', onHashChange))
</script>

<template>
  <Settings v-if="hash.startsWith('#/settings')" />
  <Demo v-else />
</template>
