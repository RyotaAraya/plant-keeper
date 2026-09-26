# frozen_string_literal: true

# 朝会・夕会ボード（要求仕様書 2.8）の場面が伝わるデモ用データ。
# シード（db/seeds/22_meeting_board.rb）と、既存環境への反映マイグレーション（SeedMeetingBoardDemo）で共有する。
# 日付は「今日から何日か」で持つ（入れた日を今日として、実施中の定期整備と、今日・明日が期限の点検計画ができる）
module MeetingBoardCatalog
  # 実施中の定期整備: 川崎のFCCを短期間止めて（SDW）、計器を点検する。作業は部署ごとに、完了・実施中・未着手が混ざる
  MAINTENANCE = {
    site: "川崎製油所", equipment: "流動接触分解装置", title: "FCC 計器点検（SDW）",
    description: "流動接触分解装置を短期間停止し、伝送器・調節弁の定修点検と計装電源盤の点検を行う。",
    start_days: -2, end_days: 3
  }.freeze

  # 作業: 計器のタグ番号（点検）か内容、種類、状態、部署（拠点内の名前。nil は未定）、担当者のメール、完了日（今日から何日）、備考。
  # 点検の作業は、計器の種類に合う定修点検のチェックリスト（MaintenanceTask.turnaround_template_for と同じ）を付ける（内容は「タグ番号 チェックリスト名」）
  TASKS = [
    { tag: "FT-601", template: "伝送器 定修点検", kind: "inspection", status: "completed", department: "計器Aチーム", assigned: "sato@example.com", completed_days: -1 },
    { tag: "LT-601", template: "伝送器 定修点検", kind: "inspection", status: "in_progress", department: "計器Aチーム", assigned: "takahashi@example.com",
      notes: "導圧管のブローを実施中。午後にゼロ点を確認する" },
    { tag: "PT-601", template: "伝送器 定修点検", kind: "inspection", status: "not_started", department: "計器Aチーム", assigned: "honda@example.com" },
    { tag: "TV-601", template: "伝送器 定修点検", kind: "inspection", status: "completed", department: "計器Bチーム", assigned: "fujita@example.com", completed_days: -1 },
    { tag: "PV-601", template: "調節弁 定修点検", kind: "inspection", status: "in_progress", department: "計器Bチーム", assigned: "nishimura@example.com",
      notes: "グランドパッキンを交換。ストロークテストは明日" },
    { tag: "TV-602", template: "伝送器 定修点検", kind: "inspection", status: "not_started", department: "計器Bチーム", assigned: "fujita@example.com" },
    { title: "FCC 計装電源盤の点検（絶縁抵抗測定）", kind: "work", status: "not_started", department: "電気チーム",
      assigned: "watanabe@example.com" },
    { title: "FCC 計器まわりの保温材の復旧", kind: "work", status: "not_started", department: nil, assigned: nil,
      notes: "担当部署を朝会で決める" }
  ].freeze

  # 今日・明日が期限の点検計画（伝送器の月次点検）。last_days_ago: 前回の実施が今日から何日前か（周期30日で、30なら今日が期限）
  PLANS = [
    { site: "川崎製油所", tag: "PT-801", name: "PT-801 圧力伝送器 月次点検", template: "伝送器 月次点検", interval_days: 30, last_days_ago: 30 },
    { site: "川崎製油所", tag: "LT-901", name: "LT-901 液面伝送器 月次点検", template: "伝送器 月次点検", interval_days: 30, last_days_ago: 29 },
    { site: "川崎製油所", tag: "FT-802", name: "FT-802 流量伝送器 月次点検", template: "伝送器 月次点検", interval_days: 30, last_days_ago: 29 }
  ].freeze
end
