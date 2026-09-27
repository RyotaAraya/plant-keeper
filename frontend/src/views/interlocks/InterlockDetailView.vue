<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import api from '@/api/axios'
import BypassActions from '@/components/BypassActions.vue'
import BypassRequestDialog from '@/components/BypassRequestDialog.vue'
import BypassSteps from '@/components/BypassSteps.vue'
import InterlockFormDialog from '@/components/InterlockFormDialog.vue'
import DetailHeader from '@/components/layout/DetailHeader.vue'
import StatusChip from '@/components/StatusChip.vue'
import MainLayout from '@/components/layout/MainLayout.vue'
import ResourceHistory from '@/components/ResourceHistory.vue'
import { usePermissions } from '@/composables/usePermissions'
import type { Interlock } from '@/types/models'
import { bypassColor, bypassLabel, formatDateTime, formatHours, restoreDueLabel } from '@/utils/interlock'

const route = useRoute()
const { canManageInterlock, canRequestBypass } = usePermissions()

const interlock = ref<Interlock | null>(null)
const loading = ref(false)
const tab = ref('bypasses')
const editDialog = ref(false)
const requestDialog = ref(false)

async function fetchInterlock() {
  loading.value = true
  try {
    interlock.value = (await api.get(`/interlocks/${route.params.id}`)).data.data
  } finally {
    loading.value = false
  }
}

const current = computed(() => interlock.value?.open_bypass ?? null)
const canRequest = computed(() => canRequestBypass.value && !!interlock.value?.is_active && !current.value)

onMounted(fetchInterlock)
</script>

<template>
  <MainLayout>
    <v-skeleton-loader v-if="loading && !interlock" type="card" />

    <template v-else-if="interlock">
      <DetailHeader back-to="/interlocks" back-label="インターロック" kind="インターロック" :title="`${interlock.tag_number} ${interlock.name}`">
        <template #status>
          <StatusChip v-if="!interlock.is_active" label="廃止" color="grey" />
        </template>
        <template #meta>
          {{ interlock.equipment.site.name }} ／ <router-link :to="`/equipments/${interlock.equipment.id}`">{{ interlock.equipment.name }}</router-link>
        </template>
        <template #actions>
          <v-btn v-if="canManageInterlock" variant="outlined" prepend-icon="mdi-pencil" @click="editDialog = true">編集</v-btn>
        </template>
      </DetailHeader>
      <v-card class="mb-4" data-testid="detail-summary">
        <v-card-text>
          <p class="mb-2"><strong>トリップ時の動作:</strong> {{ interlock.trip_action || '—' }}</p>
          <div class="d-flex align-center flex-wrap ga-2 mb-2">
            <strong>関係する計器:</strong>
            <v-chip v-for="i in interlock.instruments" :key="i.id" size="small" label :to="`/instruments/${i.id}`">{{ i.tag_number }}</v-chip>
            <span v-if="!interlock.instruments.length" class="text-medium-emphasis">—</span>
          </div>
          <p v-if="interlock.notes"><strong>備考:</strong> {{ interlock.notes }}</p>
        </v-card-text>
      </v-card>

      <v-card class="mb-4" :color="current?.overdue ? 'error' : current?.status === 'bypassed' ? 'warning' : undefined" variant="tonal" data-testid="current-bypass">
        <v-card-title class="d-flex align-center flex-wrap ga-2">
          <v-icon>{{ current?.status === 'bypassed' ? 'mdi-shield-off-outline' : 'mdi-shield-check-outline' }}</v-icon>
          <span>いまのバイパス</span>
          <template v-if="current">
            <StatusChip :label="bypassLabel(current)" :color="bypassColor(current)" :alert="current.overdue" />
            <span class="text-body-2">{{ current.request_number }}</span>
          </template>
          <v-spacer />
          <v-btn v-if="canRequest" color="primary" size="small" prepend-icon="mdi-shield-edit-outline" data-testid="bypass-request" @click="requestDialog = true">バイパスを申請</v-btn>
        </v-card-title>
        <v-card-text v-if="current" class="text-high-emphasis">
          <v-row dense class="mb-2">
            <v-col cols="12" md="6"><strong>理由:</strong> {{ current.reason }}</v-col>
            <v-col cols="12" md="6">
              <strong>予定の復帰:</strong> {{ formatDateTime(current.planned_restore_at) }}
              <span v-if="current.status === 'bypassed'">（{{ restoreDueLabel(current) }}・バイパスして {{ formatHours(current.bypassed_hours) }}）</span>
            </v-col>
            <v-col cols="12"><strong>代替措置:</strong> {{ current.compensatory_measure }}</v-col>
          </v-row>
          <BypassSteps :bypass="current" class="mb-3" />
          <BypassActions :bypass="current" @changed="fetchInterlock" />
        </v-card-text>
        <v-card-text v-else>
          インターロックは働いています（終わっていないバイパスはありません）。
        </v-card-text>
      </v-card>

      <v-tabs v-model="tab" class="mb-4">
        <v-tab value="bypasses">バイパスの履歴</v-tab>
        <v-tab value="history">変更履歴</v-tab>
      </v-tabs>

      <v-window v-model="tab">
        <v-window-item value="bypasses">
          <v-table density="compact">
            <thead>
              <tr class="text-no-wrap">
                <th>申請番号</th>
                <th>状態</th>
                <th>理由</th>
                <th>申請</th>
                <th>バイパス</th>
                <th>復帰</th>
                <th>確認・却下・取消</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!interlock.bypasses?.length">
                <td colspan="7" class="text-center text-grey py-4">バイパスの記録はありません</td>
              </tr>
              <tr v-for="b in interlock.bypasses" :key="b.id">
                <td class="text-no-wrap">{{ b.request_number }}</td>
                <td><v-chip :color="bypassColor(b)" size="x-small" label variant="tonal">{{ bypassLabel(b) }}</v-chip></td>
                <td>
                  {{ b.reason }}
                  <div v-if="b.closed_reason" class="text-caption text-medium-emphasis">{{ b.closed_reason }}</div>
                </td>
                <td class="text-no-wrap">{{ b.requested_by?.name }}<div class="text-caption">{{ formatDateTime(b.requested_at) }}</div></td>
                <td class="text-no-wrap">{{ b.bypassed_by?.name ?? '—' }}<div class="text-caption">{{ b.bypassed_at ? formatDateTime(b.bypassed_at) : '' }}</div></td>
                <td class="text-no-wrap">{{ b.restored_by?.name ?? '—' }}<div class="text-caption">{{ b.restored_at ? formatDateTime(b.restored_at) : '' }}</div></td>
                <td class="text-no-wrap">
                  {{ (b.confirmed_by ?? b.closed_by)?.name ?? '—' }}
                  <div class="text-caption">{{ formatDateTime(b.confirmed_at ?? b.closed_at) === '—' ? '' : formatDateTime(b.confirmed_at ?? b.closed_at) }}</div>
                </td>
              </tr>
            </tbody>
          </v-table>
        </v-window-item>
        <v-window-item value="history">
          <ResourceHistory auditable-type="Interlock" :auditable-id="interlock.id" />
        </v-window-item>
      </v-window>
    </template>

    <InterlockFormDialog v-model="editDialog" :interlock="interlock" @saved="fetchInterlock" />
    <BypassRequestDialog v-model="requestDialog" :interlock="interlock" @saved="fetchInterlock" />
  </MainLayout>
</template>
