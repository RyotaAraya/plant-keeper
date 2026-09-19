import { ref } from 'vue'
import api from '@/api/axios'

// 選んだ拠点に属する設備・部署の選択肢。一覧の絞り込みで、表示する拠点の分だけを出すために使う。
// 部署名は拠点間で重複する（どの拠点にも「保全部」がある）ので、拠点が1つに決まらないときは拠点名を付けて区別する
export function useSiteScopeOptions({ withDepartments = true } = {}) {
  const equipments = ref<any[]>([])
  const departments = ref<any[]>([])

  // 拠点を続けて切り替えると取得が重なるため、最新の取得だけを反映する
  let seq = 0

  // siteIds が空のときは全拠点
  async function load(siteIds: number[]) {
    const current = ++seq
    const params = siteIds.length ? { site_ids: siteIds } : {}
    const [equipmentRes, departmentRes] = await Promise.all([
      api.get('/equipments', { params: { ...params, per_page: 1000 } }),
      withDepartments ? api.get('/departments', { params }) : Promise.resolve(null),
    ])
    if (current !== seq) return

    equipments.value = equipmentRes.data.data
    if (!departmentRes) return

    const singleSite = siteIds.length === 1
    departments.value = departmentRes.data.data
      .map((d: any) => ({ ...d, display_name: singleSite ? d.full_path : `${d.site?.name ?? ''} ${d.full_path}` }))
      .sort((a: any, b: any) => a.display_name.localeCompare(b.display_name, 'ja'))
  }

  return { equipments, departments, load }
}
