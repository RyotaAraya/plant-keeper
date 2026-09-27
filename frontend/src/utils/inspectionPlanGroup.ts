import type { InspectionPlanGroup } from '@/types/models'

// まとまりの表示名。拠点が1つに決まらないときは、拠点名を付けて区別する（どの拠点にも「伝送器 月次点検」がある）
export function groupLabel(group: Pick<InspectionPlanGroup, 'name' | 'site'>, withSite: boolean) {
  return withSite && group.site ? `${group.site.name} ${group.name}` : group.name
}
