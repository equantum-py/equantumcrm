class Company < ApplicationRecord
  include Auditable

  belongs_to :country, optional: true
  belongs_to :owner, class_name: "User", optional: true
  has_many :company_services, dependent: :destroy
  has_many :services, through: :company_services
  has_many :leads, dependent: :restrict_with_error
  has_many :opportunities, dependent: :restrict_with_error
  has_many :activities, as: :subject, dependent: :destroy

  normalizes :website, with: ->(url) { url.strip.presence }

  before_validation :set_normalized_domain

  validates :trade_name, presence: true, length: { maximum: 200 }
  validates :normalized_domain, uniqueness: { allow_nil: true, message: "ya está registrado en otra empresa" }
  validate :website_is_http

  scope :ordered, -> { order(:trade_name) }

  def self.search(query)
    return all if query.blank?

    term = "%#{sanitize_sql_like(query.strip)}%"
    where("trade_name ILIKE :t OR legal_name ILIKE :t OR normalized_domain ILIKE :t", t: term)
  end

  def to_s = trade_name

  private
    def set_normalized_domain
      self.normalized_domain = UrlCanonicalizer.domain(website)
    end

    def website_is_http
      return if website.blank?

      errors.add(:website, "debe ser una URL http(s) válida") unless UrlCanonicalizer.http_url?(website)
    end
end
