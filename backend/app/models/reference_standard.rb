# 基準器（校正に使う圧力校正器・マルチテスタ・温度校正器など）。
# 校正はメーカーが行い、その履歴（reference_standard_calibrations）から、点検日に使える基準器かを判定する。
# 基準器の年次校正は点検計画に載せる（作成時に自動で作る）
class ReferenceStandard < ApplicationRecord
  # 校正済みでなくなる前に知らせる日数
  EXPIRING_DAYS = 30
  DEFAULT_INTERVAL_DAYS = 365

  belongs_to :site

  has_many :calibrations, -> { order(performed_on: :desc, id: :desc) }, class_name: "ReferenceStandardCalibration", dependent: :restrict_with_error
  has_many :inspection_reference_standards, dependent: :restrict_with_error
  has_many :inspections, through: :inspection_reference_standards
  has_many :inspection_plans, dependent: :restrict_with_error

  # pressure=圧力・差圧 / electrical=電流・電圧 / temperature=温度
  enum :category, { pressure: "pressure", electrical: "electrical", temperature: "temperature", other: "other" }, prefix: true
  # usable=使用可 / in_calibration=校正中（メーカーに出している） / retired=使用停止
  enum :status, { usable: "usable", in_calibration: "in_calibration", retired: "retired" }, prefix: true

  STATUS_LABELS = { "usable" => "使用可", "in_calibration" => "校正中", "retired" => "使用停止" }.freeze

  validates :management_number, presence: true, uniqueness: true
  validates :name, presence: true

  after_create :create_calibration_plan
  after_update :sync_plan_activity, if: :saved_change_to_status?

  def latest_calibration = calibrations.first

  # 点検日に効いていた校正（その日以前で最新のもの）
  def calibration_on(date) = calibrations.detect { |calibration| calibration.performed_on <= date }

  # 次の校正の期限（最新の校正の有効期限。校正の記録がなければ nil）
  def next_due_on = latest_calibration&.valid_until

  # 今日の校正の状態: never=校正の記録なし / failed=最新の校正が不合格 / expired=有効期限切れ / expiring=期限間近 / valid
  def calibration_state(today = InspectionPlan.today)
    latest = latest_calibration
    return "never" if latest.nil?
    return "failed" if latest.result_fail?
    return "expired" if latest.valid_until < today

    latest.valid_until <= today + EXPIRING_DAYS ? "expiring" : "valid"
  end

  # 点検日 date に、この基準器を使えない理由。取引用の計器の点検では、トレーサビリティのある校正が必要
  def unusable_reasons(date, require_traceable: false)
    reasons = []
    reasons << "#{STATUS_LABELS[status]}のため使えません" unless status_usable?
    calibration = calibration_on(date)
    if calibration.nil?
      reasons << "点検日（#{date}）時点で有効な校正の記録がありません"
    elsif calibration.result_fail?
      reasons << "点検日時点の校正（#{calibration.performed_on}）が不合格です"
    elsif calibration.valid_until < date
      reasons << "点検日（#{date}）時点で校正の有効期限（#{calibration.valid_until}）が切れています"
    elsif require_traceable && !calibration.traceable
      reasons << "取引用の計器の点検には、トレーサビリティのある校正が必要です（点検日時点の校正は、トレーサビリティなし）"
    end
    reasons
  end

  private

  def create_calibration_plan
    inspection_plans.create!(
      name: "#{name} 年次校正", inspection_type: "periodic", interval_days: DEFAULT_INTERVAL_DAYS,
      next_due_on: InspectionPlan.today, is_active: !status_retired?
    )
  end

  # 使用停止にした基準器の校正計画は止め、使用可に戻したら再開する
  def sync_plan_activity
    inspection_plans.update_all(is_active: !status_retired?)
  end
end
