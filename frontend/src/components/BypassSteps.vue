<script setup lang="ts">
// バイパスの各段階（申請・承認・実施・復帰・確認、または却下・取消）を、誰が・いつ行ったかの順に並べる
import { computed } from 'vue'
import type { InterlockBypass } from '@/types/models'
import { formatDateTime } from '@/utils/interlock'

const props = defineProps<{ bypass: InterlockBypass }>()

const steps = computed(() => {
  const b = props.bypass
  const requested = { label: '申請', user: b.requested_by, at: b.requested_at as string | null }
  const list = [
    requested,
    { label: '承認', user: b.approved_by, at: b.approved_at },
    { label: 'バイパス実施', user: b.bypassed_by, at: b.bypassed_at },
    { label: '復帰', user: b.restored_by, at: b.restored_at },
    { label: '復帰の確認', user: b.confirmed_by, at: b.confirmed_at },
  ]
  if (b.status === 'rejected' || b.status === 'cancelled') {
    return [requested, ...list.slice(1).filter((s) => s.at), { label: b.status === 'rejected' ? '却下' : '取消', user: b.closed_by, at: b.closed_at }]
  }
  return list
})
</script>

<template>
  <ol class="pk-bypass-steps">
    <li v-for="step in steps" :key="step.label" :class="{ 'is-done': !!step.at }">
      <span class="pk-bypass-steps__label">{{ step.label }}</span>
      <span v-if="step.at" class="pk-bypass-steps__who">{{ step.user?.name }}<small>{{ formatDateTime(step.at) }}</small></span>
      <span v-else class="pk-bypass-steps__who text-medium-emphasis">—</span>
    </li>
  </ol>
</template>

<style scoped>
.pk-bypass-steps { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 8px; padding: 0; list-style: none; }
.pk-bypass-steps li { padding: 8px 10px; border: 1px solid var(--pk-line); border-radius: 10px; background: #fff; }
.pk-bypass-steps li.is-done { border-color: var(--pk-steel); background: var(--pk-soft-blue); }
.pk-bypass-steps__label { display: block; font-size: 0.75rem; color: var(--pk-muted); }
.pk-bypass-steps__who { display: block; font-size: 0.875rem; }
.pk-bypass-steps__who small { display: block; color: var(--pk-muted); font-size: 0.75rem; }
</style>
