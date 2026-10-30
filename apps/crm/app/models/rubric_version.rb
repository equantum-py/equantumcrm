# Which rubric is in force. Only one version can be active; a new version is
# seeded as a draft and changes nothing until it is activated on purpose.
class RubricVersion < ApplicationRecord
  include Auditable

  STATUSES = %w[draft active retired].freeze
  PRIORITY_FROM_VERSION = 2

  belongs_to :approved_by, class_name: "User", optional: true

  validates :version, presence: true, uniqueness: true
  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }

  def self.active_version
    find_by(status: "active")&.version
  end

  # Commercial priority belongs to rubric v2; it stays off until v2 is active.
  def self.priority_enabled?
    (active_version || 0) >= PRIORITY_FROM_VERSION
  end
end
