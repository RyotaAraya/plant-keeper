# frozen_string_literal: true

puts "ユーザを作成中..."

owner = Company.find_by!(company_type: "owner")
techno = Company.find_by!(name: "テクノサービス")
plant_maint = Company.find_by!(name: "プラントメンテナンス")
kansai = Company.find_by!(name: "関西プラントサービス")
tohoku = Company.find_by!(name: "東北計装サービス")

# 部署検索ヘルパー
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

user_data = [
  # === 川崎製油所 ===
  # 保全部
  { email: "admin@example.com",      name: "田中 太郎",   employment_type: "employee", system_role: "admin",       position: "general_manager", dept: ["川崎製油所", "保全部"], join_year: 2000, pref: "神奈川県" },
  # 計器保全課
  { email: "suzuki@example.com",     name: "鈴木 一郎",   employment_type: "employee", system_role: "supervisor",  position: "section_manager", dept: ["川崎製油所", "保全部", "計器保全課"], join_year: 2005, pref: "東京都" },
  { email: "sato@example.com",       name: "佐藤 健太",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["川崎製油所", "保全部", "計器保全課", "計器Aチーム"], join_year: 2012, pref: "千葉県" },
  { email: "takahashi@example.com",  name: "高橋 美咲",   employment_type: "employee", system_role: "member",      position: "senior_staff",    dept: ["川崎製油所", "保全部", "計器保全課", "計器Aチーム"], join_year: 2015, pref: "埼玉県" },
  { email: "inoue@example.com",      name: "井上 真司",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["川崎製油所", "保全部", "計器保全課", "計器Aチーム"], join_year: 2020, pref: "東京都" },
  { email: "endo@example.com",       name: "遠藤 大地",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["川崎製油所", "保全部", "計器保全課", "計器Aチーム"], join_year: 2022, pref: "神奈川県" },
  { email: "fujita@example.com",     name: "藤田 翔太",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["川崎製油所", "保全部", "計器保全課", "計器Bチーム"], join_year: 2013, pref: "静岡県" },
  { email: "nishimura@example.com",  name: "西村 拓也",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["川崎製油所", "保全部", "計器保全課", "計器Bチーム"], join_year: 2019, pref: "千葉県" },
  { email: "okada@example.com",      name: "岡田 雅人",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["川崎製油所", "保全部", "計器保全課", "計器Bチーム"], join_year: 2021, pref: "埼玉県" },
  { email: "yoshida@example.com",    name: "吉田 浩二",   employment_type: "contractor", system_role: "supervisor", position: "staff",           dept: ["川崎製油所", "保全部", "計器保全課", "計器Aチーム"], join_year: 2020, pref: "神奈川県", company: techno },
  { email: "yamada@example.com",     name: "山田 修",     employment_type: "contractor", system_role: "worker",     position: "staff",           dept: ["川崎製油所", "保全部", "計器保全課", "計器Bチーム"], join_year: 2021, pref: "東京都", company: plant_maint },
  { email: "honda@example.com",      name: "本田 慎一",   employment_type: "contractor", system_role: "worker",     position: "staff",           dept: ["川崎製油所", "保全部", "計器保全課", "計器Aチーム"], join_year: 2023, pref: "神奈川県", company: techno },
  # 電気保全課
  { email: "yamamoto@example.com",   name: "山本 大輔",   employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["川崎製油所", "保全部", "電気保全課"], join_year: 2006, pref: "神奈川県" },
  { email: "watanabe@example.com",   name: "渡辺 直人",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["川崎製油所", "保全部", "電気保全課", "電気チーム"], join_year: 2014, pref: "東京都" },
  { email: "hasegawa@example.com",   name: "長谷川 誠",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["川崎製油所", "保全部", "電気保全課", "電気チーム"], join_year: 2018, pref: "埼玉県" },
  { email: "aoki@example.com",       name: "青木 真理",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["川崎製油所", "保全部", "電気保全課", "電気チーム"], join_year: 2022, pref: "千葉県" },
  # 検査課
  { email: "nakamura@example.com",   name: "中村 雄一",   employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["川崎製油所", "保全部", "検査課"], join_year: 2008, pref: "静岡県" },
  { email: "maeda@example.com",      name: "前田 裕也",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["川崎製油所", "保全部", "検査課", "検査チーム"], join_year: 2014, pref: "神奈川県" },
  { email: "ishida@example.com",     name: "石田 康平",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["川崎製油所", "保全部", "検査課", "検査チーム"], join_year: 2020, pref: "東京都" },
  # 製造部
  { email: "morimoto@example.com",   name: "森本 隆司",   employment_type: "employee", system_role: "supervisor",  position: "general_manager", dept: ["川崎製油所", "製造部"], join_year: 2002, pref: "神奈川県" },
  { email: "kato@example.com",       name: "加藤 誠",     employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["川崎製油所", "製造部", "第1運転課"], join_year: 2009, pref: "東京都" },
  { email: "shimizu@example.com",    name: "清水 裕太",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["川崎製油所", "製造部", "第1運転課", "直A"], join_year: 2015, pref: "神奈川県" },
  { email: "ogawa_k@example.com",    name: "小川 健一",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["川崎製油所", "製造部", "第1運転課", "直A"], join_year: 2019, pref: "千葉県" },
  { email: "matsuda@example.com",    name: "松田 和也",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["川崎製油所", "製造部", "第1運転課", "直B"], join_year: 2020, pref: "東京都" },
  { email: "ueda@example.com",       name: "上田 敦",     employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["川崎製油所", "製造部", "第2運転課"], join_year: 2010, pref: "埼玉県" },
  { email: "nomura@example.com",     name: "野村 洋介",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["川崎製油所", "製造部", "第2運転課", "直A"], join_year: 2016, pref: "神奈川県" },
  { email: "fukuda@example.com",     name: "福田 光太",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["川崎製油所", "製造部", "第2運転課", "直A"], join_year: 2021, pref: "千葉県" },
  { email: "nagai@example.com",      name: "永井 恵子",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["川崎製油所", "製造部", "第2運転課", "直B"], join_year: 2022, pref: "東京都" },
  # 安全環境部
  { email: "kobayashi@example.com",  name: "小林 陽子",   employment_type: "employee", system_role: "member",      position: "general_manager", dept: ["川崎製油所", "安全環境部"], join_year: 2003, pref: "神奈川県" },
  { email: "murakami@example.com",   name: "村上 浩",     employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["川崎製油所", "安全環境部", "環境管理課"], join_year: 2011, pref: "東京都" },
  { email: "saito_k@example.com",    name: "斎藤 健",     employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["川崎製油所", "安全環境部", "安全課"], join_year: 2010, pref: "千葉県" },

  # === 根岸製油所 ===
  { email: "hashimoto@example.com",  name: "橋本 拓哉",   employment_type: "employee", system_role: "admin",       position: "general_manager", dept: ["根岸製油所", "保全部"], join_year: 2001, pref: "神奈川県" },
  { email: "yamashita@example.com",  name: "山下 聡",     employment_type: "employee", system_role: "supervisor",  position: "section_manager", dept: ["根岸製油所", "保全部", "計器保全課"], join_year: 2007, pref: "東京都" },
  { email: "imai@example.com",       name: "今井 大介",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["根岸製油所", "保全部", "計器保全課", "計器チーム"], join_year: 2014, pref: "神奈川県" },
  { email: "ogata@example.com",      name: "緒方 慎太郎", employment_type: "employee", system_role: "member",      position: "staff",           dept: ["根岸製油所", "保全部", "計器保全課", "計器チーム"], join_year: 2019, pref: "千葉県" },
  { email: "kaneko@example.com",     name: "金子 亮",     employment_type: "employee", system_role: "member",      position: "staff",           dept: ["根岸製油所", "保全部", "計器保全課", "計器チーム"], join_year: 2021, pref: "埼玉県" },
  { email: "ota@example.com",        name: "太田 智子",   employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["根岸製油所", "保全部", "電気保全課"], join_year: 2009, pref: "神奈川県" },
  { email: "goto@example.com",       name: "後藤 幸一",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["根岸製油所", "保全部", "電気保全課", "電気チーム"], join_year: 2015, pref: "東京都" },
  { email: "miura@example.com",      name: "三浦 翔",     employment_type: "employee", system_role: "member",      position: "staff",           dept: ["根岸製油所", "保全部", "電気保全課", "電気チーム"], join_year: 2020, pref: "千葉県" },
  { email: "kuroda@example.com",     name: "黒田 将人",   employment_type: "employee", system_role: "supervisor",  position: "general_manager", dept: ["根岸製油所", "製造部"], join_year: 2004, pref: "神奈川県" },
  { email: "noguchi@example.com",    name: "野口 裕介",   employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["根岸製油所", "製造部", "運転課"], join_year: 2011, pref: "東京都" },
  { email: "harada@example.com",     name: "原田 美紀",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["根岸製油所", "製造部", "運転課", "直A"], join_year: 2016, pref: "神奈川県" },
  { email: "kawano@example.com",     name: "川野 達也",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["根岸製油所", "製造部", "運転課", "直A"], join_year: 2021, pref: "千葉県" },
  { email: "takeda@example.com",     name: "武田 誠一",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["根岸製油所", "製造部", "運転課", "直B"], join_year: 2022, pref: "埼玉県" },
  { email: "hirata@example.com",     name: "平田 恵",     employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["根岸製油所", "安全環境部", "環境安全課"], join_year: 2012, pref: "神奈川県" },

  # === 堺製油所 ===
  { email: "ito@example.com",        name: "伊藤 和也",   employment_type: "employee", system_role: "admin",       position: "general_manager", dept: ["堺製油所", "保全部"], join_year: 2002, pref: "大阪府" },
  { email: "kimura@example.com",     name: "木村 拓哉",   employment_type: "employee", system_role: "supervisor",  position: "section_manager", dept: ["堺製油所", "保全部", "計器保全課"], join_year: 2008, pref: "兵庫県" },
  { email: "tanabe@example.com",     name: "田辺 雄太",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["堺製油所", "保全部", "計器保全課", "計器Aチーム"], join_year: 2014, pref: "大阪府" },
  { email: "nishida@example.com",    name: "西田 真一",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["堺製油所", "保全部", "計器保全課", "計器Aチーム"], join_year: 2019, pref: "京都府" },
  { email: "kawaguchi@example.com",  name: "川口 啓介",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["堺製油所", "保全部", "計器保全課", "計器Aチーム"], join_year: 2022, pref: "兵庫県" },
  { email: "hayashi@example.com",    name: "林 真理子",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["堺製油所", "保全部", "計器保全課", "計器Bチーム"], join_year: 2015, pref: "大阪府" },
  { email: "fujimoto@example.com",   name: "藤本 健二",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["堺製油所", "保全部", "計器保全課", "計器Bチーム"], join_year: 2020, pref: "奈良県" },
  { email: "otsuka@example.com",     name: "大塚 恵美",   employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["堺製油所", "保全部", "電気保全課"], join_year: 2009, pref: "大阪府" },
  { email: "sugiyama@example.com",   name: "杉山 浩二",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["堺製油所", "保全部", "電気保全課", "電気チーム"], join_year: 2016, pref: "兵庫県" },
  { email: "moriyama@example.com",   name: "森山 裕一",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["堺製油所", "保全部", "電気保全課", "電気チーム"], join_year: 2021, pref: "大阪府" },
  { email: "iwamoto@example.com",    name: "岩本 亮介",   employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["堺製油所", "保全部", "検査課"], join_year: 2010, pref: "大阪府" },
  { email: "wada@example.com",       name: "和田 美穂",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["堺製油所", "保全部", "検査課", "検査チーム"], join_year: 2017, pref: "兵庫県" },
  { email: "nakata@example.com",     name: "中田 慎吾",   employment_type: "employee", system_role: "supervisor",  position: "general_manager", dept: ["堺製油所", "製造部"], join_year: 2003, pref: "大阪府" },
  { email: "ogawa@example.com",      name: "小川 美穂",   employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["堺製油所", "製造部", "第1運転課"], join_year: 2011, pref: "大阪府" },
  { email: "kitamura@example.com",   name: "北村 剛志",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["堺製油所", "製造部", "第1運転課", "直A"], join_year: 2017, pref: "兵庫県" },
  { email: "murata@example.com",     name: "村田 裕子",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["堺製油所", "製造部", "第1運転課", "直A"], join_year: 2021, pref: "大阪府" },
  { email: "arai@example.com",       name: "荒井 康太",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["堺製油所", "製造部", "第1運転課", "直B"], join_year: 2023, pref: "京都府" },
  { email: "kubo@example.com",       name: "久保 正人",   employment_type: "contractor", system_role: "worker",     position: "staff",           dept: ["堺製油所", "保全部", "計器保全課", "計器Aチーム"], join_year: 2021, pref: "大阪府", company: kansai },

  # === 和歌山製油所 ===
  { email: "abe@example.com",        name: "阿部 俊介",   employment_type: "employee", system_role: "admin",       position: "general_manager", dept: ["和歌山製油所", "保全部"], join_year: 2003, pref: "和歌山県" },
  { email: "kawamoto@example.com",   name: "川本 浩一",   employment_type: "employee", system_role: "supervisor",  position: "section_manager", dept: ["和歌山製油所", "保全部", "計器保全課"], join_year: 2009, pref: "和歌山県" },
  { email: "doi@example.com",        name: "土井 拓真",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["和歌山製油所", "保全部", "計器保全課", "計器チーム"], join_year: 2015, pref: "大阪府" },
  { email: "hara@example.com",       name: "原 雅之",     employment_type: "employee", system_role: "member",      position: "staff",           dept: ["和歌山製油所", "保全部", "計器保全課", "計器チーム"], join_year: 2020, pref: "和歌山県" },
  { email: "taguchi@example.com",    name: "田口 和美",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["和歌山製油所", "保全部", "計器保全課", "計器チーム"], join_year: 2023, pref: "奈良県" },
  { email: "morita_w@example.com",   name: "森田 達也",   employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["和歌山製油所", "保全部", "電気保全課"], join_year: 2010, pref: "和歌山県" },
  { email: "komori@example.com",     name: "小森 秀樹",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["和歌山製油所", "保全部", "電気保全課", "電気チーム"], join_year: 2016, pref: "大阪府" },
  { email: "hirose@example.com",     name: "広瀬 義男",   employment_type: "employee", system_role: "supervisor",  position: "general_manager", dept: ["和歌山製油所", "製造部"], join_year: 2004, pref: "和歌山県" },
  { email: "sakai@example.com",      name: "酒井 勝",     employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["和歌山製油所", "製造部", "運転課"], join_year: 2012, pref: "和歌山県" },
  { email: "kurata@example.com",     name: "倉田 隆志",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["和歌山製油所", "製造部", "運転課", "直A"], join_year: 2017, pref: "大阪府" },
  { email: "matsubara@example.com",  name: "松原 薫",     employment_type: "employee", system_role: "member",      position: "staff",           dept: ["和歌山製油所", "製造部", "運転課", "直A"], join_year: 2022, pref: "和歌山県" },
  { email: "yasuda@example.com",     name: "安田 光一",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["和歌山製油所", "製造部", "運転課", "直B"], join_year: 2023, pref: "兵庫県" },

  # === 仙台製油所 ===
  { email: "sasaki@example.com",     name: "佐々木 隆",   employment_type: "employee", system_role: "admin",       position: "general_manager", dept: ["仙台製油所", "保全部"], join_year: 2004, pref: "宮城県" },
  { email: "matsumoto@example.com",  name: "松本 剛",     employment_type: "employee", system_role: "supervisor",  position: "section_manager", dept: ["仙台製油所", "保全部", "計器保全課"], join_year: 2010, pref: "岩手県" },
  { email: "chiba_t@example.com",    name: "千葉 拓斗",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["仙台製油所", "保全部", "計器保全課", "計器チーム"], join_year: 2015, pref: "宮城県" },
  { email: "oikawa@example.com",     name: "及川 大輝",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["仙台製油所", "保全部", "計器保全課", "計器チーム"], join_year: 2020, pref: "秋田県" },
  { email: "sugawara@example.com",   name: "菅原 涼太",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["仙台製油所", "保全部", "計器保全課", "計器チーム"], join_year: 2023, pref: "宮城県" },
  { email: "takagi@example.com",     name: "高木 勇人",   employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["仙台製油所", "保全部", "電気保全課"], join_year: 2011, pref: "福島県" },
  { email: "kumagai@example.com",    name: "熊谷 正樹",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["仙台製油所", "保全部", "電気保全課", "電気チーム"], join_year: 2016, pref: "宮城県" },
  { email: "shibata@example.com",    name: "柴田 恵子",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["仙台製油所", "保全部", "電気保全課", "電気チーム"], join_year: 2021, pref: "山形県" },
  { email: "endo_sd@example.com",    name: "遠藤 孝明",   employment_type: "employee", system_role: "supervisor",  position: "general_manager", dept: ["仙台製油所", "製造部"], join_year: 2005, pref: "宮城県" },
  { email: "konno@example.com",      name: "今野 真吾",   employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["仙台製油所", "製造部", "運転課"], join_year: 2012, pref: "宮城県" },
  { email: "abe_sd@example.com",     name: "阿部 慶太",   employment_type: "employee", system_role: "member",      position: "team_leader",     dept: ["仙台製油所", "製造部", "運転課", "直A"], join_year: 2018, pref: "岩手県" },
  { email: "sato_sd@example.com",    name: "佐藤 彩花",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["仙台製油所", "製造部", "運転課", "直A"], join_year: 2022, pref: "宮城県" },
  { email: "mikami@example.com",     name: "三上 賢治",   employment_type: "contractor", system_role: "worker",     position: "staff",           dept: ["仙台製油所", "保全部", "計器保全課", "計器チーム"], join_year: 2022, pref: "宮城県", company: tohoku },

  # === 千葉（閉鎖）→ 退職者 ===
  { email: "morita@example.com",     name: "森田 正義",   employment_type: "employee", system_role: "member",      position: "section_manager", dept: ["千葉製油所", "保全部", "計器保全課"], join_year: 2006, pref: "千葉県", inactive: true },
  { email: "oishi@example.com",      name: "大石 裕次",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["千葉製油所", "保全部", "計器保全課"], join_year: 2015, pref: "千葉県", inactive: true },
  { email: "suzuki_c@example.com",   name: "鈴木 将大",   employment_type: "employee", system_role: "member",      position: "staff",           dept: ["千葉製油所", "製造部", "運転課"], join_year: 2016, pref: "千葉県", inactive: true }
]

user_data.each do |data|
  User.create!(
    email: data[:email],
    password: "password",
    password_confirmation: "password",
    name: data[:name],
    employment_type: data[:employment_type],
    system_role: data[:system_role],
    company: data[:company] || owner,
    position: data[:position],
    department: dept(*data[:dept]),
    join_year: data[:join_year],
    home_prefecture: data[:pref],
    is_active: data[:inactive] ? false : true,
    deactivated_on: data[:inactive] ? Date.new(2024, 3, 31) : nil
  )
end
