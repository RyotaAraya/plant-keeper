# 外部のシステム（機器管理システム: Emerson AMS Device Manager・横河 PRM など）が PlantKeeper にデータを送るときのトークン。
# ユーザのログイン（JWT）とは別で、管理者が拠点ごとに発行・失効する。平文は発行したときに一度だけ返し、保存するのは SHA-256 だけ
class IntegrationToken < ApplicationRecord
  PREFIX = "pkint_".freeze

  belongs_to :site
  belongs_to :created_by, class_name: "User"
  belongs_to :revoked_by, class_name: "User", optional: true
  has_many :instrument_diagnostics, dependent: :nullify

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  def self.digest(raw) = Digest::SHA256.hexdigest(raw.to_s)

  # 新しいトークンを作り、[記録, 平文] を返す（平文はこのときだけ）
  def self.issue!(name:, site:, created_by:)
    raw = "#{PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    token = create!(name: name, site: site, created_by: created_by, token_digest: digest(raw), token_hint: raw.last(4))
    [ token, raw ]
  end

  # 有効なトークン（失効していない）。見つからなければ nil
  def self.authenticate(raw)
    return if raw.blank?

    active.find_by(token_digest: digest(raw))
  end

  def revoked? = revoked_at.present?

  def revoke!(by:)
    update!(revoked_at: Time.current, revoked_by: by) unless revoked?
  end
end
