# 計器の自己診断（NAMUR NE 107）の状態が変わった記録。
# 状態は 正常 / 故障（F: Failure）/ 機能点検中（C: Function check）/ 仕様外（S: Out of specification）/ 保守要求（M: Maintenance required）
class InstrumentDiagnostic < ApplicationRecord
  STATUSES = %w[good failure function_check out_of_specification maintenance_required].freeze
  # 送る側は NE 107 の記号（N/F/C/S/M）でも名前でもよい
  LETTERS = { "N" => "good", "F" => "failure", "C" => "function_check", "S" => "out_of_specification", "M" => "maintenance_required" }.freeze

  belongs_to :instrument
  belongs_to :integration_token, optional: true

  enum :status, STATUSES.index_by(&:itself), prefix: true

  validates :occurred_at, presence: true
  validates :code, length: { maximum: 100 }
  validates :message, length: { maximum: 1000 }

  # "F" / "failure" / "Failure" → "failure"。分からなければ nil
  def self.normalize_status(value)
    text = value.to_s.strip
    LETTERS[text.upcase] || STATUSES.find { |status| status == text.downcase }
  end
end
