# status の遷移を制限する。含めるモデルに STATUS_TRANSITIONS（{ "現在の状態" => %w[遷移できる状態...] }）を定義する。
# 新規作成時は対象外（シードや初期状態での作成は自由）。遷移表にない状態からは変更できない
module StatusTransitions
  extend ActiveSupport::Concern

  included do
    validate :status_transition_allowed, on: :update
  end

  private

  def status_transition_allowed
    return unless status_changed?
    return if self.class::STATUS_TRANSITIONS.fetch(status_was, []).include?(status)

    errors.add(:status, "「#{status_was}」から「#{status}」には変更できません")
  end
end
