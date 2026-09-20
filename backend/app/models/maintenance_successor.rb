# 定期整備の「次回を作る」の提案。
# 系列の定期整備なら、日付は前回の予定開始日から系列の最短の周期だけ先に仮置きし、対象設備は、設備ごとの周期から
# 次回の日付までに周期が来ているもの（前回までに最後に含めた日から、周期の月数 − 1か月を過ぎたもの）を入れる。
# 系列に属さない定期整備は、対象設備をそのまま引き継ぎ、日付は利用者が入力する（提案は空）。
# 名称の年は次回の年に進める（年がなければ、先頭に付ける）。提案は仮で、確認のうえ手で直せる
class MaintenanceSuccessor
  YEAR_PATTERN = /\d{4}年/

  def initialize(maintenance)
    @maintenance = maintenance
    @series = maintenance.maintenance_series
  end

  def suggestion
    start_on = next_start_on
    {
      "title" => next_title(start_on),
      "planned_start_on" => start_on,
      "planned_end_on" => next_end_on(start_on),
      "equipments" => candidates(start_on),
      "assignments_count" => @maintenance.maintenance_assignments.size
    }
  end

  private

  def next_start_on
    return unless @series && intervals.any?

    @maintenance.planned_start_on + intervals.values.min.months
  end

  def next_end_on(start_on)
    return unless start_on && @maintenance.planned_end_on

    start_on + (@maintenance.planned_end_on - @maintenance.planned_start_on).to_i
  end

  def next_title(start_on)
    return @maintenance.title unless start_on

    year = "#{start_on.year}年"
    @maintenance.title.match?(YEAR_PATTERN) ? @maintenance.title.sub(YEAR_PATTERN, year) : "#{year} #{@maintenance.title}"
  end

  # 系列の設備と、今回の対象設備。入れる（included）かと、その理由を付ける
  def candidates(start_on)
    source_ids = @maintenance.equipment_ids
    ids = (intervals.keys + source_ids).uniq
    equipments = Equipment.where(id: ids).index_by(&:id)
    ids.filter_map { |id| equipments[id] }.sort_by(&:id).map { |equipment| candidate(equipment, start_on) }
  end

  def candidate(equipment, start_on)
    interval = intervals[equipment.id]
    last_on = last_included_on(equipment.id)
    included, reason =
      if @series.nil?
        [ true, "今回の対象設備を引き継ぐ" ]
      elsif interval.nil?
        [ false, "系列の周期が未登録" ]
      elsif last_on.nil?
        [ true, "#{interval}か月周期・これまでの実績なし" ]
      elsif start_on && start_on >= last_on + (interval - 1).months
        [ true, "#{interval}か月周期・前回 #{last_on}（周期が来ている）" ]
      else
        [ false, "#{interval}か月周期・前回 #{last_on}（まだ周期が来ていない）" ]
      end
    { "id" => equipment.id, "name" => equipment.name, "interval_months" => interval, "last_included_on" => last_on, "included" => included, "reason" => reason }
  end

  def intervals
    @intervals ||= @series ? @series.intervals : {}
  end

  # 系列の定期整備のうち、その設備を最後に対象にした予定開始日
  def last_included_on(equipment_id)
    return unless @series

    ScheduledMaintenanceEquipment.joins(:scheduled_maintenance)
                                 .where(equipment_id: equipment_id, scheduled_maintenances: { maintenance_series_id: @series.id })
                                 .maximum("scheduled_maintenances.planned_start_on")
  end
end
