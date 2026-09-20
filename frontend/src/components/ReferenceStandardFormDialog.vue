<script setup lang="ts">
// 基準器の登録・編集ダイアログ（基準器の一覧と詳細で共通）。standard が null なら新規登録
import { ref, watch } from 'vue'
import api from '@/api/axios'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import type { ReferenceStandard } from '@/types/models'
import { CATEGORY_LABEL, STATUS_LABEL } from '@/utils/referenceStandard'

const props = defineProps<{ standard: ReferenceStandard | null; defaultSiteId?: number | null }>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ saved: [] }>()

const { canViewSites } = usePermissions()
const authStore = useAuthStore()
const sites = ref<any[]>([])
const errors = ref<string[]>([])

const statusOptions = Object.entries(STATUS_LABEL).map(([value, title]) => ({ title, value }))
const categoryOptions = Object.entries(CATEGORY_LABEL).map(([value, title]) => ({ title, value }))

const blank = () => ({
  site_id: (props.defaultSiteId ?? authStore.user?.site_id ?? null) as number | null,
  management_number: '', name: '', category: 'pressure', model_number: '', serial_number: '',
  measuring_range: '', accuracy: '', location: '', status: 'usable', notes: '',
})
const form = ref(blank())

watch(open, async (isOpen) => {
  if (!isOpen) return
  errors.value = []
  const s = props.standard
  form.value = s
    ? {
        site_id: s.site_id, management_number: s.management_number, name: s.name, category: s.category,
        model_number: s.model_number ?? '', serial_number: s.serial_number ?? '', measuring_range: s.measuring_range ?? '',
        accuracy: s.accuracy ?? '', location: s.location ?? '', status: s.status, notes: s.notes ?? '',
      }
    : blank()
  if (canViewSites.value && !sites.value.length) {
    const res = await api.get('/sites', { params: { per_page: 100 } })
    sites.value = res.data.data
  }
})

async function save() {
  errors.value = []
  try {
    if (props.standard) await api.patch(`/reference_standards/${props.standard.id}`, { reference_standard: form.value })
    else await api.post('/reference_standards', { reference_standard: form.value })
    open.value = false
    emit('saved')
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}
</script>

<template>
  <v-dialog v-model="open" max-width="640" scrollable>
    <v-card>
      <v-card-title>{{ standard ? '基準器の編集' : '基準器の登録' }}</v-card-title>
      <v-card-text>
        <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
          <div v-for="err in errors" :key="err">{{ err }}</div>
        </v-alert>
        <v-select v-if="canViewSites" v-model="form.site_id" :items="sites" item-title="name" item-value="id" label="拠点" class="mb-2" />
        <v-text-field v-model="form.management_number" label="管理番号 *" class="mb-2" />
        <v-text-field v-model="form.name" label="名称 *" class="mb-2" />
        <v-row dense>
          <v-col cols="6"><v-select v-model="form.category" :items="categoryOptions" item-title="title" item-value="value" label="種別" /></v-col>
          <v-col cols="6"><v-select v-model="form.status" :items="statusOptions" item-title="title" item-value="value" label="状態" /></v-col>
          <v-col cols="6"><v-text-field v-model="form.model_number" label="型式" /></v-col>
          <v-col cols="6"><v-text-field v-model="form.serial_number" label="製造番号" /></v-col>
          <v-col cols="6"><v-text-field v-model="form.measuring_range" label="測定範囲（例: 0〜200 kPa）" /></v-col>
          <v-col cols="6"><v-text-field v-model="form.accuracy" label="精度（例: ±0.05 %RD）" /></v-col>
        </v-row>
        <v-text-field v-model="form.location" label="保管場所" class="mb-2" />
        <v-textarea v-model="form.notes" label="備考" rows="2" />
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">キャンセル</v-btn>
        <v-btn color="primary" @click="save">保存</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
