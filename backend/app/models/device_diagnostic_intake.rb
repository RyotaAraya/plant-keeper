# 機器管理システムから届いた診断（1件分）を、計器のいまの状態と履歴に反映する。
# - 計器はトークンの拠点のタグ番号で探す（別の拠点の計器は受け付けない）
# - 状態・コード・内容がいまと同じなら、履歴は増やさず、最後に受け取った日時だけ更新する（定期的に同じ状態が送られてくるため）
# - いまの状態より古い日時の診断は、順番が入れ替わって届いたものとして反映しない
# - 未来の日時（時計のずれの許容を超えるもの）は受け付けない（反映すると、それより前の正しい診断がすべて古い扱いになるため）
class DeviceDiagnosticIntake
  Result = Data.define(:tag_number, :result, :errors)
  CLOCK_SKEW = 5.minutes

  def initialize(token, now: Time.current)
    @token = token
    @now = now
  end

  def call(item)
    item = item.to_h.stringify_keys
    tag = item["tag_number"].to_s.strip
    errors = []
    instrument = Instrument.joins(:equipment).find_by(tag_number: tag, equipments: { site_id: @token.site_id }) if tag.present?
    errors << "タグ番号 #{tag.presence || '（空）'} の計器が、#{@token.site.name}にありません" unless instrument
    status = InstrumentDiagnostic.normalize_status(item["status"])
    errors << "状態 #{item['status'].inspect} は分かりません（N/F/C/S/M か good/failure/function_check/out_of_specification/maintenance_required）" unless status
    occurred_at = parse_time(item["occurred_at"])
    if occurred_at.nil?
      errors << "発生日時 #{item['occurred_at'].inspect} を読めません（ISO 8601 で送ってください）"
    elsif occurred_at > @now + CLOCK_SKEW
      errors << "発生日時 #{item['occurred_at']} が未来です（送る側の時計・タイムゾーンを確かめてください）"
    end
    return Result.new(tag, "error", errors) if errors.any?

    apply(instrument, status, item["code"].presence&.to_s&.strip, item["message"].presence&.to_s&.strip, occurred_at)
  end

  private

  def apply(instrument, status, code, message, occurred_at)
    instrument.with_lock do
      latest = instrument.instrument_diagnostics.order(occurred_at: :desc, id: :desc).first
      next Result.new(instrument.tag_number, "stale", []) if latest && occurred_at < latest.occurred_at

      if latest && [ latest.status, latest.code, latest.message ] == [ status, code, message ]
        instrument.update_columns(diagnostic_received_at: @now)
        next Result.new(instrument.tag_number, "unchanged", [])
      end

      diagnostic = instrument.instrument_diagnostics.new(status: status, code: code, message: message, occurred_at: occurred_at, integration_token: @token)
      next Result.new(instrument.tag_number, "error", diagnostic.errors.full_messages) unless diagnostic.save

      instrument.update_columns(diagnostic_status: status, diagnostic_since: occurred_at, diagnostic_received_at: @now)
      Result.new(instrument.tag_number, "changed", [])
    end
  end

  def parse_time(value)
    return if value.blank?

    Time.zone.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end
end
