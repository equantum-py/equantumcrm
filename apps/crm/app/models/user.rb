class User < ApplicationRecord
  include Auditable

  has_secure_password
  belongs_to :role
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def can?(permission_key)
    permission_keys.include?(permission_key.to_s)
  end

  def admin?
    role.key == "admin"
  end

  private
    def permission_keys
      @permission_keys ||= role.permissions.pluck(:key).to_set
    end
end
