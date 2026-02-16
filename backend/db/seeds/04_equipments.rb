# frozen_string_literal: true

puts "倉庫を作成中..."

kawasaki  = Site.find_by!(name: "川崎製油所")
negishi   = Site.find_by!(name: "根岸製油所")
sakai     = Site.find_by!(name: "堺製油所")
wakayama  = Site.find_by!(name: "和歌山製油所")
sendai    = Site.find_by!(name: "仙台製油所")

Warehouse.create!(site: kawasaki,  name: "川崎第1倉庫")
Warehouse.create!(site: kawasaki,  name: "川崎第2倉庫")
Warehouse.create!(site: kawasaki,  name: "川崎危険物保管庫")
Warehouse.create!(site: negishi,   name: "根岸倉庫")
Warehouse.create!(site: negishi,   name: "根岸第2倉庫")
Warehouse.create!(site: sakai,     name: "堺第1倉庫")
Warehouse.create!(site: sakai,     name: "堺第2倉庫")
Warehouse.create!(site: wakayama,  name: "和歌山倉庫")
Warehouse.create!(site: sendai,    name: "仙台倉庫")
Warehouse.create!(site: sendai,    name: "仙台第2倉庫")

puts "設備を作成中..."

chiba = Site.find_by!(name: "千葉製油所")

# 川崎
Equipment.create!(site: kawasaki, name: "常圧蒸留装置", description: "CDU（Crude Distillation Unit）。原油を常圧で蒸留し、ナフサ・灯油・軽油・残渣油に分離する装置。")
Equipment.create!(site: kawasaki, name: "重油間接脱硫装置", description: "RHDS（Residue Hydro-Desulfurization）。重油中の硫黄分を水素化脱硫により除去する装置。")
Equipment.create!(site: kawasaki, name: "流動接触分解装置", description: "FCC（Fluid Catalytic Cracking）。重質油を軽質油に変換する装置。")
Equipment.create!(site: kawasaki, name: "ボイラー設備", description: "プラント用スチーム供給設備。高圧・中圧・低圧スチームを生成。")
Equipment.create!(site: kawasaki, name: "接触改質装置", description: "CRF。ナフサからオクタン価の高いガソリン基材を製造する装置。")
Equipment.create!(site: kawasaki, name: "減圧蒸留装置", description: "VDU（Vacuum Distillation Unit）。常圧残渣油を減圧下で蒸留する装置。")
Equipment.create!(site: kawasaki, name: "タンク設備", description: "原油・製品貯蔵タンク群。浮屋根式・固定屋根式。")
# 根岸
Equipment.create!(site: negishi, name: "常圧蒸留装置", description: "根岸CDU。原油処理能力27万バレル/日。")
Equipment.create!(site: negishi, name: "軽油脱硫装置", description: "HDS。軽油中の硫黄分を除去する装置。")
Equipment.create!(site: negishi, name: "ボイラー設備", description: "根岸工場スチーム供給設備。")
Equipment.create!(site: negishi, name: "タンク設備", description: "根岸工場タンクヤード。")
# 堺
Equipment.create!(site: sakai, name: "常圧蒸留装置", description: "堺CDU。")
Equipment.create!(site: sakai, name: "軽油脱硫装置", description: "HDS。軽油中の硫黄分を除去する装置。")
Equipment.create!(site: sakai, name: "接触改質装置", description: "CRF。ナフサからガソリン基材を製造。")
Equipment.create!(site: sakai, name: "ボイラー設備", description: "堺工場スチーム供給設備。")
Equipment.create!(site: sakai, name: "タンク設備", description: "堺工場タンクヤード。")
# 和歌山
Equipment.create!(site: wakayama, name: "常圧蒸留装置", description: "和歌山CDU。")
Equipment.create!(site: wakayama, name: "流動接触分解装置", description: "和歌山FCC。")
Equipment.create!(site: wakayama, name: "ボイラー設備", description: "和歌山工場スチーム供給設備。")
Equipment.create!(site: wakayama, name: "タンク設備", description: "和歌山工場タンクヤード。")
# 仙台
Equipment.create!(site: sendai, name: "潤滑油製造装置", description: "LK（Lube King）。基油から潤滑油を製造する装置。")
Equipment.create!(site: sendai, name: "ボイラー設備", description: "仙台工場スチーム供給設備。")
Equipment.create!(site: sendai, name: "タンク設備", description: "仙台工場タンクヤード。浮屋根式・固定屋根式。")
Equipment.create!(site: sendai, name: "軽油脱硫装置", description: "仙台HDS。軽油中の硫黄分を除去。")
# 千葉（閉鎖済）
Equipment.create!(site: chiba, name: "常圧蒸留装置", description: "千葉CDU。2024年3月閉鎖。")
