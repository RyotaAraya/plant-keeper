# 運転中に直せないトラブルを、定期整備の作業に回す。作業がトラブルを指す（トラブルは「定修待ち」になる）
class AddTroubleToMaintenanceTasks < ActiveRecord::Migration[8.0]
  def change
    add_reference :maintenance_tasks, :trouble, foreign_key: true
  end
end
