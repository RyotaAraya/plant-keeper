// 入出庫（出庫・廃棄・移動・入庫）できる在庫の状態。バックエンドの Stock::TRANSACTABLE_STATUSES のミラー
// 修理待ち・修理中の在庫は修理管理の操作だけで変え、廃棄済みは動かさない
export const TRANSACTABLE_STOCK_STATUSES = ['available', 'in_use']

export function canTransactStock(status: string | undefined): boolean {
  return !!status && TRANSACTABLE_STOCK_STATUSES.includes(status)
}
