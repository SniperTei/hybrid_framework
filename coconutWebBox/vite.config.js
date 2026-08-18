import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],

  // 离线包：相对 base，产物可从任意路径（file:// / coconut://）加载
  base: './',

  build: {
    rollupOptions: {
      output: {
        // 禁 hash 文件名：git diff 稳定，离线包 manifest 路径固定
        entryFileNames: 'assets/[name].js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name][extname]',
        // 离线包必须用 classic script（非 ES module）：module script 规范上
        // 永远走 CORS 模式请求，而 file:// / resource:// 等离线 scheme 的
        // origin 是 null → 必被 CORS 拦（Harmony/Android 实测）。iife 单文件
        // 产物 + classic <script src> 不走 CORS。
        format: 'iife',
        inlineDynamicImports: true,
      },
    },
  },

  // 服务器配置
  server: {
    host: '0.0.0.0', // 允许外部访问
    port: 5174,      // 端口号
    strictPort: true, // 端口被占用时直接失败
  },
})
