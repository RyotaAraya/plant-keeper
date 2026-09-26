# インターロックのバイパスの JSON（一覧・インターロック詳細・ダッシュボードで共通）
module InterlockBypassJson
  BYPASS_USERS = %i[requested_by approved_by bypassed_by restored_by confirmed_by closed_by].freeze
  BYPASS_INCLUDES = [ *BYPASS_USERS, { interlock: { equipment: :site } } ].freeze

  private

  def bypass_json(bypass, now: Time.current)
    bypass.as_json(except: [ :created_at, :updated_at ]).merge(
      "overdue" => bypass.overdue?(now),
      "bypassed_hours" => bypass.bypassed_hours(now),
      "interlock" => {
        "id" => bypass.interlock.id, "tag_number" => bypass.interlock.tag_number, "name" => bypass.interlock.name,
        "equipment" => { "id" => bypass.interlock.equipment.id, "name" => bypass.interlock.equipment.name,
                         "site" => bypass.interlock.equipment.site.as_json(only: [ :id, :name ]) }
      }
    ).merge(BYPASS_USERS.to_h { |key| [ key.to_s, bypass.public_send(key)&.as_json(only: [ :id, :name ]) ] })
  end
end
