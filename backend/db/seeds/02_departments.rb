# frozen_string_literal: true

puts "部署を作成中..."

sites = {
  kawasaki: Site.find_by!(name: "川崎製油所"),
  negishi:  Site.find_by!(name: "根岸製油所"),
  sakai:    Site.find_by!(name: "堺製油所"),
  wakayama: Site.find_by!(name: "和歌山製油所"),
  sendai:   Site.find_by!(name: "仙台製油所"),
  chiba:    Site.find_by!(name: "千葉製油所")
}

# ヘルパー: 部→課→チームを一括作成（既存があれば再利用し、重複作成を防ぐ）
def create_dept_tree(site, divisions)
  divisions.each do |div|
    d = Department.find_or_create_by!(name: div[:name], site: site, parent: nil) do |dept|
      dept.department_type = div[:type]
      dept.level = "division"
    end
    (div[:sections] || []).each do |sec|
      s = Department.find_or_create_by!(name: sec[:name], site: site, parent: d) do |dept|
        dept.department_type = sec[:type] || div[:type]
        dept.level = "section"
      end
      (sec[:teams] || []).each do |tm|
        Department.find_or_create_by!(name: tm[:name], site: site, parent: s) do |dept|
          dept.department_type = tm[:type] || sec[:type] || div[:type]
          dept.level = "team"
        end
      end
    end
  end
end

# --- 川崎製油所 ---
create_dept_tree(sites[:kawasaki], [
  { name: "保全部", type: "maintenance", sections: [
    { name: "計器保全課", teams: [
      { name: "計器Aチーム" },
      { name: "計器Bチーム" }
    ] },
    { name: "電気保全課", teams: [
      { name: "電気チーム" }
    ] },
    { name: "検査課", teams: [
      { name: "検査チーム" }
    ] }
  ] },
  { name: "製造部", type: "operation", sections: [
    { name: "第1運転課", teams: [
      { name: "直A" },
      { name: "直B" }
    ] },
    { name: "第2運転課", teams: [
      { name: "直A" },
      { name: "直B" }
    ] }
  ] },
  { name: "安全環境部", type: "environment", sections: [
    { name: "環境管理課", teams: [
      { name: "環境チーム" }
    ] },
    { name: "安全課", teams: [
      { name: "安全チーム" }
    ] }
  ] }
])

# --- 根岸製油所 ---
create_dept_tree(sites[:negishi], [
  { name: "保全部", type: "maintenance", sections: [
    { name: "計器保全課", teams: [
      { name: "計器チーム" }
    ] },
    { name: "電気保全課", teams: [
      { name: "電気チーム" }
    ] }
  ] },
  { name: "製造部", type: "operation", sections: [
    { name: "運転課", teams: [
      { name: "直A" },
      { name: "直B" }
    ] }
  ] },
  { name: "安全環境部", type: "environment", sections: [
    { name: "環境安全課" }
  ] }
])

# --- 堺製油所 ---
create_dept_tree(sites[:sakai], [
  { name: "保全部", type: "maintenance", sections: [
    { name: "計器保全課", teams: [
      { name: "計器Aチーム" },
      { name: "計器Bチーム" }
    ] },
    { name: "電気保全課", teams: [
      { name: "電気チーム" }
    ] },
    { name: "検査課", teams: [
      { name: "検査チーム" }
    ] }
  ] },
  { name: "製造部", type: "operation", sections: [
    { name: "第1運転課", teams: [
      { name: "直A" },
      { name: "直B" }
    ] }
  ] },
  { name: "安全環境部", type: "environment", sections: [
    { name: "環境管理課" }
  ] }
])

# --- 和歌山製油所 ---
create_dept_tree(sites[:wakayama], [
  { name: "保全部", type: "maintenance", sections: [
    { name: "計器保全課", teams: [
      { name: "計器チーム" }
    ] },
    { name: "電気保全課", teams: [
      { name: "電気チーム" }
    ] }
  ] },
  { name: "製造部", type: "operation", sections: [
    { name: "運転課", teams: [
      { name: "直A" },
      { name: "直B" }
    ] }
  ] }
])

# --- 仙台製油所 ---
create_dept_tree(sites[:sendai], [
  { name: "保全部", type: "maintenance", sections: [
    { name: "計器保全課", teams: [
      { name: "計器チーム" }
    ] },
    { name: "電気保全課", teams: [
      { name: "電気チーム" }
    ] }
  ] },
  { name: "製造部", type: "operation", sections: [
    { name: "運転課", teams: [
      { name: "直A" }
    ] }
  ] }
])

# --- 千葉製油所（閉鎖） ---
create_dept_tree(sites[:chiba], [
  { name: "保全部", type: "maintenance", sections: [
    { name: "計器保全課" }
  ] },
  { name: "製造部", type: "operation", sections: [
    { name: "運転課" }
  ] }
])
