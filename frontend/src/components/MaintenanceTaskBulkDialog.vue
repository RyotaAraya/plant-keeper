<script setup lang="ts">
// 設備の計器を、種類ごとの定修点検のチェックリストつきで、点検の作業として一括追加する。
// すでに作業のある計器と、チェックリストのない計器（手動弁など）は飛ばす
import { ref, watch } from 'vue'
import api from '@/api/axios'

const props = defineProps<{ maintenance: any }>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ saved: [] }>()

const equipmentId = ref<number | null>(null)
const departmentId = ref<number | null>(null)
const departments = ref<any[]>([])
const errors = ref<string[]>([])
const result = ref<{ created: number; skipped_existing: number; unsupported: number } | null>(null)

watch(open, async (isOpen) => {
  if (!isOpen) return
  errors.value = []
  result.value = null
  equipmentId.value = props.maintenance.equipments?.[0]?.id ?? null
  departmentId.value = null
  const res = await api.get('/departments')
  departments.value = res.data.data.filter((d: any) => d.site_id === props.maintenance.site_id)
})

async function add() {
  errors.value = []
  result.value = null
  try {
    const res = await api.post(`/scheduled_maintenances/${props.maintenance.id}/tasks/bulk`, { equipment_id: equipmentId.value, department_id: departmentId.value })
    result.value = res.data.meta
    emit('saved')
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['追加に失敗しました']
  }
}
</script>

<template>
  <v-dialog v-model="open" max-width="520">
    <v-card>
      <v-card-title>計器を一括追加</v-card-title>
      <v-card-text>
        <div class="text-caption text-medium-emphasis mb-3">
          設備の計器を、種類（伝送器・調節弁・遮断弁・安全弁）ごとの定修点検のチェックリストつきで、点検の作業として追加します。すでに作業のある計器と、チェックリストのない計器（手動弁など）は飛ばします。
        </div>
        <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
          <div v-for="err in errors" :key="err">{{ err }}</div>
        </v-alert>
        <v-alert v-if="result" type="success" variant="tonal" density="compact" class="mb-4" data-testid="bulk-result">
          {{ result.created }}件を追加しました（作業のある計器 {{ result.skipped_existing }}件・チェックリストのない計器 {{ result.unsupported }}件は飛ばしました）
        </v-alert>
        <v-select v-model="equipmentId" :items="maintenance.equipments" item-title="name" item-value="id" label="設備 *" class="mb-2" />
        <v-select v-model="departmentId" :items="departments" item-title="full_path" item-value="id" label="担当する部署" clearable hint="作業の部署になります。あとから作業ごとに変えられます" persistent-hint />
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">閉じる</v-btn>
        <v-btn color="primary" @click="add">追加</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
