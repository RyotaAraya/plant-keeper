import 'vuetify/styles'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { ja } from 'vuetify/locale'

const vuetify = createVuetify({
  components,
  directives,
  locale: {
    defaultLocale: 'ja',
    messages: { ja },
  },
  theme: {
    defaultTheme: 'light',
    themes: {
      light: {
        colors: {
          primary: '#1565C0',
          secondary: '#424242',
          accent: '#FF6F00',
        },
      },
    },
  },
})

export default vuetify
