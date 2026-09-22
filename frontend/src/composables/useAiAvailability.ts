import { ref } from 'vue'
import api from '@/api/axios'
import type { AiStatus } from '@/types/models'

export function useAiAvailability() {
  const status = ref<AiStatus | null>(null)
  const loading = ref(true)
  const failed = ref(false)
  async function refresh() {
    loading.value = true
    failed.value = false
    try {
      status.value = (await api.get('/ai/status')).data.data
    } catch {
      failed.value = true
    } finally {
      loading.value = false
    }
  }
  return { status, loading, failed, refresh }
}
