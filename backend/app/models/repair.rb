class Repair < ApplicationRecord
  include StatusTransitions

  # 依頼中→発送済→修理中→完了。完了・廃棄からは変えられない
  STATUS_TRANSITIONS = {
    "pending" => %w[shipped in_repair disposed],
    "shipped" => %w[in_repair completed disposed],
    "in_repair" => %w[completed disposed],
    "completed" => [],
    "disposed" => []
  }.freeze

  belongs_to :stock
  belongs_to :trouble, optional: true
  belongs_to :requested_by, class_name: "User"

  enum :status, { pending: "pending", shipped: "shipped", in_repair: "in_repair", completed: "completed", disposed: "disposed" }
  enum :disposition, { repair: "repair", dispose: "dispose" }
end
