class PipelineStage < ApplicationRecord
  KINDS = %w[open won lost].freeze

  has_many :opportunities, dependent: :restrict_with_error

  validates :name, presence: true
  validates :position, presence: true, uniqueness: true
  validates :kind, inclusion: { in: KINDS }
  validates :probability, numericality: { in: 0..100 }

  scope :ordered, -> { order(:position) }

  def won? = kind == "won"
  def lost? = kind == "lost"
  def closed? = won? || lost?
end
