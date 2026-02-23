<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'
import ResourceHistory from '@/components/ResourceHistory.vue'

const route = useRoute()
const router = useRouter()
const { canManageEquipment, canManageEquipmentAssignment } = usePermissions()

const equipment = ref<any>(null)
const loading = ref(false)
const tab = ref('instruments')

// --- 設備編集 ---
const editDialog = ref(false)
const editForm = ref({ name: '', description: '', site_id: null as number | null })
const editErrors = ref<string[]>([])
const sites = ref<any[]>([])

async function openEditEquipment() {
  if (!sites.value.length) {
    const res = await api.get('/sites', { params: { per_page: 100 } })
    sites.value = res.data.data
  }
  editForm.value = {
    name: equipment.value.name,
    description: equipment.value.description || '',
    site_id: equipment.value.site_id,
  }
  editErrors.value = []
  editDialog.value = true
}

async function saveEquipment() {
  editErrors.value = []
  try {
    await api.patch(`/equipments/${route.params.id}`, { equipment: editForm.value })
    editDialog.value = false
    await fetchEquipment()
  } catch (e: any) {
    editErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

// --- 設備担当追加 ---
const assignDialog = ref(false)
const assignForm = ref({ user_id: null as number | null, role: '', started_on: new Date().toISOString().slice(0, 10) })
const assignErrors = ref<string[]>([])
const users = ref<any[]>([])

async function openAssignDialog() {
  if (!users.value.length) {
    const res = await api.get('/users', { params: { per_page: 200 } })
    users.value = res.data.data
  }
  assignForm.value = { user_id: null, role: '', started_on: new Date().toISOString().slice(0, 10) }
  assignErrors.value = []
  assignDialog.value = true
}

async function saveAssignment() {
  assignErrors.value = []
  try {
    await api.post('/equipment_assignments', {
      equipment_assignment: {
        equipment_id: equipment.value.id,
        user_id: assignForm.value.user_id,
        role: assignForm.value.role,
        started_on: assignForm.value.started_on,
      },
    })
    assignDialog.value = false
    await fetchEquipment()
  } catch (e: any) {
    assignErrors.value = e.response?.data?.errors || ['保存に失敗しました']
  }
}

async function fetchEquipment() {
  loading.value = true
  try {
    const res = await api.get(`/equipments/${route.params.id}`)
    equipment.value = res.data.data
  } finally {
    loading.value = false
  }
}

function currentAssignments() {
  return (equipment.value?.equipment_assignments || []).filter((a: any) => !a.ended_on)
}

function pastAssignments() {
  return (equipment.value?.equipment_assignments || []).filter((a: any) => a.ended_on)
}

async function endAssignment(assignment: any) {
  await api.patch(`/equipment_assignments/${assignment.id}`, {
    equipment_assignment: { ended_on: new Date().toISOString().slice(0, 10) }
  })
  await fetchEquipment()
}

onMounted(fetchEquipment)
</script>

<template>
  <MainLayout>
    <v-btn variant="text" prepend-icon="mdi-arrow-left" class="mb-2" @click="router.push('/equipments')">
      設備一覧に戻る
    </v-btn>

    <v-skeleton-loader v-if="loading" type="card" />

    <template v-else-if="equipment">
      <v-card class="mb-4">
        <v-card-title class="d-flex align-center">
          {{ equipment.name }}
          <v-spacer />
          <v-btn v-if="canManageEquipment" variant="outlined" size="small" prepend-icon="mdi-pencil" @click="openEditEquipment">編集</v-btn>
        </v-card-title>
        <v-card-subtitle v-if="equipment.site">{{ equipment.site?.name }}</v-card-subtitle>
        <v-card-text>
          <p v-if="equipment.description">{{ equipment.description }}</p>
          <v-row class="mt-2">
            <v-col cols="6" md="3">
              <v-card variant="tonal" class="text-center pa-3">
                <div class="text-h5">{{ equipment.instruments?.length || 0 }}</div>
                <div class="text-body-2">計器数</div>
              </v-card>
            </v-col>
            <v-col cols="6" md="3">
              <v-card variant="tonal" class="text-center pa-3">
                <div class="text-h5">{{ equipment.troubles_count || 0 }}</div>
                <div class="text-body-2">トラブル</div>
              </v-card>
            </v-col>
          </v-row>
        </v-card-text>
      </v-card>

      <v-tabs v-model="tab" class="mb-4">
        <v-tab value="instruments">装置・計器</v-tab>
        <v-tab value="assignments">設備担当</v-tab>
        <v-tab value="maintenances">定期整備</v-tab>
        <v-tab value="history">変更履歴</v-tab>
      </v-tabs>

      <v-window v-model="tab">
        <v-window-item value="instruments">
          <v-data-table
            :headers="[
              { title: 'タグナンバー', key: 'tag_number' },
              { title: '種別', key: 'instrument_type' },
              { title: '設置場所', key: 'location' },
            ]"
            :items="equipment.instruments || []"
            hover
            class="cursor-pointer"
            @click:row="(_e: any, { item }: any) => router.push(`/instruments/${item.id}`)"
          />
        </v-window-item>

        <v-window-item value="assignments">
          <div class="d-flex align-center mb-2">
            <h3 class="text-subtitle-1">現任担当者</h3>
            <v-spacer />
            <v-btn v-if="canManageEquipmentAssignment" size="small" color="primary" prepend-icon="mdi-plus" @click="openAssignDialog">担当追加</v-btn>
          </div>
          <v-list v-if="currentAssignments().length">
            <v-list-item
              v-for="a in currentAssignments()"
              :key="a.id"
              :title="a.user?.name"
              :subtitle="`${a.role} / ${a.started_on}〜`"
            >
              <template #append>
                <v-btn v-if="canManageEquipmentAssignment" size="small" variant="outlined" color="warning" @click="endAssignment(a)">
                  担当終了
                </v-btn>
              </template>
            </v-list-item>
          </v-list>
          <p v-else class="text-body-2 text-grey ml-4">現任担当者なし</p>

          <v-divider class="my-4" />

          <h3 class="text-subtitle-1 mb-2">担当履歴</h3>
          <v-list v-if="pastAssignments().length">
            <v-list-item
              v-for="a in pastAssignments()"
              :key="a.id"
              :title="a.user?.name"
              :subtitle="`${a.role} / ${a.started_on}〜${a.ended_on}`"
            />
          </v-list>
          <p v-else class="text-body-2 text-grey ml-4">履歴なし</p>
        </v-window-item>

        <v-window-item value="maintenances">
          <v-list v-if="(equipment.scheduled_maintenances || []).length">
            <v-list-item
              v-for="m in equipment.scheduled_maintenances"
              :key="m.id"
              :title="m.title"
              :subtitle="`予定日: ${m.scheduled_date}`"
            >
              <template #append>
                <v-chip :color="m.status === 'completed' ? 'success' : m.status === 'in_progress' ? 'warning' : 'info'" size="small">
                  {{ { planned: '計画中', in_progress: '実施中', completed: '完了' }[m.status as string] || m.status }}
                </v-chip>
              </template>
            </v-list-item>
          </v-list>
          <p v-else class="text-body-2 text-grey ml-4">定期整備の予定なし</p>
        </v-window-item>

        <v-window-item value="history">
          <ResourceHistory auditable-type="Equipment" :auditable-id="equipment.id" />
        </v-window-item>
      </v-window>
    </template>

    <!-- 設備編集ダイアログ -->
    <v-dialog v-model="editDialog" max-width="500">
      <v-card>
        <v-card-title>設備編集</v-card-title>
        <v-card-text>
          <v-alert v-if="editErrors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in editErrors" :key="err">{{ err }}</div>
          </v-alert>
          <v-select v-model="editForm.site_id" :items="sites" item-title="name" item-value="id" label="拠点" class="mb-2" />
          <v-text-field v-model="editForm.name" label="設備名" class="mb-2" />
          <v-textarea v-model="editForm.description" label="説明" rows="3" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="editDialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="saveEquipment">保存</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 担当追加ダイアログ -->
    <v-dialog v-model="assignDialog" max-width="500">
      <v-card>
        <v-card-title>担当追加</v-card-title>
        <v-card-text>
          <v-alert v-if="assignErrors.length" type="error" density="compact" class="mb-4">
            <div v-for="err in assignErrors" :key="err">{{ err }}</div>
          </v-alert>
          <v-select v-model="assignForm.user_id" :items="users" item-title="name" item-value="id" label="担当者 *" class="mb-2" />
          <v-text-field v-model="assignForm.role" label="役割" class="mb-2" />
          <v-text-field v-model="assignForm.started_on" label="開始日 *" type="date" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="assignDialog = false">キャンセル</v-btn>
          <v-btn color="primary" @click="saveAssignment">追加</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
