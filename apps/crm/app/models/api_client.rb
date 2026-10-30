# A service (Prospect AI, a Skill runner) that calls the CRM API. Only a
# SHA-256 digest of the token is stored; the token is shown once on creation.
class ApiClient < ApplicationRecord
  SCOPES = %w[leads:ingest].freeze
  TOKEN_PREFIX = "eqcrm_".freeze

  has_many :ingestion_requests, dependent: :destroy

  validates :name, presence: true, uniqueness: true, length: { maximum: 80 }
  validates :token_digest, presence: true, uniqueness: true
  validate :scopes_are_known

  scope :active, -> { where(active: true) }

  # Returns [client, plaintext_token]. The plaintext is never persisted.
  def self.issue!(name:, scopes: SCOPES)
    token = "#{TOKEN_PREFIX}#{SecureRandom.base58(40)}"
    client = create!(name: name, scopes: scopes, token_digest: digest(token), token_prefix: token.first(12))
    [ client, token ]
  end

  def self.authenticate(token)
    return if token.blank? || !token.start_with?(TOKEN_PREFIX)

    active.find_by(token_digest: digest(token))
  end

  def self.digest(token) = Digest::SHA256.hexdigest(token)

  def allowed?(scope) = scopes.include?(scope)

  def touch_last_used!
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 1.minute.ago
  end

  private
    def scopes_are_known
      errors.add(:scopes, "contiene alcances desconocidos") if (scopes - SCOPES).any?
    end
end
