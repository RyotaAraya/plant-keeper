<script setup lang="ts">
// インターロックの登録・編集ダイアログ（台帳の一覧と詳細で共通）。interlock が null なら新規登録。
// 関係する計器は、インターロックの設備の計器から選ぶ
import { ref, watch } from 'vue'
import api from '@/api/axios'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import type { Interlock } from '@/types/models'

const props = defineProps<{ interlock: Interlock | null; defaultSiteId?: number | null }>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ saved: [id: number] }>()

const { canViewSites } = usePermissions()
const authStore = useAuthStore()
const sites = ref<{ id: number; name: string }[]>([])
const equipments = ref<{ id: number; name: string }[]>([])
const instruments = ref<{ id: number; tag_number: string }[]>([])
const errors = ref<string[]>([])

const blank = () => ({
  site_id: (props.defaultSiteId ?? authStore.user?.site_id ?? null) as number | null,
  equipment_id: null as number | null, tag_number: '', name: '', trip_action: '', notes: '', is_active: true, instrument_ids: [] as number[],
})
const form = ref(blank())

watch(open, async (isOpen) => {
  if (!isOpen) return
  errors.value = []
  const il = props.interlock
  form.value = il
    ? {
        site_id: il.equipment.site.id, equipment_id: il.equipment_id, tag_number: il.tag_number, name: il.name,
        trip_action: il.trip_action ?? '', notes: il.notes ?? '', is_active: il.is_active, instrument_ids: il.instruments.map((i) => i.id),
      }
    : blank()
  if (canViewSites.value && !sites.value.length) sites.value = (await api.get('/sites', { params: { per_page: 100 } })).data.data
  await loadEquipments(form.value.site_id)
  await loadInstruments(form.value.equipment_id)
})

async function loadEquipments(siteId: number | null) {
  equipments.value = siteId ? (await api.get('/equipments', { params: { site_id: siteId, per_page: 1000 } })).data.data : []
}

async function loadInstruments(equipmentId: number | null) {
  instruments.value = equipmentId ? (await api.get('/instruments', { params: { equipment_id: equipmentId, per_page: 1000 } })).data.data : []
}

async function changeSite(siteId: number | null) {
  form.value.equipment_id = null
  form.value.instrument_ids = []
  await loadEquipments(siteId)
  instruments.value = []
}

async function changeEquipment(equipmentId: number | null) {
  form.value.instrument_ids = []
  await loadInstruments(equipmentId)
}

async function save() {
  errors.value = []
  // 拠点は設備を選ぶためだけに使い、送らない
  const payload: Record<string, unknown> = { ...form.value }
  delete payload.site_id
  try {
    const res = props.interlock
      ? await api.patch(`/interlocks/${props.interlock.id}`, { interlock: payload })
      : await api.post('/interlocks', { interlock: payload })
    open.value = false
    emit('saved', res.data.data.id)
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}
</script>

<template>
  <v-dialog v-model="open" max-width="640" scrollable>
    <v-card>
      <v-card-title>{{ interlock ? 'インターロックの編集' : 'インターロックの登録' }}</v-card-title>
      <v-card-text>
        <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
          <div v-for="err in errors" :key="err">{{ err }}</div>
        </v-alert>
        <v-select
          v-if="canViewSites && !interlock"
          v-model="form.site_id"
          :items="sites"
          item-title="name"
          item-value="id"
          label="拠点"
          class="mb-2"
          @update:model-value="changeSite"
        />
        <v-select
          v-model="form.equipment_id"
          :items="equipments"
          item-title="name"
          item-value="id"
          label="設備 *"
          :disabled="!!interlock"
          class="mb-2"
          @update:model-value="changeEquipment"
        />
        <v-row dense>
          <v-col cols="4"><v-text-field v-model="form.tag_number" label="番号 *" placeholder="I-701" /></v-col>
          <v-col cols="8"><v-text-field v-model="form.name" label="名称 *" placeholder="ボイラードラム液位 低低" /></v-col>
        </v-row>
        <v-autocomplete
          v-model="form.instrument_ids"
          :items="instruments"
          item-title="tag_number"
          item-value="id"
          label="関係する計器（検出端・遮断弁など）"
          multiple
          chips
          closable-chips
          :disabled="!form.equipment_id"
          class="mb-2"
        />
        <v-textarea v-model="form.trip_action" label="トリップ時の動作" rows="2" placeholder="例: 燃料ガス遮断弁 XV-701 を閉じ、ボイラーを停止する" class="mb-2" />
        <v-textarea v-model="form.notes" label="備考" rows="2" />
        <v-switch v-if="interlock" v-model="form.is_active" label="使用中（オフで廃止。過去のバイパスの記録は残ります）" color="primary" density="compact" hide-details />
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">キャンセル</v-btn>
        <v-btn color="primary" @click="save">保存</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
