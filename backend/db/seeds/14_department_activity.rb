# frozen_string_literal: true

# 09_inspections.rb は各拠点の「計器保全課」（課レベル）中心のデータしかなく、
# それ以外の部署では点検・トラブル・整備が0件だった。
#
# さらに、点検・トラブル管理画面の部署フィルタは拠点内の全部署（部・課・チーム）を
# フラットに選択できる一方、点検記録の department は「課」レベルにしか
# 付与されていなかったため、チームに所属するユーザ（一般的な現場担当者の大半）
# が自分の所属部署で絞り込むと常に0件になっていた（例: 佐藤健太＝計器Aチーム所属だが
# 点検記録は「計器保全課」に紐付いていたため、本人のチームでは検索にヒットしない）。
#
# 対応として、末端（リーフ）部署 — チームが存在すればチーム、なければ課 — 単位で
# 点検・トラブル・整備データを生成する。対象は稼働中の拠点のみ
# （千葉製油所は閉鎖済のため対象外）。

puts "部署ごとの活動データ（点検・トラブル・整備）を補強中..."

item_sets = {
  instrument: [
    { content: "伝送器の指示値を確認", type: "check" },
    { content: "伝送器の指示値を記録（mA）", type: "measurement" },
    { content: "配管・継手からの漏れを確認", type: "check" },
    { content: "ケーブル・端子の損傷を確認", type: "check" }
  ],
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
  instrument: [ "伝送器指示値の異常", "ケーブル損傷を確認", "計器の応答遅れ" ],
  maintenance_elec: [ "モーター異音", "絶縁抵抗値低下", "端子部発熱" ],
  maintenance_inspect: [ "配管肉厚減肉", "保温材劣化・破損", "外面腐食を確認" ],
  operation: [ "運転温度上昇", "圧力変動が大きい", "異音発生" ],
  environment: [ "廃液処理設備の警報発報", "保護具の不足を確認", "排水基準値超過の疑い" ]
}

# 部署名から活動の種類を判定
def activity_kind_for(dept)
  case dept.full_path
  when /計器/ then :instrument
  when /電気/ then :maintenance_elec
  when /検査/ then :maintenance_inspect
  when /運転/ then :operation
  when /環境|安全/ then :environment
  end
end

inspection_statuses = %w[approved approved submitted approval_requested draft]

# 末端（リーフ）部署のみ対象（子部署があれば子側でカバーされるため対象外）
leaf_departments = Department.includes(:site, :children)
  .where.not(site: Site.find_by!(name: "千葉製油所"))
  .to_a
  .select { |d| d.children.empty? }
  .sort_by { |d| [ d.site_id, d.id ] }

leaf_departments.each_with_index do |dept, idx|
  kind = activity_kind_for(dept)
  next if kind.nil?

  site = dept.site
  user = dept.users.find_by(is_active: true) || User.find_by(site_id: site.id, is_active: true)
  equipments = site.equipments.to_a
  next if user.nil? || equipments.empty?

  items = item_sets[kind]
  inspection_type = kind == :operation ? "operation_check" : "routine"

  # 点検5件（それぞれ複数項目）
  5.times do |i|
    eq = equipments[i % equipments.length]
    insp = Inspection.create!(
      user: user, equipment: eq, department: dept,
      inspection_type: inspection_type,
      status: inspection_statuses[(idx + i) % inspection_statuses.length],
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
        measured_value: it[:type] == "measurement" ? (10 + idx * 0.6 + pos * 1.1).round(1).to_s : nil,
        has_defect: false
      )
    end
  end

  # トラブル2件
  titles = trouble_titles[kind]
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

  # 整備系部署（計器・電気・検査）のみ、定期整備を2件追加
  next unless %i[instrument maintenance_elec maintenance_inspect].include?(kind)

  maintenance_label = { instrument: "計器", maintenance_elec: "電気設備", maintenance_inspect: "配管" }[kind]
  2.times do |i|
    eq = equipments[i % equipments.length]
    sm = ScheduledMaintenance.create!(
      equipment: eq,
      title: "#{eq.name} #{maintenance_label}定期整備",
      description: "#{dept.full_path}による定期整備。",
      scheduled_date: (10 + idx + i * 20).days.from_now,
      status: "planned"
    )
    MaintenanceAssignment.create!(scheduled_maintenance: sm, user: user, role: "lead")
  end
end

# 「部」「課」レベルにも部長・課長（管理職）が直接所属しているケースがある
# （例: 検査課長は「検査課」自体に所属し、子の「検査チーム」には所属しない）。
# 管理職自身の所属部署で絞り込んでも0件にならないよう、子部署を持つ部署の
# うち専任ユーザがいるものには総括点検として少数のデータを補強する
# （安全環境部など管理職が配置されていない部署は対象外＝0件のまま）。
division_kind = { "maintenance" => :instrument, "operation" => :operation, "environment" => :environment }

non_leaf_departments = Department.includes(:site, :children)
  .where.not(site: Site.find_by!(name: "千葉製油所"))
  .to_a
  .select { |d| d.children.any? }
  .sort_by { |d| [ d.site_id, d.id ] }

non_leaf_departments.each_with_index do |dept, idx|
  user = dept.users.find_by(is_active: true)
  next if user.nil?

  kind = activity_kind_for(dept) || division_kind[dept.department_type]
  next if kind.nil?

  equipments = dept.site.equipments.to_a
  next if equipments.empty?

  items = item_sets[kind]
  inspection_type = kind == :operation ? "operation_check" : "routine"

  2.times do |i|
    eq = equipments[i % equipments.length]
    insp = Inspection.create!(
      user: user, equipment: eq, department: dept,
      inspection_type: inspection_type,
      status: %w[approved submitted][i % 2],
      inspected_at: (idx + i * 4 + 3).days.ago,
      notes: "#{dept.full_path}による総括点検。異常なし。"
    )
    items.each_with_index do |it, pos|
      InspectionItem.create!(
        inspection: insp,
        position: pos + 1,
        content: it[:content],
        item_type: it[:type],
        checked: it[:type] == "check",
        measured_value: it[:type] == "measurement" ? (12 + idx * 0.5 + pos).round(1).to_s : nil,
        has_defect: false
      )
    end
  end
end
