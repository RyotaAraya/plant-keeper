import { ref } from 'vue'
import api from '@/api/axios'
import { usePermissions } from '@/composables/usePermissions'
import { useAuthStore } from '@/stores/auth'
import { siteIdsFromQuery } from '@/utils/listQuery'

// 拠点に属するデータの一覧の、表示する拠点（`SiteScopeTag` の値）の共通部分。
// 拠点の配列が空のときは全拠点を表す（絞り込みなし）

export type ScopedSite = { id: number; name: string }

export function useSiteScope() {
  const authStore = useAuthStore()
  const { canViewSites } = usePermissions()

  // 所属拠点だけ。所属拠点のない人は全拠点
  function ownSiteIds(): number[] {
    return authStore.user?.site_id ? [authStore.user.site_id] : []
  }

  // 一覧を開いたときの拠点。URL の `site_ids`（`1,2` / 全拠点は `all`）があればそちら、なければ所属拠点。
  // 拠点を切り替えられない人（協力会社）は、URL によらず所属拠点（`SiteScopeTag` の表示と中身をそろえる）
  function initialSiteIds(query?: unknown): number[] {
    if (!canViewSites.value) return ownSiteIds()
    return siteIdsFromQuery(query, ownSiteIds())
  }

  return { ownSiteIds, initialSiteIds }
}

// 表示する拠点に含まれるか（空は全拠点なので、常に含まれる）
export function inSites(siteIds: number[], siteId: number | null | undefined): boolean {
  return siteIds.length === 0 || (siteId != null && siteIds.includes(siteId))
}

// 選んでいるIDのうち、表示する拠点に属する選択肢のものだけを残す。拠点を切り替えたとき、見えなくなった設備・倉庫などの絞り込みを外すために使う
export function keepInSites(ids: number[], options: { id: number; site_id?: number | null }[], siteIds: number[]): number[] {
  return ids.filter((id) => options.some((o) => o.id === id && inSites(siteIds, o.site_id)))
}

// 単一選択（部署など）の版。表示する拠点のものでなければ null
export function keepOneInSites(id: number | null, options: { id: number; site_id?: number | null }[], siteIds: number[]): number | null {
  return id != null && keepInSites([id], options, siteIds).length ? id : null
}

// 稼働中の拠点の一覧（`SiteScopeTag` の選択肢）。一覧を開くたびに取り直さないよう、1回の取得を画面の間で共有する。
// 失敗したときは空のまま（切り替えのない、所属拠点の表示になる）にして、次に使うときに取り直す
const activeSites = ref<ScopedSite[]>([])
let activeSitesRequest: Promise<void> | null = null

export function useActiveSites() {
  function load(): Promise<void> {
    activeSitesRequest ??= api
      .get('/sites', { params: { per_page: 100, is_active: true } })
      .then((res) => {
        activeSites.value = res.data.data
      })
      .catch(() => {
        activeSitesRequest = null
      })
    return activeSitesRequest
  }

  return { sites: activeSites, load }
}

// 拠点を作成・変更したあと、次に使うときに取り直す
export function invalidateActiveSites() {
  activeSitesRequest = null
}
