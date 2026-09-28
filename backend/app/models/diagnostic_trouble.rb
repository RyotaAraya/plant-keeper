# 機器の自己診断が故障（F）になったとき、その計器のトラブルを作る（要求仕様書 2.9。ルールで判定し、AIは使わない）。
# - 同じ計器に、機器の診断から作った未解決（未対応・対応中・定修待ち）のトラブルがあれば作らない
#   （コードが変わっても・正常に戻ってまた故障になっても、同じ故障の続きとして重ねない。解決済・完了にしたあとの故障は新しく作る）
# - 報告者は連携用のトークンを発行した人（トラブルの報告者は必須のため）。出所を「機器の診断」にし、元の診断を持たせて、人が作ったものと区別する
# - 監査ログはユーザなし（連携からの記録）で、どの連携から来たか（トークンの名前）を残す
# 保守要求・仕様外は、トラブルにせず点検計画の前倒しの候補にする（InspectionPlan.diagnostic_advance_candidates）。機能点検中は作業中として扱い、何もしない
class DiagnosticTrouble
  OPEN_STATUSES = %w[open in_progress deferred].freeze
  PRIORITY = "high".freeze

  # 作ったトラブル。作らなかったときは nil
  def self.create_for(diagnostic)
    return unless diagnostic.status_failure?

    token = diagnostic.integration_token
    return unless token

    instrument = diagnostic.instrument
    return if Trouble.source_device_diagnostic.where(instrument_id: instrument.id, status: OPEN_STATUSES).exists?

    trouble = Trouble.create!(
      source: "device_diagnostic", instrument_diagnostic: diagnostic,
      equipment_id: instrument.equipment_id, instrument: instrument, reported_by_id: token.created_by_id,
      title: title(instrument, diagnostic), description: description(diagnostic, token),
      status: "open", priority: PRIORITY, reported_at: diagnostic.occurred_at
    )
    AuditLog.create!(user: nil, action: "create", auditable: trouble, performed_at: Time.current,
                     changes_json: trouble.saved_changes.except("updated_at", "created_at").merge("integration_token" => token.name))
    trouble
  end

  def self.title(instrument, diagnostic)
    "#{instrument.tag_number} 機器の診断で故障#{"（#{diagnostic.code}）" if diagnostic.code.present?}"
  end

  def self.description(diagnostic, token)
    [
      "機器管理システム（#{token.name}）から、故障（F）の診断を受け取りました。",
      ("内容: #{diagnostic.message}" if diagnostic.message.present?),
      ("コード: #{diagnostic.code}" if diagnostic.code.present?),
      "発生日時: #{diagnostic.occurred_at.in_time_zone.strftime('%Y-%m-%d %H:%M')}"
    ].compact.join("\n")
  end
end
