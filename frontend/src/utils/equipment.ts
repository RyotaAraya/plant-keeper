// 複数の設備をまとめて持つ記録（点検・点検計画）の設備。代表の設備（equipment_id）が先頭
export interface NamedEquipment {
  id: number
  name: string
}

interface CoversEquipment {
  equipment_id?: number | null
  equipment?: NamedEquipment | null
  equipments?: NamedEquipment[]
}

export function coveredEquipments(record: CoversEquipment | null | undefined): NamedEquipment[] {
  if (!record) return []
  const list = record.equipments?.length ? record.equipments : record.equipment ? [record.equipment] : []
  return [...list].sort((a, b) => Number(b.id === record.equipment_id) - Number(a.id === record.equipment_id))
}

// 「常圧蒸留装置、重油間接脱硫装置」のように、すべて並べる
export function equipmentNames(record: CoversEquipment | null | undefined): string {
  return coveredEquipments(record).map((e) => e.name).join('、')
}

// 「常圧蒸留装置 ほか2設備」のように、狭い場所向けに短くする
export function equipmentSummary(record: CoversEquipment | null | undefined): string {
  const list = coveredEquipments(record)
  const name = list[0]?.name ?? ''
  return list.length > 1 ? `${name} ほか${list.length - 1}設備` : name
}
