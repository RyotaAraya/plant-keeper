import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import vuetify from 'vite-plugin-vuetify'
import { fileURLToPath, URL } from 'node:url'

// タブで環境を見分けるため、favicon を環境ごとに変える。VITE_APP_ENV は render.yaml で設定し、未設定はローカル
// （index.html の既定は `/favicon-dev.svg`）。3つとも public/ に置き、どの環境のビルドにも含める
const FAVICONS: Record<string, string> = {
  production: '/favicon.svg',
  stg: '/favicon-stg.svg',
}

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const favicon = FAVICONS[loadEnv(mode, process.cwd()).VITE_APP_ENV ?? ''] ?? '/favicon-dev.svg'

  return {
    plugins: [
      vue(),
      vuetify({ autoImport: true }),
      {
        name: 'favicon-per-env',
        transformIndexHtml: (html: string) => html.replace('href="/favicon-dev.svg"', `href="${favicon}"`),
      },
    ],
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
      },
    },
    server: {
      host: true,
      watch: {
        usePolling: true,
        interval: 1000,
      },
    },
  }
})
