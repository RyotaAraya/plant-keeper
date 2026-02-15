class Repair < ApplicationRecord
  belongs_to :stock
  belongs_to :trouble, optional: true
  belongs_to :requested_by, class_name: "User"

  enum :status, { pending: "pending", shipped: "shipped", in_repair: "in_repair", completed: "completed", disposed: "disposed" }
  enum :disposition, { repair: "repair", dispose: "dispose" }
end
