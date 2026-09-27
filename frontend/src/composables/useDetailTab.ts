import { computed, type Ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

// 詳細画面の「概要 → タブ」のタブ。選んだタブは URL の ?tab= で保つ（再読み込みで戻らない）。
// 既定のタブ（先頭）のときはクエリに出さない。知らない値・今は出していないタブは既定に戻す
export function useDetailTab(tabs: () => readonly string[]): Ref<string> {
  const route = useRoute()
  const router = useRouter()
  return computed({
    get: () => {
      const list = tabs()
      const value = route.query.tab as string
      return list.includes(value) ? value : (list[0] ?? '')
    },
    set: (value: string) => {
      void router.replace({ query: { ...route.query, tab: value === tabs()[0] ? undefined : value } })
    },
  })
}
