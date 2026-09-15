import 'vuetify/styles'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { ja } from 'vuetify/locale'

const vuetify = createVuetify({
  components,
  directives,
  locale: {
    locale: 'ja',
    messages: { ja },
  },
  theme: {
    defaultTheme: 'light',
    themes: {
      light: {
        colors: {
          primary: '#4F46E5',
          secondary: '#6B7280',
          accent: '#4F46E5',
          error: '#DC2626',
          success: '#16A34A',
          warning: '#D97706',
          info: '#2563EB',
          background: '#FAFAFA',
          surface: '#FFFFFF',
          'surface-variant': '#F4F4F5',
          'on-surface-variant': '#3F3F46',
          outline: '#E4E4E7',
        },
      },
    },
  },
  defaults: {
    VAppBar: { flat: true, color: 'surface' },
    VNavigationDrawer: { elevation: 0 },
    VCard: { elevation: 0, rounded: 'lg', border: true },
    VSheet: { elevation: 0, rounded: 'lg' },
    VBtn: { elevation: 0, rounded: 'lg' },
    VTextField: { variant: 'outlined', density: 'comfortable', rounded: 'lg' },
    VSelect: { variant: 'outlined', density: 'comfortable', rounded: 'lg' },
    VAutocomplete: { variant: 'outlined', density: 'comfortable', rounded: 'lg' },
    VTextarea: { variant: 'outlined', density: 'comfortable', rounded: 'lg' },
    VChip: { rounded: 'lg' },
    VDialog: { VCard: { elevation: 3 } },
    VDataTable: { rounded: 'lg' },
  },
})

export default vuetify
