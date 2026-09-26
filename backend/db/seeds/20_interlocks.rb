# frozen_string_literal: true

puts "インターロックの台帳と、バイパスの記録を作成中..."

# 定義は db/data/interlocks.rb（既存環境へは SeedInterlocks マイグレーションで反映する）
require Rails.root.join("db/data/interlocks")

interlocks = InterlockCatalog::INTERLOCKS.to_h do |attrs|
  equipment = Equipment.find_by!(site: Site.find_by!(name: attrs[:site]), name: attrs[:equipment])
  interlock = Interlock.create!(equipment: equipment, tag_number: attrs[:tag_number], name: attrs[:name], trip_action: attrs[:trip_action],
                                instruments: equipment.instruments.where(tag_number: attrs[:instruments]).to_a)
  [ [ attrs[:site], attrs[:tag_number] ], interlock ]
end

now = Time.current
at = ->(step) { step && { user: User.find_by!(email: step[0]), at: now - step[1].hours } }
InterlockCatalog::BYPASSES.each do |attrs|
  steps = %i[requested approved bypassed restored confirmed closed].index_with { |key| at.call(attrs[key]) }
  InterlockBypass.create!(
    interlock: interlocks.fetch(attrs[:interlock]), request_number: InterlockCatalog.request_number(attrs[:seq], now.year),
    status: attrs[:status], reason: attrs[:reason], compensatory_measure: attrs[:compensatory_measure],
    planned_restore_at: now + attrs[:restore_in_hours].hours, closed_reason: attrs[:closed_reason],
    **steps.compact.flat_map { |key, step| [ [ :"#{key}_by", step[:user] ], [ :"#{key}_at", step[:at] ] ] }.to_h
  )
end
