<script setup lang="ts">
// インターロックのバイパスの申請ダイアログ。バイパス中はプラントを守る仕組みが外れるため、代替措置（どう監視・保護するか）を必ず書く
import { ref, watch } from 'vue'
import api from '@/api/axios'
import { nowForInput } from '@/utils/datetime'

const props = defineProps<{ interlock: { id: number; tag_number: string; name: string } | null }>()
const open = defineModel<boolean>({ default: false })
const emit = defineEmits<{ saved: [] }>()

const errors = ref<string[]>([])
const saving = ref(false)
const form = ref({ reason: '', compensatory_measure: '', planned_restore_at: '' })

watch(open, (isOpen) => {
  if (!isOpen) return
  errors.value = []
  // 予定の復帰は、4時間後を初期値にする（点検・校正の半日程度の作業）
  form.value = { reason: '', compensatory_measure: '', planned_restore_at: nowForInput(new Date(Date.now() + 4 * 3600 * 1000)) }
})

async function save() {
  if (!props.interlock) return
  errors.value = []
  saving.value = true
  try {
    await api.post('/interlock_bypasses', { interlock_bypass: { interlock_id: props.interlock.id, ...form.value } })
    open.value = false
    emit('saved')
  } catch (e: any) {
    errors.value = e.response?.data?.errors || ['申請に失敗しました']
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <v-dialog v-model="open" max-width="600" scrollable>
    <v-card>
      <v-card-title>バイパスを申請</v-card-title>
      <v-card-subtitle v-if="interlock">{{ interlock.tag_number }} {{ interlock.name }}</v-card-subtitle>
      <v-card-text>
        <div class="text-caption text-medium-emphasis mb-3">
          承認されたら、現場でバイパスを実施して記録します。作業が終わったら復帰を記録し、別の人が復帰を確認して完了です。
        </div>
        <v-alert v-if="errors.length" type="error" density="compact" class="mb-4">
          <div v-for="err in errors" :key="err">{{ err }}</div>
        </v-alert>
        <v-textarea v-model="form.reason" label="理由 *" rows="2" placeholder="例: LT-701 の導圧管のブローのため" class="mb-2" data-testid="bypass-reason" />
        <v-textarea
          v-model="form.compensatory_measure"
          label="バイパス中の代替措置 *"
          rows="3"
          placeholder="例: 現場の液面計を運転員が1時間ごとに確認し、異常時は手動でボイラーを停止する"
          hint="インターロックの代わりに、誰が・何を見て・どうなったら止めるか"
          persistent-hint
          class="mb-4"
          data-testid="bypass-measure"
        />
        <v-text-field v-model="form.planned_restore_at" type="datetime-local" label="予定の復帰日時 *" hint="この日時を過ぎても復帰していなければ「復帰期限超過」になります" persistent-hint />
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="open = false">キャンセル</v-btn>
        <v-btn color="primary" :loading="saving" data-testid="bypass-request-submit" @click="save">申請</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>
