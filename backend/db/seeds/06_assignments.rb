# frozen_string_literal: true

puts "設備担当を作成中..."

# ヘルパー
def user_by(email) = User.find_by!(email: email)
def equip(site_name, equip_name) = Equipment.find_by!(site: Site.find_by!(name: site_name), name: equip_name)

[
  # 川崎
  { user: "suzuki@example.com",    equip: ["川崎製油所", "常圧蒸留装置"],   role: "主担当", started: "2020-04-01" },
  { user: "sato@example.com",      equip: ["川崎製油所", "常圧蒸留装置"],   role: "副担当", started: "2021-04-01" },
  { user: "suzuki@example.com",    equip: ["川崎製油所", "重油間接脱硫装置"], role: "主担当", started: "2020-04-01" },
  { user: "takahashi@example.com", equip: ["川崎製油所", "流動接触分解装置"], role: "主担当", started: "2022-04-01" },
  { user: "sato@example.com",      equip: ["川崎製油所", "流動接触分解装置"], role: "副担当", started: "2022-04-01" },
  { user: "fujita@example.com",    equip: ["川崎製油所", "ボイラー設備"],   role: "主担当", started: "2023-04-01" },
  { user: "yamamoto@example.com",  equip: ["川崎製油所", "ボイラー設備"],   role: "副担当", started: "2020-04-01" },
  { user: "inoue@example.com",     equip: ["川崎製油所", "接触改質装置"],   role: "主担当", started: "2023-04-01" },
  { user: "nishimura@example.com", equip: ["川崎製油所", "減圧蒸留装置"],   role: "主担当", started: "2022-04-01" },
  { user: "okada@example.com",     equip: ["川崎製油所", "タンク設備"],     role: "主担当", started: "2023-04-01" },
  { user: "sato@example.com",      equip: ["川崎製油所", "ボイラー設備"],   role: "副担当", started: "2019-04-01", ended: "2021-03-31" },
  # 根岸
  { user: "yamashita@example.com", equip: ["根岸製油所", "常圧蒸留装置"],   role: "主担当", started: "2019-04-01" },
  { user: "imai@example.com",      equip: ["根岸製油所", "常圧蒸留装置"],   role: "副担当", started: "2020-04-01" },
  { user: "ogata@example.com",     equip: ["根岸製油所", "軽油脱硫装置"],   role: "主担当", started: "2021-04-01" },
  { user: "kaneko@example.com",    equip: ["根岸製油所", "ボイラー設備"],   role: "主担当", started: "2023-04-01" },
  { user: "goto@example.com",      equip: ["根岸製油所", "タンク設備"],     role: "主担当", started: "2020-04-01" },
  # 堺
  { user: "kimura@example.com",    equip: ["堺製油所", "常圧蒸留装置"],     role: "主担当", started: "2019-04-01" },
  { user: "tanabe@example.com",    equip: ["堺製油所", "軽油脱硫装置"],     role: "主担当", started: "2021-04-01" },
  { user: "hayashi@example.com",   equip: ["堺製油所", "接触改質装置"],     role: "主担当", started: "2021-04-01" },
  { user: "nishida@example.com",   equip: ["堺製油所", "ボイラー設備"],     role: "主担当", started: "2022-04-01" },
  { user: "kawaguchi@example.com", equip: ["堺製油所", "タンク設備"],       role: "主担当", started: "2023-04-01" },
  # 和歌山
  { user: "doi@example.com",       equip: ["和歌山製油所", "常圧蒸留装置"], role: "主担当", started: "2020-04-01" },
  { user: "hara@example.com",      equip: ["和歌山製油所", "流動接触分解装置"], role: "主担当", started: "2022-04-01" },
  { user: "taguchi@example.com",   equip: ["和歌山製油所", "ボイラー設備"], role: "主担当", started: "2023-04-01" },
  # 仙台
  { user: "sasaki@example.com",    equip: ["仙台製油所", "潤滑油製造装置"], role: "主担当", started: "2020-04-01" },
  { user: "matsumoto@example.com", equip: ["仙台製油所", "軽油脱硫装置"],   role: "主担当", started: "2021-04-01" },
  { user: "chiba_t@example.com",   equip: ["仙台製油所", "ボイラー設備"],   role: "主担当", started: "2021-04-01" },
  { user: "oikawa@example.com",    equip: ["仙台製油所", "タンク設備"],     role: "主担当", started: "2022-04-01" }
].each do |data|
  EquipmentAssignment.create!(
    user: user_by(data[:user]),
    equipment: equip(*data[:equip]),
    role: data[:role],
    started_on: Date.parse(data[:started]),
    ended_on: data[:ended] ? Date.parse(data[:ended]) : nil
  )
end

puts "部署異動履歴を作成中..."

def dept(site_name, *names)
  site = Site.find_by!(name: site_name)
  parent = nil
  result = nil
  names.each do |name|
    result = Department.find_by!(name: name, site: site, parent: parent)
    parent = result
  end
  result
end

[
  { user: "sato@example.com",      dept: ["川崎製油所", "製造部", "第1運転課", "直A"], started: "2012-04-01", ended: "2015-03-31", note: "入社後3年間運転課で現場経験" },
  { user: "sato@example.com",      dept: ["川崎製油所", "保全部", "計器保全課", "計器Aチーム"], started: "2015-04-01", note: "計器保全課Aチームへ異動。チームリーダ" },
  { user: "suzuki@example.com",    dept: ["川崎製油所", "保全部", "計器保全課"], started: "2005-04-01", note: "入社から計器保全課。課長" },
  { user: "admin@example.com",     dept: ["川崎製油所", "保全部"], started: "2000-04-01", note: "管理者。保全部長" },
  { user: "morita@example.com",    dept: ["千葉製油所", "保全部", "計器保全課"], started: "2006-04-01", ended: "2024-03-31", note: "千葉工場閉鎖に伴い退職" },
  { user: "yamamoto@example.com",  dept: ["川崎製油所", "保全部", "電気保全課"], started: "2006-04-01", note: "電気保全課長" },
  { user: "takahashi@example.com", dept: ["川崎製油所", "保全部", "計器保全課", "計器Aチーム"], started: "2015-04-01", note: "計器保全課Aチーム。主任" },
  { user: "fujita@example.com",    dept: ["川崎製油所", "保全部", "計器保全課", "計器Bチーム"], started: "2013-04-01", note: "計器保全課Bチーム。チームリーダ" },
  { user: "kimura@example.com",    dept: ["堺製油所", "保全部", "計器保全課"], started: "2008-04-01", note: "堺計器保全課長" },
  { user: "ito@example.com",       dept: ["堺製油所", "保全部"], started: "2002-04-01", note: "堺保全部長" },
  { user: "sasaki@example.com",    dept: ["仙台製油所", "保全部"], started: "2004-04-01", note: "仙台保全部長" }
].each do |data|
  DepartmentHistory.create!(
    user: user_by(data[:user]),
    department: dept(*data[:dept]),
    started_on: Date.parse(data[:started]),
    ended_on: data[:ended] ? Date.parse(data[:ended]) : nil,
    role_note: data[:note]
  )
end
