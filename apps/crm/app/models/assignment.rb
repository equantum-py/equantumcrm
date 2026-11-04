# History of proposals and confirmations for an inbox item. Rows are closed
# with ended_at, never deleted.
class Assignment < ApplicationRecord
  include Auditable

  KINDS = %w[proposed confirmed].freeze
  SOURCES = %w[rule manager].freeze

  belongs_to :inbox_item
  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :source, inclusion: { in: SOURCES }
  validates :started_at, presence: true

  scope :current, -> { where(ended_at: nil) }
end
