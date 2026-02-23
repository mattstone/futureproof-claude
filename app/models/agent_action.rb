class AgentAction < ApplicationRecord
  belongs_to :ai_agent
  belongs_to :actionable, polymorphic: true, optional: true

  ACTION_TYPES = %w[evaluate decide communicate escalate handoff].freeze
  DECISIONS = %w[approve flag reject advance request_info].freeze
  STATUSES = %w[pending completed overridden failed].freeze

  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES }
  validates :decision, inclusion: { in: DECISIONS }, allow_nil: true
  validates :confidence, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }

  scope :for_entity, ->(entity) { where(actionable: entity) }
  scope :evaluations, -> { where(action_type: 'evaluate') }
  scope :decisions, -> { where(action_type: 'decide') }
  scope :by_agent, ->(agent) { where(ai_agent: agent) }

  def override!(by:, reason:)
    update!(
      status: 'overridden',
      overridden_by: by,
      override_reason: reason
    )
  end
end
