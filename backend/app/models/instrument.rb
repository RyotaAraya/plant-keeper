class Instrument < ApplicationRecord
  belongs_to :equipment
  belongs_to :service, optional: true
  belongs_to :line_class, optional: true

  has_many :inspections, dependent: :restrict_with_error
  has_many :inspection_items, dependent: :restrict_with_error
  has_many :troubles, dependent: :restrict_with_error
  has_many :interlock_instruments, dependent: :restrict_with_error
  has_many :interlocks, through: :interlock_instruments
  # 機器の自己診断（NAMUR NE 107）の状態が変わった記録。いまの状態は diagnostic_status に持つ
  has_many :instrument_diagnostics, dependent: :destroy

  # 校正の種類。伝送器（種別が *_transmitter）は出力（4-20mA）とDCS表示、調節弁はポジショナの開度を校正する
  CONTROL_VALVE_TYPES = %w[pressure_valve level_valve flow_valve temperature_valve].freeze
  CHARACTERISTICS = %w[linear square_root].freeze
  # legal=法令 / manufacturer=メーカー / internal=社内基準
  TOLERANCE_BASES = %w[legal manufacturer internal].freeze

  validates :tag_number, presence: true
  validate :tag_number_unique_within_site
  validates :output_characteristic, :dcs_characteristic, inclusion: { in: CHARACTERISTICS }
  validates :tolerance_basis, inclusion: { in: TOLERANCE_BASES }, allow_nil: true
  validates :tolerance_percent, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validate :ranges_are_valid

  def calibration_kind
    if CONTROL_VALVE_TYPES.include?(instrument_type)
      "positioner"
    elsif instrument_type.to_s.end_with?("_transmitter")
      "transmitter"
    end
  end

  # 5点校正ができる計器（校正範囲と許容差が設定済み）
  def calibratable? = calibration_kind.present? && range_lower.present? && range_upper.present? && tolerance_percent.present?
  alias_method :calibratable, :calibratable?

  # 不具合発見時にまず確認する、計器種別ごとの一次点検の定型項目（参考情報。InstrumentTroubleshootingCatalog）
  def troubleshooting_checks
    InstrumentTroubleshootingCatalog.for(instrument_type)
  end

  private

  # 範囲は下限と上限をセットで、上限が下限より大きいこと。DCSの範囲も同様で、DCSが平方根のときは必須
  # （平方根をとった流量は伝送器の入力と単位が違うため、伝送器の範囲では代用できない）
  def ranges_are_valid
    validate_range(:range_lower, :range_upper, "校正範囲")
    validate_range(:dcs_range_lower, :dcs_range_upper, "DCSの範囲")
    if dcs_characteristic == "square_root" && (dcs_range_lower.nil? || dcs_range_upper.nil?)
      errors.add(:base, "DCSが平方根の計器は、DCSの範囲（下限・上限）が必要です")
    end
  end

  def validate_range(lower_attr, upper_attr, label)
    lower = public_send(lower_attr)
    upper = public_send(upper_attr)
    if lower.nil? != upper.nil?
      errors.add(:base, "#{label}は下限と上限をセットで入力してください")
    elsif lower && upper <= lower
      errors.add(:base, "#{label}は、上限を下限より大きくしてください")
    end
  end

  # タグ番号は拠点内で一意（別拠点なら同じ番号があり得る）
  def tag_number_unique_within_site
    return if tag_number.blank? || equipment.nil?

    duplicates = Instrument.joins(:equipment)
                           .where(tag_number: tag_number, equipments: { site_id: equipment.site_id })
    duplicates = duplicates.where.not(id: id) if persisted?
    errors.add(:tag_number, :taken) if duplicates.exists?
  end
end
