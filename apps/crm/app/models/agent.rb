# An agent authorized to work for eQuantum ARM. It only researches, analyzes
# and prepares drafts. Commercial actions (sending, contacting, committing a
# price, hiring, spending) are never allowed: they are not in ALLOWED_ACTIONS.
class Agent < ApplicationRecord
  include Auditable

  AREAS = {
    "prospect_ai" => "Prospect AI",
    "sales_intelligence" => "Sales Intelligence",
    "sales_agent" => "Sales Agent",
    "relationship_hub" => "Relationship Hub"
  }.freeze
  EXECUTION_MODES = %w[manual scheduled].freeze
  ALLOWED_ACTIONS = {
    "read_public_sources" => "Leer fuentes públicas autorizadas",
    "ingest_leads" => "Registrar prospectos sin verificar",
    "analyze_leads" => "Proponer análisis y puntaje (pendiente de revisión)",
    "draft_messages" => "Redactar borradores de mensajes",
    "draft_proposals" => "Redactar borradores de propuestas",
    "suggest_follow_ups" => "Sugerir seguimientos"
  }.freeze
  FORBIDDEN_ACTIONS = {
    "send_proposals" => "Enviar propuestas",
    "contact_clients" => "Contactar clientes",
    "commit_prices" => "Comprometer precios",
    "hire_services" => "Contratar servicios",
    "spend_money" => "Realizar gastos"
  }.freeze

  has_many :runs, -> { order(started_at: :desc) }, class_name: "AgentRun", dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :name, presence: true, length: { maximum: 80 }
  validates :area, inclusion: { in: AREAS.keys }
  validates :execution_mode, inclusion: { in: EXECUTION_MODES }
  validates :schedule, presence: { message: "es obligatoria para un agente programado" }, if: -> { execution_mode == "scheduled" }
  validate :actions_are_allowed

  scope :ordered, -> { in_order_of(:area, AREAS.keys).order(:name) }

  def area_name = AREAS.fetch(area, area)
  def last_run = runs.first

  # Honest operating state: an agent only counts as running on its own when
  # it is enabled, scheduled and implemented by code that a worker executes.
  def operating_state
    return :disabled unless enabled
    return :not_implemented if implemented_by.blank?
    return :scheduled if execution_mode == "scheduled"

    :manual
  end

  private
    def actions_are_allowed
      actions = Array(allowed_actions)
      forbidden = actions & FORBIDDEN_ACTIONS.keys
      errors.add(:allowed_actions, "incluye acciones prohibidas: #{forbidden.join(', ')}") if forbidden.any?
      unknown = actions - ALLOWED_ACTIONS.keys - FORBIDDEN_ACTIONS.keys
      errors.add(:allowed_actions, "incluye acciones desconocidas: #{unknown.join(', ')}") if unknown.any?
    end
end
