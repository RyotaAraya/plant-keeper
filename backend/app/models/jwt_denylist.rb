# ログアウトしたトークンの失効リスト。トークン（jti）ごとに記録するので、
# 同じユーザの他の端末のトークンには影響しない
class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist

  self.table_name = "jwt_denylists"

  # 期限切れのトークンは、有効期限の検証で拒否されるため、失効の記録は要らない。失効のたびに掃除して肥大化を防ぐ
  def self.revoke_jwt(payload, _user)
    where(exp: ...Time.current).delete_all
    find_or_create_by!(jti: payload["jti"], exp: Time.at(payload["exp"].to_i))
  end
end
