# frozen_string_literal: true

puts "朝会・夕会ボードのデモ（実施中の定期整備・今日と明日が期限の点検計画・今日の点検と対応記録）を作成中..."

# 定義は db/data/meeting_board.rb（既存環境へは SeedMeetingBoardDemo マイグレーションで反映する）
require Rails.root.join("db/data/meeting_board")

today = InspectionPlan.today
spec = MeetingBoardCatalog::MAINTENANCE
site = Site.find_by!(name: spec[:site])
equipment = Equipment.find_by!(site: site, name: spec[:equipment])
maintenance = ScheduledMaintenance.create!(
  site: site, equipments: [ equipment ], title: spec[:title], description: spec[:description], status: "in_progress",
  planned_start_on: today + spec[:start_days], planned_end_on: today + spec[:end_days], actual_start_on: today + spec[:start_days]
)
MeetingBoardCatalog::TASKS.each do |task|
  instrument = task[:tag] && equipment.instruments.find_by!(tag_number: task[:tag])
  maintenance.maintenance_tasks.create!(
    equipment: equipment, instrument: instrument, kind: task[:kind], status: task[:status], title: task[:title], notes: task[:notes],
    checklist_template: task[:template] && ChecklistTemplate.where(name: task[:template], is_active: true).order(:id).first!,
    department: task[:department] && Department.find_by!(site: site, name: task[:department]),
    assigned_to: task[:assigned] && User.find_by!(email: task[:assigned]),
    completed_on: task[:completed_days] && today + task[:completed_days]
  )
end

# 夕会の場面: 今日の点検（作業から実施）と、今日の対応記録
now = Time.current
MeetingBoardCatalog::INSPECTIONS.each do |spec|
  task = maintenance.maintenance_tasks.joins(:instrument).find_by!(instruments: { tag_number: spec[:task_tag] })
  Inspection.create!(
    user: User.find_by!(email: spec[:user]), department: Department.find_by!(site: site, name: spec[:department]),
    equipment: equipment, instrument: task.instrument, checklist_template: task.checklist_template, maintenance_task: task,
    inspection_type: "periodic", status: spec[:status], inspected_at: MeetingBoardCatalog.today_at(now, spec[:hours_ago]), notes: spec[:notes]
  )
end
MeetingBoardCatalog::RESPONSES.each do |spec|
  trouble = Trouble.joins(:equipment).find_by!(title: spec[:trouble], equipments: { site_id: Site.find_by!(name: spec[:site]).id })
  trouble.trouble_responses.create!(user: User.find_by!(email: spec[:user]), response_type: spec[:response_type], description: spec[:description],
                                    responded_at: MeetingBoardCatalog.today_at(now, spec[:hours_ago]))
end

MeetingBoardCatalog::PLANS.each do |plan|
  instrument = Instrument.joins(:equipment).find_by!(tag_number: plan[:tag], equipments: { site_id: Site.find_by!(name: plan[:site]).id })
  last = today - plan[:last_days_ago]
  InspectionPlan.create!(name: plan[:name], equipment: instrument.equipment, instrument: instrument,
                         checklist_template: ChecklistTemplate.where(name: plan[:template], is_active: true).order(:id).first!,
                         inspection_type: "periodic", interval_days: plan[:interval_days], last_inspected_on: last, next_due_on: last + plan[:interval_days])
end
