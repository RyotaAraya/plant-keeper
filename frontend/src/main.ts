import { createApp } from 'vue'
import '@mdi/font/css/materialdesignicons.css'
import vuetify from '@/plugins/vuetify'
import pinia from '@/plugins/pinia'
import router from '@/router'
import App from '@/App.vue'

const app = createApp(App)

app.use(pinia)
app.use(router)
app.use(vuetify)

app.mount('#app')
