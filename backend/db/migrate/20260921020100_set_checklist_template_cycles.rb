# チェックリストの周期（巡回・月次・年次・定修）を、名前の末尾から設定する（「伝送器 巡回点検」「安全弁 定修点検」など）。
# 周期が未設定のテンプレートだけが対象で、何度実行しても同じ結果になる（旧テンプレートや利用者が作ったものは、名前が合わなければ触れない）
class SetChecklistTemplateCycles < ActiveRecord::Migration[8.0]
  SUFFIXES = { "巡回点検" => "patrol", "月次点検" => "monthly", "年次点検" => "annual", "定修点検" => "turnaround" }.freeze

  def up
    SUFFIXES.each do |suffix, cycle|
      execute "UPDATE checklist_templates SET cycle = #{connection.quote(cycle)} WHERE cycle IS NULL AND name LIKE #{connection.quote("%#{suffix}")}"
    end
  end

  def down
    # 設定した周期は、利用者が編集した値と区別できないため、ここでは戻さない
  end
end
