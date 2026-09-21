import 'vuetify/styles'
import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
import { ja } from 'vuetify/locale'

// PlantKeeper デザイントークン
// プラナのブルーを共通の操作色に。状態を表す赤・黄・緑とは役割を分ける。
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
          primary: '#2364C4',
          'primary-darken-1': '#194B96',
          secondary: '#566A83',
          accent: '#A95612',
          error: '#B3261E',
          success: '#2E7D4F',
          warning: '#B4720E',
          info: '#2364C4',
          background: '#F3F7FC',
          surface: '#FFFFFF',
          'on-surface': '#203451',
          'surface-variant': '#EAF2FD',
          'on-surface-variant': '#344C6B',
          outline: '#DAE4F0',
          ink: '#203451',
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
    VCard: { elevation: 0, rounded: 'lg', border: true },
    VSheet: { elevation: 0, rounded: 'lg' },
    VBtn: { elevation: 0, rounded: 'lg' },
    VTextField: { variant: 'outlined', density: 'comfortable', rounded: 'lg', color: 'primary' },
    VSelect: { variant: 'outlined', density: 'comfortable', rounded: 'lg', color: 'primary' },
    VAutocomplete: { variant: 'outlined', density: 'comfortable', rounded: 'lg', color: 'primary' },
    VTextarea: { variant: 'outlined', density: 'comfortable', rounded: 'lg', color: 'primary' },
    VChip: { rounded: 'lg' },
    VAlert: { rounded: 'lg' },
    VDialog: { VCard: { elevation: 3, rounded: 'xl' } },
    VDataTable: { rounded: 'lg', itemsPerPage: 50 },
  },
})

export default vuetify
