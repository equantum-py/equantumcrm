class AuditLog < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def self.record!(action:, auditable: nil, changeset: {})
    create!(
      action: action,
      auditable: auditable,
      changeset: changeset,
      actor: Current.user,
      ip_address: Current.ip_address,
      request_id: Current.request_id
    )
  end

  def readonly?
    persisted?
  end
end
