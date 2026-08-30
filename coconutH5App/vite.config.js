import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// 与 coconutWebBox 同一套离线包约束（详见 scripts/build-offline-package.sh）：
//  - base './' 相对路径，产物可从 coconut:// / file:// 任意前缀加载
//  - 无 hash 文件名：manifest 路径固定，git diff 稳定
//  - iife + classic script：ES module 永远走 CORS 模式请求，
//    离线 scheme（origin=null）必被拦；构建脚本会把入口剥成 classic script
export default defineConfig({
  plugins: [vue()],

  base: './',

  build: {
    rollupOptions: {
      output: {
        entryFileNames: 'assets/[name].js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name][extname]',
        format: 'iife',
        inlineDynamicImports: true,
      },
    },
  },

  server: {
    host: '0.0.0.0', // 模拟器 WebView 走局域网 IP 访问 dev server
    port: 5175,      // 与 coconutWebBox (5174) 错开
    strictPort: true,
  },
})
