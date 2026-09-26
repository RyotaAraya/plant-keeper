<script setup lang="ts">
// バイパスの状態に応じて、いまのユーザが次にできる操作のボタンを出す（承認・却下・実施・復帰・復帰の確認・取消）。
// 判定はバックエンド（InterlockBypassPolicy と InterlockBypass の、申請した本人は承認できない・復帰した本人は確認できない）と同じ
import { computed, ref } from 'vue'
import api from '@/api/axios'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import type { InterlockBypass } from '@/types/models'

const props = defineProps<{ bypass: InterlockBypass }>()
const emit = defineEmits<{ changed: [] }>()

const { canApproveBypass, canConfirmBypass } = usePermissions()
const authStore = useAuthStore()
const me = computed(() => authStore.user?.id)

type Action = 'approve' | 'reject' | 'start' | 'restore' | 'confirm' | 'cancel'
interface ActionDef { action: Action; label: string; color: string; variant: 'flat' | 'outlined' | 'text'; confirm: string; needsReason?: boolean }

const ACTIONS: Record<Action, ActionDef> = {
  approve: { action: 'approve', label: '承認', color: 'primary', variant: 'flat', confirm: '理由と代替措置を確認し、このバイパスを承認します。' },
  reject: { action: 'reject', label: '却下', color: 'error', variant: 'text', confirm: 'このバイパスの申請を却下します。', needsReason: true },
  start: { action: 'start', label: 'バイパスを実施', color: 'warning', variant: 'flat', confirm: '現場でバイパスしたことを記録します。ここから、インターロックは働いていない扱いになります。' },
  restore: { action: 'restore', label: '復帰した', color: 'primary', variant: 'flat', confirm: 'バイパスを解除し、インターロックを復帰したことを記録します。別の人の確認で完了になります。' },
  confirm: { action: 'confirm', label: '復帰を確認', color: 'success', variant: 'flat', confirm: 'インターロックが正常に復帰していること（バイパスの解除・指示の正常）を確認しました。' },
  cancel: { action: 'cancel', label: '取消', color: 'grey', variant: 'text', confirm: 'このバイパスの申請を取り消します。', needsReason: true },
}

const isRequester = computed(() => props.bypass.requested_by?.id === me.value)
const isRestorer = computed(() => props.bypass.restored_by?.id === me.value)
const canCancel = computed(() => canApproveBypass.value || isRequester.value)

const available = computed<ActionDef[]>(() => {
  switch (props.bypass.status) {
    case 'requested':
      return [
        ...(canApproveBypass.value && !isRequester.value ? [ACTIONS.approve] : []),
        ...(canApproveBypass.value ? [ACTIONS.reject] : []),
        ...(canCancel.value ? [ACTIONS.cancel] : []),
      ]
    case 'approved':
      return [ACTIONS.start, ...(canCancel.value ? [ACTIONS.cancel] : [])]
    case 'bypassed':
      return [ACTIONS.restore]
    case 'restored':
      return canConfirmBypass.value && !isRestorer.value ? [ACTIONS.confirm] : []
    default:
      return []
  }
})

// 操作できない理由（ボタンが出ない代わりに出す）
const note = computed(() => {
  const status = props.bypass.status
  if (status === 'requested' && canApproveBypass.value && isRequester.value) return '自分の申請は、別の人が承認します'
  if (status === 'requested' && !canApproveBypass.value) return '管理者・自社の業務管理者の承認待ちです'
  if (status === 'restored' && isRestorer.value) return '復帰した人とは別の人が確認します'
  if (status === 'restored' && !canConfirmBypass.value) return '自社の保全員の確認待ちです'
  return ''
})

const dialog = ref(false)
const current = ref<ActionDef | null>(null)
const reason = ref('')
const errors = ref<string[]>([])
const saving = ref(false)

function openAction(def: ActionDef) {
  current.value = def
  reason.value = ''
  errors.value = []
  dialog.value = true
}

async function run() {
  if (!current.value) return
  saving.value = true
  errors.value = []
  try {
    await api.post(`/interlock_bypasses/${props.bypass.id}/${current.value.action}`, current.value.needsReason ? { reason: reason.value } : {})
    dialog.value = false
    emit('changed')
  } catch (e: any) {
    errors.value = e.response?.data?.errors || [e.response?.data?.error || '操作に失敗しました']
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="d-flex align-center flex-wrap ga-2">
    <v-btn
      v-for="def in available"
      :key="def.action"
      :color="def.color"
      :variant="def.variant"
      size="small"
      :data-testid="`bypass-${def.action}`"
      @click.stop="openAction(def)"
    >
      {{ def.label }}
    </v-btn>
    <span v-if="note" class="text-caption text-medium-emphasis">{{ note }}</span>

    <v-dialog v-model="dialog" max-width="480">
      <v-card v-if="current">
        <v-card-title>{{ current.label }}（{{ bypass.request_number }}）</v-card-title>
        <v-card-text>
          <p class="mb-3">{{ current.confirm }}</p>
          <v-alert v-if="errors.length" type="error" density="compact" class="mb-3">
            <div v-for="err in errors" :key="err">{{ err }}</div>
          </v-alert>
          <v-textarea v-if="current.needsReason" v-model="reason" label="理由 *" rows="2" data-testid="bypass-close-reason" />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="dialog = false">キャンセル</v-btn>
          <v-btn :color="current.color" variant="flat" :loading="saving" data-testid="bypass-action-submit" @click="run">{{ current.label }}</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>
