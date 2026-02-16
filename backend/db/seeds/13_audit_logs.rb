# frozen_string_literal: true

puts "監査ログを作成中..."

def user_by(email) = User.find_by!(email: email)

tanaka = user_by("admin@example.com")
sato = user_by("sato@example.com")
suzuki = user_by("suzuki@example.com")
ito = user_by("ito@example.com")
sasaki = user_by("sasaki@example.com")
kimura = user_by("kimura@example.com")
fujita = user_by("fujita@example.com")
morita = user_by("morita@example.com")

t3 = Trouble.find_by!(title: "FT-301 オリフィス閉塞疑い")
t1 = Trouble.find_by!(title: "PV-201 グランドパッキン漏れ")
insp3 = Inspection.joins(:instrument).find_by!(instruments: { tag_number: "TV-601" }, status: "approval_requested")
insp9 = Inspection.joins(:instrument).find_by!(instruments: { tag_number: "TV-S101" }, status: "approved")

AuditLog.create!(user: tanaka, action: "login", auditable_type: "User", auditable_id: tanaka.id, ip_address: "192.168.1.100", performed_at: 1.hour.ago)
AuditLog.create!(user: sato, action: "create", auditable_type: "Trouble", auditable_id: t3.id, changes_json: { title: [ nil, "FT-301 オリフィス閉塞疑い" ], status: [ nil, "open" ] }, ip_address: "192.168.1.105", performed_at: 1.day.ago)
AuditLog.create!(user: suzuki, action: "update", auditable_type: "Trouble", auditable_id: t1.id, changes_json: { status: [ "in_progress", "resolved" ], resolved_at: [ nil, 5.days.ago.iso8601 ] }, ip_address: "192.168.1.102", performed_at: 5.days.ago)
AuditLog.create!(user: sato, action: "approval_request", auditable_type: "Inspection", auditable_id: insp3.id, changes_json: { status: [ "submitted", "approval_requested" ] }, ip_address: "192.168.1.105", performed_at: 1.day.ago)
AuditLog.create!(user: suzuki, action: "login", auditable_type: "User", auditable_id: suzuki.id, ip_address: "192.168.1.102", performed_at: 2.hours.ago)
AuditLog.create!(user: ito, action: "login", auditable_type: "User", auditable_id: ito.id, ip_address: "192.168.2.100", performed_at: 3.hours.ago)
AuditLog.create!(user: sasaki, action: "login", auditable_type: "User", auditable_id: sasaki.id, ip_address: "192.168.3.100", performed_at: 4.hours.ago)
AuditLog.create!(user: tanaka, action: "update", auditable_type: "User", auditable_id: morita.id, changes_json: { is_active: [ true, false ], deactivated_on: [ nil, "2024-03-31" ] }, ip_address: "192.168.1.100", performed_at: 300.days.ago)
AuditLog.create!(user: kimura, action: "create", auditable_type: "Inspection", auditable_id: insp9.id, changes_json: { status: [ nil, "approved" ] }, ip_address: "192.168.2.105", performed_at: 3.days.ago)
AuditLog.create!(user: fujita, action: "create", auditable_type: "StockTransaction", auditable_id: StockTransaction.first!.id, changes_json: { transaction_type: "outgoing", quantity: 2 }, ip_address: "192.168.1.110", performed_at: 15.days.ago)
