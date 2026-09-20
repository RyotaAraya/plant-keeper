# 点検で使った基準器と、使用前の1点チェックの結果（pre_check_passed: nil=未確認 / true=OK / false=NG）
class InspectionReferenceStandard < ApplicationRecord
  belongs_to :inspection
  belongs_to :reference_standard

  validates :reference_standard_id, uniqueness: { scope: :inspection_id }

  # 点検日に効いていた校正（証明書番号などをたどれるように、点検の詳細に出す）
  def calibration_at_inspection
    calibration = reference_standard.calibration_on(inspection.inspected_at.to_date)
    calibration&.as_json(only: [ :id, :performed_on, :performed_by, :certificate_number, :result, :traceable, :valid_until ])
  end
end
