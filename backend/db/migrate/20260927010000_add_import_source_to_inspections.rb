# 校正結果のファイルから取り込んだ点検の出所（ファイル名・キャリブレータの型式と製造番号・実施者など）。手入力の点検は NULL
class AddImportSourceToInspections < ActiveRecord::Migration[8.0]
  def change
    add_column :inspections, :import_source, :jsonb
  end
end
