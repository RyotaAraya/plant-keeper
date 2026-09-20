# 部署名の誤り「計器保全課」を、正しい「計装保全課」に直す（既存環境の部署と、基準器のデモデータの保管場所・校正者の文言）。
# 生SQLで、何度実行しても同じ結果になる。監査ログの過去の記録は、当時の内容のまま残す
class RenameInstrumentationSection < ActiveRecord::Migration[8.0]
  OLD_NAME = "計器保全課"
  NEW_NAME = "計装保全課"

  def up
    execute "UPDATE departments SET name = #{connection.quote(NEW_NAME)} WHERE name = #{connection.quote(OLD_NAME)}"
    replace_text "reference_standards", "location"
    replace_text "reference_standard_calibrations", "performed_by"
  end

  def down
    # 利用者が同じ名前で作った部署と区別できないため、ここでは戻さない
  end

  private

  def replace_text(table, column)
    execute "UPDATE #{table} SET #{column} = REPLACE(#{column}, #{connection.quote(OLD_NAME)}, #{connection.quote(NEW_NAME)}) WHERE #{column} LIKE #{connection.quote("%#{OLD_NAME}%")}"
  end
end
