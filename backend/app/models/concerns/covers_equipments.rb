# 複数の設備をまとめて持つ（点検・点検計画）。
# equipment_id は「代表の設備」（先頭）で、一覧・拠点の判定・集計に使う。代表の設備を含む全体は equipment_links
# （点検で見た設備・計画の対象設備の中間テーブル。含めるクラスが定義する）に持ち、同じ拠点の設備だけ。
# 画面から送られたとき（equipment_ids_input）だけ、保存後にその内容に合わせる。送られなければ変えない
# （代表の設備を変えたときは、その設備だけにする）
module CoversEquipments
  extend ActiveSupport::Concern

  included do
    attr_writer :equipment_ids_input
    validate :equipments_are_in_one_site
    after_save :sync_equipments
  end

  # 対象の設備のID（保存前の入力を含む。代表の設備が先頭）
  def covered_equipment_ids
    saved = @equipment_ids_input.nil? ? (persisted? ? equipment_links.pluck(:equipment_id) : []) : @equipment_ids_input
    ([ equipment_id ] + saved).compact.uniq
  end

  private

  # 複数の設備をまとめられるのは、同じ拠点の設備どうしだけ（定期整備の対象設備と同じ）
  def equipments_are_in_one_site
    ids = covered_equipment_ids
    return if ids.size <= 1

    found = Equipment.where(id: ids).pluck(:site_id)
    errors.add(:base, "選択した設備が見つかりません") if found.size != ids.size
    errors.add(:base, "まとめられるのは、同じ拠点の設備だけです") if found.uniq.size > 1
  end

  def sync_equipments
    ids = if !@equipment_ids_input.nil?
      covered_equipment_ids
    elsif saved_change_to_equipment_id?
      [ equipment_id ].compact
    else
      return
    end
    equipment_links.where.not(equipment_id: ids).destroy_all
    (ids - equipment_links.pluck(:equipment_id)).each { |id| equipment_links.create!(equipment_id: id) }
    equipments.reset
    @equipment_ids_input = nil
  end
end
