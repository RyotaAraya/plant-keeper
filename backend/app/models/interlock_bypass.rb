# インターロックの一時的なバイパス（点検・故障のときに、インターロックを働かないようにする）。
# 申請中 → 承認済 → バイパス中 → 復帰済（確認待ち） → 完了 と進む。申請中は却下でき、申請中・承認済は取消できる。
# バイパス中はプラントを守る仕組みが外れているため、承認は申請した人と別の人が、復帰の確認は復帰した人と別の自社ユーザが行う。
# 申請には、バイパス中の代替措置（インターロックの代わりに、どう監視・保護するか）を必ず書く。
# 予定の復帰日時を過ぎてもバイパス中のものは、復帰期限超過として一覧・ダッシュボードで目立たせる
class InterlockBypass < ApplicationRecord
  STATUSES = %w[requested approved bypassed restored completed rejected cancelled].freeze
  # 終わっていない状態（1つのインターロックに1件だけ）
  OPEN_STATUSES = %w[requested approved bypassed restored].freeze
  STATUS_LABELS = {
    "requested" => "申請中", "approved" => "承認済", "bypassed" => "バイパス中", "restored" => "復帰確認待ち",
    "completed" => "完了", "rejected" => "却下", "cancelled" => "取消"
  }.freeze

  belongs_to :interlock
  belongs_to :requested_by, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :bypassed_by, class_name: "User", optional: true
  belongs_to :restored_by, class_name: "User", optional: true
  belongs_to :confirmed_by, class_name: "User", optional: true
  belongs_to :closed_by, class_name: "User", optional: true

  has_one :equipment, through: :interlock

  enum :status, STATUSES.index_by(&:itself), prefix: true

  validates :reason, :compensatory_measure, :planned_restore_at, :requested_at, presence: true
  validate :interlock_active, on: :create
  validate :planned_restore_after_request, on: :create
  validate :one_open_bypass_per_interlock, on: :create

  before_validation :assign_request_number, on: :create

  scope :open, -> { where(status: OPEN_STATUSES) }
  scope :overdue, ->(now = Time.current) { status_bypassed.where(planned_restore_at: ...now) }
  scope :for_sites, ->(site_ids) { joins(interlock: :equipment).where(equipments: { site_id: site_ids }) }

  class TransitionError < StandardError; end

  def open? = OPEN_STATUSES.include?(status)

  def overdue?(now = Time.current) = status_bypassed? && planned_restore_at < now

  # バイパスしてからの時間（時間。バイパス中のときだけ）
  def bypassed_hours(now = Time.current)
    return unless status_bypassed? && bypassed_at

    ((now - bypassed_at) / 3600).floor
  end

  def approve!(user)
    transition!(from: "requested", to: "approved", user: user, by: :approved_by, at: :approved_at) do
      "申請した人は、自分の申請を承認できません" if user.id == requested_by_id
    end
  end

  def start!(user)
    transition!(from: "approved", to: "bypassed", user: user, by: :bypassed_by, at: :bypassed_at)
  end

  def restore!(user)
    transition!(from: "bypassed", to: "restored", user: user, by: :restored_by, at: :restored_at)
  end

  def confirm!(user)
    transition!(from: "restored", to: "completed", user: user, by: :confirmed_by, at: :confirmed_at) do
      "復帰した人とは別の人が確認してください" if user.id == restored_by_id
    end
  end

  def reject!(user, reason)
    close!(from: "requested", to: "rejected", user: user, reason: reason)
  end

  def cancel!(user, reason)
    close!(from: %w[requested approved], to: "cancelled", user: user, reason: reason)
  end

  private

  def transition!(from:, to:, user:, by:, at:)
    ensure_status!(from, to)
    error = yield if block_given?
    raise TransitionError, error if error

    update!(status: to, by => user, at => Time.current)
  end

  def close!(from:, to:, user:, reason:)
    ensure_status!(from, to)
    raise TransitionError, "理由を入力してください" if reason.blank?

    update!(status: to, closed_by: user, closed_at: Time.current, closed_reason: reason)
  end

  def ensure_status!(from, to)
    return if Array(from).include?(status)

    raise TransitionError, "#{STATUS_LABELS[status]}のバイパスは、#{STATUS_LABELS[to]}にできません"
  end

  # 申請番号: BP-年-連番（年ごと・全拠点で通し）
  def assign_request_number
    return if request_number.present?

    year = (requested_at || Time.current).in_time_zone.year
    prefix = "BP-#{year}-"
    last = self.class.where("request_number LIKE ?", "#{prefix}%").maximum(:request_number)
    self.request_number = format("%s%04d", prefix, last ? last.delete_prefix(prefix).to_i + 1 : 1)
  end

  def interlock_active
    errors.add(:base, "廃止したインターロックはバイパスを申請できません") if interlock && !interlock.is_active
  end

  def planned_restore_after_request
    return if planned_restore_at.nil? || requested_at.nil?

    errors.add(:planned_restore_at, "は申請日時より後にしてください") if planned_restore_at <= requested_at
  end

  def one_open_bypass_per_interlock
    return if interlock_id.nil?

    open_one = self.class.open.where(interlock_id: interlock_id).first
    errors.add(:base, "このインターロックには、終わっていないバイパス（#{open_one.request_number}）があります") if open_one
  end
end
