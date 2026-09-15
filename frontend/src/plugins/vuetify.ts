import 'vuetify/styles'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { ja } from 'vuetify/locale'

// PlantKeeper デザイントークン
// 計装保全の現場（銘板・計器盤・P&ID図面）を起点にした配色。
// 汎用SaaS的な紫系グラデーションを避け、鋼板のような寒色グレーに
// 保全タグの錆色アンバーを差し色として使う。
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
          primary: '#2E5B7A',
          'primary-darken-1': '#203F55',
          secondary: '#5B6B70',
          accent: '#C1631F',
          error: '#B3261E',
          success: '#2E7D4F',
          warning: '#B4720E',
          info: '#3D6E8C',
          background: '#EEF1EF',
          surface: '#FFFFFF',
          'surface-variant': '#E7EBE8',
          'on-surface-variant': '#3C4547',
          outline: '#D6DBD8',
          ink: '#17222B',
        },
        variables: {
          'border-color': '#17222B',
          'border-opacity': 0.12,
        },
      },
      dark: {
        dark: true,
        colors: {
          primary: '#7FA6BF',
          secondary: '#AAB4B8',
          accent: '#E7B778',
          error: '#E5766B',
          success: '#5CA97F',
          warning: '#D99B3F',
          info: '#7FA6BF',
          background: '#17222B',
          surface: '#17222B',
          'surface-variant': '#203041',
          'on-surface-variant': '#CFD6D8',
          outline: '#2E3D48',
          ink: '#17222B',
        },
      },
    },
  },
  defaults: {
    VAppBar: { flat: true, color: 'surface' },
    VNavigationDrawer: { elevation: 0 },
    VCard: { elevation: 0, rounded: 0, border: true },
    VSheet: { elevation: 0, rounded: 0 },
    VBtn: { elevation: 0, rounded: 'sm' },
    VTextField: { variant: 'outlined', density: 'comfortable', rounded: 'sm' },
    VSelect: { variant: 'outlined', density: 'comfortable', rounded: 'sm' },
    VAutocomplete: { variant: 'outlined', density: 'comfortable', rounded: 'sm' },
    VTextarea: { variant: 'outlined', density: 'comfortable', rounded: 'sm' },
    VChip: { rounded: 'sm' },
    VDialog: { VCard: { elevation: 3, rounded: 0 } },
    VDataTable: { rounded: 0 },
  },
})

export default vuetify
