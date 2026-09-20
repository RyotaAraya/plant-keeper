# チェックリストテンプレートを「廃止」できるようにする。過去の点検記録が参照しているテンプレートは消せないため、
# 使わなくなったものは廃止（is_active=false）にして、点検の選択肢から外す
class AddIsActiveToChecklistTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :checklist_templates, :is_active, :boolean, null: false, default: true
  end
end
