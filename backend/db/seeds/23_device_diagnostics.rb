# frozen_string_literal: true

puts "機器の自己診断（NAMUR NE 107）のデモを作成中..."

# 定義は db/data/device_diagnostics.rb（既存環境へは SeedDeviceDiagnostics マイグレーションで反映する）
require Rails.root.join("db/data/device_diagnostics")

now = Time.current
site = Site.find_by!(name: DeviceDiagnosticCatalog::SITE)
spec = DeviceDiagnosticCatalog::TOKEN
token, = IntegrationToken.issue!(name: spec[:name], site: site, created_by: User.find_by!(email: spec[:created_by]))
token.update!(created_at: now - spec[:hours_ago].hours, last_used_at: now - DeviceDiagnosticCatalog::RECEIVED_HOURS_AGO.hours)

DeviceDiagnosticCatalog::HISTORIES.each do |tag, history|
  instrument = Instrument.joins(:equipment).find_by!(tag_number: tag, equipments: { site_id: site.id })
  history.each do |entry|
    instrument.instrument_diagnostics.create!(status: entry[:status], code: entry[:code], message: entry[:message],
                                              occurred_at: now - entry[:hours_ago].hours, integration_token: token)
  end
  instrument.update_columns(diagnostic_status: history.last[:status], diagnostic_since: now - history.last[:hours_ago].hours,
                            diagnostic_received_at: now - DeviceDiagnosticCatalog::RECEIVED_HOURS_AGO.hours)
end

# 診断のある計器の点検計画（前倒しの候補・自動のトラブルの担当部署のデモ）
today = InspectionPlan.today
DeviceDiagnosticCatalog::PLANS.each do |spec|
  instrument = Instrument.joins(:equipment).find_by!(tag_number: spec[:tag], equipments: { site_id: site.id })
  last = today - spec[:last_days_ago]
  InspectionPlan.create!(name: spec[:name], equipment: instrument.equipment, instrument: instrument,
                         checklist_template: ChecklistTemplate.find_by!(name: spec[:template]), inspection_type: "periodic",
                         interval_days: spec[:interval], last_inspected_on: last, next_due_on: last + spec[:interval])
end

# いま故障の計器（TV-602）は、受け口と同じく診断からトラブルを作る
Instrument.where(diagnostic_status: "failure").find_each do |instrument|
  DiagnosticTrouble.create_for(instrument.instrument_diagnostics.order(occurred_at: :desc, id: :desc).first)
end
