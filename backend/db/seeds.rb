# frozen_string_literal: true

puts "=== シードデータ投入開始 ==="

Dir[Rails.root.join("db/seeds/*.rb")].sort.each do |file|
  load file
end

puts ""
puts "=== シードデータ投入完了 ==="
puts ""
puts "--- 統計 ---"
puts "拠点: #{Site.count}件（稼働中: #{Site.where(is_active: true).count}件）"
puts "部署: #{Department.count}件（部: #{Department.where(level: 'division').count}件 / 課: #{Department.where(level: 'section').count}件 / チーム: #{Department.where(level: 'team').count}件）"
puts "ユーザ: #{User.count}件（在籍: #{User.where(is_active: true).count}件）"
puts "設備: #{Equipment.count}件"
puts "装置・計器: #{Instrument.count}件"
puts "サービス・流体: #{Service.count}件"
puts "ラインクラス: #{LineClass.count}件"
puts "メーカー: #{Manufacturer.count}件"
puts "資材: #{Material.count}件"
puts "在庫: #{Stock.count}件"
puts "倉庫: #{Warehouse.count}件"
puts "チェックリストテンプレート: #{ChecklistTemplate.count}件"
puts "点検記録: #{Inspection.count}件"
puts "トラブル: #{Trouble.count}件"
puts "定期整備: #{ScheduledMaintenance.count}件"
puts "発注: #{Order.count}件"
puts "修理: #{Repair.count}件"
puts "監査ログ: #{AuditLog.count}件"
puts ""
puts "ログイン情報:"
puts "  システム管理者: admin@example.com / password"
puts "  業務管理者:     suzuki@example.com / password"
puts "  一般:           sato@example.com / password"
