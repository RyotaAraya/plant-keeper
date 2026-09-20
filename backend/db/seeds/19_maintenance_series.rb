# frozen_string_literal: true

puts "定期整備の系列（A号ボイラー整備）を作成中..."

# 川崎製油所のA号ボイラーと発電設備の、繰り返しの定期整備。ボイラーは2年ごと、発電設備は4年ごと。
# 2022年（両方）→ 2024年（ボイラーのみ）→ 2026年（両方・計画中）。周期のとおりなので、2026年から「次回を作る」と2028年はボイラーだけになる
kawasaki = Site.find_by!(name: "川崎製油所")
boiler = Equipment.find_by!(site: kawasaki, name: "ボイラー設備")
generator = Equipment.find_by!(site: kawasaki, name: "発電設備")
instrument_section = Department.find_by!(name: "計装保全課", site: kawasaki)
electric_section = Department.find_by!(name: "電気保全課", site: kawasaki)
suzuki = User.find_by!(email: "suzuki@example.com")
fujita = User.find_by!(email: "fujita@example.com")
yamamoto = User.find_by!(email: "yamamoto@example.com")

series = MaintenanceSeries.create!(site: kawasaki, name: "A号ボイラー整備", notes: "A号ボイラーと、蒸気を受ける発電設備をまとめて止めて整備する。")
MaintenanceSeriesEquipment.create!(maintenance_series: series, equipment: boiler, interval_months: 24)
MaintenanceSeriesEquipment.create!(maintenance_series: series, equipment: generator, interval_months: 48)

# 済んだ回は、検収まで記録して完了にする
def create_round!(series, equipments:, title:, starts_on:, ends_on:, completed: false, description: nil)
  attrs = { site: series.site, maintenance_series: series, equipments: equipments, title: title, description: description,
            planned_start_on: starts_on, planned_end_on: ends_on }
  if completed
    attrs.merge!(status: "completed", actual_start_on: starts_on, actual_end_on: ends_on, accepted_on: ends_on,
                 accepted_by: User.find_by!(email: "suzuki@example.com"), acceptance_result: "passed")
  end
  ScheduledMaintenance.create!(**attrs)
end

# 設備の計器を、種類ごとの定修点検つきで点検の作業にする（画面の「計器を一括追加」と同じ。テンプレートのない計器は飛ばす）
def add_instrument_tasks!(maintenance, equipment, department, completed_on: nil)
  equipment.instruments.order(:tag_number).each do |instrument|
    template = MaintenanceTask.turnaround_template_for(instrument)
    next if template.nil?

    status = completed_on ? { status: "completed", completed_on: completed_on } : {}
    maintenance.maintenance_tasks.create!(equipment: equipment, instrument: instrument, department: department, kind: "inspection",
                                          checklist_template: template, **status)
  end
end

def assign!(maintenance, lead:, members:)
  MaintenanceAssignment.create!(scheduled_maintenance: maintenance, user: lead, role: "lead")
  members.each { |user| MaintenanceAssignment.create!(scheduled_maintenance: maintenance, user: user, role: "member") }
end

# --- 2022年（ボイラー＋発電設備・完了）---
round2022 = create_round!(series, equipments: [ boiler, generator ], title: "2022年 A号ボイラー整備", starts_on: Date.new(2022, 10, 11), ends_on: Date.new(2022, 10, 28),
                                  completed: true, description: "ボイラーと発電設備の同時停止整備。発電設備は4年ごとのタービン開放点検の回。")
add_instrument_tasks!(round2022, boiler, instrument_section, completed_on: Date.new(2022, 10, 18))
add_instrument_tasks!(round2022, generator, instrument_section, completed_on: Date.new(2022, 10, 19))
round2022.maintenance_tasks.create!(equipment: generator, department: electric_section, kind: "overhaul", title: "蒸気タービン開放点検",
                                    status: "completed", completed_on: Date.new(2022, 10, 25))
round2022.maintenance_tasks.create!(equipment: generator, department: electric_section, kind: "inspection", title: "発電機 絶縁抵抗測定・巻線点検",
                                    status: "completed", completed_on: Date.new(2022, 10, 22))
assign!(round2022, lead: suzuki, members: [ fujita, yamamoto ])

# --- 2024年（ボイラーのみ・完了）---
round2024 = create_round!(series, equipments: [ boiler ], title: "2024年 A号ボイラー整備", starts_on: Date.new(2024, 10, 8), ends_on: Date.new(2024, 10, 25),
                                  completed: true, description: "ボイラーのみの回（発電設備は4年周期のため2026年）。")
add_instrument_tasks!(round2024, boiler, instrument_section, completed_on: Date.new(2024, 10, 16))
assign!(round2024, lead: suzuki, members: [ fujita, yamamoto ])

# --- 2026年（ボイラー＋発電設備・計画中）---
round2026 = create_round!(series, equipments: [ boiler, generator ], title: "2026年 A号ボイラー整備", starts_on: Date.new(2026, 11, 9), ends_on: Date.new(2026, 11, 27),
                                  description: "ボイラーと発電設備の同時停止整備。発電設備は4年ごとのタービン開放点検の回。運転中に直せなかったトラブルもこの整備で対応する。")
add_instrument_tasks!(round2026, boiler, instrument_section)
add_instrument_tasks!(round2026, generator, instrument_section)
round2026.maintenance_tasks.create!(equipment: generator, department: electric_section, kind: "overhaul", title: "蒸気タービン開放点検")
round2026.maintenance_tasks.create!(equipment: generator, department: electric_section, kind: "inspection", title: "発電機 絶縁抵抗測定・巻線点検")
assign!(round2026, lead: suzuki, members: [ fujita, yamamoto ])

# 運転中は隔離できず直せなかったトラブルを、この回の整備の作業に回す（トラブルは定修待ちになる）
trouble = Trouble.find_by!(equipment: boiler, title: "FT-702 給水流量計据え付け不良")
round2026.maintenance_tasks.create!(equipment: boiler, instrument: trouble.instrument, department: instrument_section, kind: "overhaul",
                                    title: trouble.title, notes: trouble.description, trouble: trouble)
trouble.update!(status: "deferred")
