<script setup lang="ts">
// 点検のまとまりの追加・編集（名前・担当部署・法規区分・既定の周期・有効/無効）。拠点は追加するときだけ選べる
import { computed, ref, watch } from 'vue'
import api from '@/api/axios'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import type { InspectionPlanGroup } from '@/types/models'

const props = defineProps<{ group: InspectionPlanGroup | null; defaultSiteId?: number | null }>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ saved: [] }>()

const { canViewSites } = usePermissions()
const authStore = useAuthStore()

const sites = ref<{ id: number; name: string }[]>([])
const departments = ref<any[]>([])
const regulations = ref<{ id: number; name: string }[]>([])
const errors = ref<string[]>([])
const saving = ref(false)
const form = ref({
  site_id: null as number | null,
  name: '',
  department_id: null as number | null,
  regulation_id: null as number | null,
  default_interval_days: null as number | null,
  is_active: true,
})
const isEdit = computed(() => !!props.group)

async function loadDepartments(siteId: number | null) {
  departments.value = []
  if (!siteId) return
  const res = await api.get('/departments', { params: { site_ids: [siteId] } })
  departments.value = res.data.data
}

function changeSite(siteId: number | null) {
  form.value.department_id = null
  loadDepartments(siteId)
}

watch(open, async (isOpen) => {
  if (!isOpen) return
  errors.value = []
  const group = props.group
  form.value = group
    ? {
        site_id: group.site_id,
        name: group.name,
        department_id: group.department_id,
        regulation_id: group.regulation_id,
        default_interval_days: group.default_interval_days,
        is_active: group.is_active,
      }
    : { site_id: props.defaultSiteId ?? authStore.user?.site_id ?? null, name: '', department_id: null, regulation_id: null, default_interval_days: null, is_active: true }
  const [regulationRes, siteRes] = await Promise.all([
    api.get('/regulations'),
    !isEdit.value && canViewSites.value ? api.get('/sites', { params: { per_page: 100, is_active: true } }) : Promise.resolve(null),
  ])
  regulations.value = regulationRes.data.data
  if (siteRes) sites.value = siteRes.data.data
  await loadDepartments(form.value.site_id)
})

async function save() {
  errors.value = []
  saving.value = true
  try {
    const body = { ...form.value, default_interval_days: form.value.default_interval_days || null }
    if (props.group) await api.patch(`/inspection_plan_groups/${props.group.id}`, { inspection_plan_group: body })
    else await api.post('/inspection_plan_groups', { inspection_plan_group: body })
    open.value = false
    emit('saved')
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['保存に失敗しました']
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <v-dialog v-model="open" max-width="520">
    <v-card>
      <v-card-title>{{ isEdit ? 'まとまりを編集' : 'まとまりを追加' }}</v-card-title>
      <v-card-text>
        <v-alert v-if="errors.length" type="error" variant="tonal" class="mb-3">{{ errors.join('、') }}</v-alert>
        <v-select
          v-if="!isEdit && canViewSites"
          v-model="form.site_id"
          :items="sites"
          item-title="name"
          item-value="id"
          label="拠点"
          class="mb-2"
          @update:model-value="changeSite"
        />
        <v-text-field v-model="form.name" label="名前" hint="例: テレメータ計器の定期検査" persistent-hint class="mb-2" />
        <v-select
          v-model="form.department_id"
          :items="departments"
          item-title="full_path"
          item-value="id"
          label="担当部署（任意）"
          clearable
          class="mb-2"
        />
        <v-select v-model="form.regulation_id" :items="regulations" item-title="name" item-value="id" label="法規区分（任意）" clearable class="mb-2" />
        <v-text-field
          v-model.number="form.default_interval_days"
          label="既定の周期（日・任意）"
          type="number"
          min="1"
          hint="計画を追加するときの初期値です。周期は計画ごとに変えられます"
          persistent-hint
          class="mb-2"
        />
        <v-switch v-if="isEdit" v-model="form.is_active" label="有効（無効にすると、計画の追加で選べなくなります）" color="primary" hide-details />
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">キャンセル</v-btn>
        <v-btn color="primary" :loading="saving" :disabled="!form.name || !form.site_id" @click="save">保存</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
