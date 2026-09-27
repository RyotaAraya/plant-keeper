<script setup lang="ts">
// 定期整備（1回分）の作成。名称・拠点・予定期間・対象設備・説明
import { ref, watch } from 'vue'
import api from '@/api/axios'
import SiteEquipmentSelect from '@/components/SiteEquipmentSelect.vue'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'

const props = defineProps<{ defaultSiteId?: number | null }>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ saved: [] }>()

const { canViewSites } = usePermissions()
const authStore = useAuthStore()
const sites = ref<any[]>([])
const errors = ref<string[]>([])
const form = ref({
  title: '',
  site_id: null as number | null,
  planned_start_on: '',
  planned_end_on: '',
  equipment_ids: [] as number[],
  description: '',
})

watch(open, async (isOpen) => {
  if (!isOpen) return
  errors.value = []
  form.value = {
    title: '',
    site_id: props.defaultSiteId ?? authStore.user?.site_id ?? null,
    planned_start_on: '', planned_end_on: '', equipment_ids: [], description: '',
  }
  if (canViewSites.value && !sites.value.length) {
    const res = await api.get('/sites', { params: { per_page: 100 } })
    sites.value = res.data.data
  }
})

async function save() {
  errors.value = []
  try {
    await api.post('/scheduled_maintenances', { scheduled_maintenance: form.value })
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
      <v-card-title>定期整備の作成</v-card-title>
      <v-card-text>
        <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
          <div v-for="err in errors" :key="err">{{ err }}</div>
        </v-alert>
        <v-text-field v-model="form.title" label="名称 *（例: 2026年 A号ボイラー整備）" class="mb-2" />
        <v-select v-if="canViewSites" v-model="form.site_id" :items="sites" item-title="name" item-value="id" label="拠点 *" class="mb-2" />
        <v-row dense>
          <v-col cols="6"><v-text-field v-model="form.planned_start_on" label="予定 開始日 *" type="date" /></v-col>
          <v-col cols="6"><v-text-field v-model="form.planned_end_on" label="予定 終了日" type="date" /></v-col>
        </v-row>
        <SiteEquipmentSelect v-model="form.equipment_ids" :site-id="form.site_id" class="mb-2" />
        <v-textarea v-model="form.description" label="説明" rows="3" class="mt-2" />
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">キャンセル</v-btn>
        <v-btn color="primary" @click="save">作成</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
