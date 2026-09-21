// 現場メモに似た過去のトラブルを、AIに探してもらう（要求仕様書 2.5.1）。
// AIは候補を選んで対応を要約するだけで、何も変えない。使えない・失敗したときも、画面のほかの操作には影響しない
import { ref } from 'vue'
import api from '@/api/axios'
import { latestGuard } from '@/utils/latestGuard'
import type { AiSimilarTroubles } from '@/types/models'

interface SearchParams {
  equipmentId: number | null
  instrumentId: number | null
  memo: string
  // トラブルの詳細から探すときの、そのトラブル自身（候補から外す）
  excludeTroubleId?: number
}

// onRemaining: 今日の残り回数が分かったときに、画面の表示を合わせる
export function useSimilarTroubles(onRemaining: (count: number) => void) {
  const loading = ref(false)
  const error = ref('')
  const result = ref<AiSimilarTroubles | null>(null)
  // 探している間に、入力やトラブルが変わる（clear）ことがある。古い検索の結果は、あとから返っても反映しない
  const guard = latestGuard()

  async function search(params: SearchParams) {
    if (!params.equipmentId) {
      error.value = '先に設備を選んでください'
      return
    }
    const isLatest = guard()
    loading.value = true
    error.value = ''
    result.value = null
    try {
      const res = await api.post('/ai/similar_troubles', {
        equipment_id: params.equipmentId,
        instrument_id: params.instrumentId,
        memo: params.memo,
        exclude_trouble_id: params.excludeTroubleId,
      })
      // 残り回数は、どの検索でも本人のものなので、古い検索でも合わせる
      onRemaining(res.data.data.remaining_today)
      if (!isLatest()) return
      result.value = res.data.data
    } catch (e: any) {
      // 失敗・上限も回数に数えるため、画面の残り回数を実際に合わせる
      const left = e.response?.data?.remaining_today
      if (typeof left === 'number') onRemaining(left)
      if (!isLatest()) return
      error.value = e.response?.data?.errors?.[0] || 'AIから類似トラブルを取得できませんでした'
    } finally {
      if (isLatest()) loading.value = false
    }
  }

  // 結果とエラーを消し、進行中の検索は無効にする（あとから返っても反映しない）
  function clear() {
    guard()
    result.value = null
    error.value = ''
    loading.value = false
  }

  return { loading, error, result, search, clear }
}
