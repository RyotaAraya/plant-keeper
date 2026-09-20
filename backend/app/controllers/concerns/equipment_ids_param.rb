# 複数の設備をまとめて持つ記録（点検・点検計画）の、設備の指定（equipment_ids）を受け取る。
# equipment_ids が送られたら、先頭を代表の設備（equipment_id）にする（送られなければ equipment_id のまま）。
# record_params に equipment_ids を入れないこと（has_many の equipment_ids= が、検証なしに直接書き込むため）
module EquipmentIdsParam
  extend ActiveSupport::Concern

  private

  def equipment_ids_param(root)
    return unless params[root].key?(:equipment_ids)

    Array(params[root][:equipment_ids]).map(&:to_i).select(&:positive?).uniq.presence
  end

  def apply_equipment_ids(record, root)
    return unless (ids = equipment_ids_param(root))

    record.equipment_id = ids.first
    record.equipment_ids_input = ids
  end

  def equipment_ids_of(record) = record.equipment_links.pluck(:equipment_id).sort

  # 監査ログの変更内容。設備が2つ以上、または変わったときだけ、対象の設備のIDを [前, 後] で残す
  def equipment_ids_changes(before, record)
    after = record.equipment_links.reload.pluck(:equipment_id).sort
    return {} if before.nil? ? after.size < 2 : before == after

    { "equipment_ids" => [ before, after ] }
  end
end
