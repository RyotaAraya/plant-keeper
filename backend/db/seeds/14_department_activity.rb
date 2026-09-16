# frozen_string_literal: true

# 09_inspections.rb は各拠点の「計器保全課」中心のデータしかなく、
# 電気保全課・検査課・運転課・安全環境部など他の部署では点検・トラブル・
# 整備が0件だった。部署フィルタ（点検・トラブル管理）で選んでも
# 何も表示されない部署が大半だったため、代表的な活動データを補強する。
# 対象は稼働中の拠点のみ（千葉製油所は閉鎖済のため対象外）。

puts "部署ごとの活動データ（点検・トラブル・整備）を補強中..."

def find_dept(site_name, path)
  site = Site.find_by!(name: site_name)
  dept = nil
  path.each { |name| dept = Department.find_by!(name: name, site: site, parent: dept) }
  dept
end

item_sets = {
  maintenance_elec: [
    { content: "モーター回転方向を確認", type: "check" },
    { content: "絶縁抵抗値（MΩ）", type: "measurement" },
    { content: "ベアリング温度（℃）", type: "measurement" },
    { content: "異常振動・異音の有無を確認", type: "check" }
  ],
  maintenance_inspect: [
    { content: "配管外観検査（腐食・損傷）", type: "check" },
    { content: "肉厚測定値（mm）", type: "measurement" },
    { content: "保温材の状態確認", type: "check" }
  ],
  operation: [
    { content: "運転圧力指示値確認", type: "check" },
    { content: "運転温度指示値確認（℃）", type: "measurement" },
    { content: "異音・異臭の有無を確認", type: "check" },
    { content: "バルブ開度確認", type: "check" }
  ],
  environment: [
    { content: "保護具着用状況確認", type: "check" },
    { content: "緊急停止装置動作確認", type: "check" },
    { content: "廃液・廃棄物処理状況確認", type: "check" }
  ]
}

trouble_titles = {
  maintenance_elec: [ "モーター異音", "絶縁抵抗値低下", "端子部発熱" ],
  maintenance_inspect: [ "配管肉厚減肉", "保温材劣化・破損", "外面腐食を確認" ],
  operation: [ "運転温度上昇", "圧力変動が大きい", "異音発生" ],
  environment: [ "廃液処理設備の警報発報", "保護具の不足を確認", "排水基準値超過の疑い" ]
}

target_sections = [
  { site: "川崎製油所", path: %w[保全部 検査課], kind: :maintenance_inspect },
  { site: "根岸製油所", path: %w[保全部 電気保全課], kind: :maintenance_elec },
  { site: "堺製油所", path: %w[保全部 電気保全課], kind: :maintenance_elec },
  { site: "堺製油所", path: %w[保全部 検査課], kind: :maintenance_inspect },
  { site: "和歌山製油所", path: %w[保全部 電気保全課], kind: :maintenance_elec },
  { site: "仙台製油所", path: %w[保全部 電気保全課], kind: :maintenance_elec },
  { site: "川崎製油所", path: %w[製造部 第1運転課], kind: :operation },
  { site: "川崎製油所", path: %w[製造部 第2運転課], kind: :operation },
  { site: "根岸製油所", path: %w[製造部 運転課], kind: :operation },
  { site: "堺製油所", path: %w[製造部 第1運転課], kind: :operation },
  { site: "和歌山製油所", path: %w[製造部 運転課], kind: :operation },
  { site: "仙台製油所", path: %w[製造部 運転課], kind: :operation },
  { site: "川崎製油所", path: %w[安全環境部 環境管理課], kind: :environment },
  { site: "川崎製油所", path: %w[安全環境部 安全課], kind: :environment },
  { site: "根岸製油所", path: %w[安全環境部 環境安全課], kind: :environment },
  { site: "堺製油所", path: %w[安全環境部 環境管理課], kind: :environment }
]

inspection_statuses = %w[approved approved submitted approval_requested]

target_sections.each_with_index do |t, idx|
  dept = find_dept(t[:site], t[:path])
  site = dept.site
  user = dept.users.first || User.find_by(site_id: site.id, is_active: true)
  equipments = site.equipments.to_a
  next if user.nil? || equipments.empty?

  items = item_sets[t[:kind]]
  inspection_type = t[:kind] == :operation ? "operation_check" : "routine"

  # 点検3件（それぞれ複数項目）
  3.times do |i|
    eq = equipments[i % equipments.length]
    insp = Inspection.create!(
      user: user, equipment: eq, department: dept,
      inspection_type: inspection_type,
      status: inspection_statuses[i % inspection_statuses.length],
      inspected_at: (idx + i * 2 + 1).days.ago,
      notes: "#{dept.full_path}による定期チェック。異常なし。"
    )
    items.each_with_index do |it, pos|
      InspectionItem.create!(
        inspection: insp,
        position: pos + 1,
        content: it[:content],
        item_type: it[:type],
        checked: it[:type] == "check",
        measured_value: it[:type] == "measurement" ? (10 + idx * 0.7 + pos * 1.3).round(1).to_s : nil,
        has_defect: false
      )
    end
  end

  # トラブル2件
  titles = trouble_titles[t[:kind]]
  2.times do |i|
    eq = equipments[i % equipments.length]
    title = titles[i % titles.length]
    Trouble.create!(
      equipment: eq,
      reported_by: user,
      assigned_to: i.even? ? user : nil,
      title: "#{eq.name} #{title}",
      description: "#{dept.full_path}が確認。#{title}の兆候あり。",
      status: i.even? ? "in_progress" : "open",
      priority: %w[low medium high][(idx + i) % 3],
      reported_at: (idx + i * 3 + 2).days.ago
    )
  end

  # 整備系部署のみ、定期整備を2件追加
  next unless t[:kind].to_s.start_with?("maintenance")

  2.times do |i|
    eq = equipments[i % equipments.length]
    sm = ScheduledMaintenance.create!(
      equipment: eq,
      title: "#{eq.name} #{t[:kind] == :maintenance_elec ? '電気設備' : '配管'}定期整備",
      description: "#{dept.full_path}による定期整備。",
      scheduled_date: (10 + idx + i * 20).days.from_now,
      status: "planned"
    )
    MaintenanceAssignment.create!(scheduled_maintenance: sm, user: user, role: "lead")
  end
end
