<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import api from '@/api/axios'
import MainLayout from '@/components/layout/MainLayout.vue'
import { usePermissions } from '@/composables/usePermissions'

const route = useRoute()
const router = useRouter()
const { canManageEquipmentAssignment } = usePermissions()

const equipment = ref<any>(null)
const loading = ref(false)
const tab = ref('instruments')

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
        <v-card-title>{{ equipment.name }}</v-card-title>
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
          <h3 class="text-subtitle-1 mb-2">現任担当者</h3>
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
      </v-window>
    </template>
  </MainLayout>
</template>

<style scoped>
.cursor-pointer :deep(tbody tr) {
  cursor: pointer;
}
</style>
