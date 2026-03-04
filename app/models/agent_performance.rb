class AgentPerformance < ApplicationRecord
  has_many :agent_tasks, dependent: :destroy

  STATUSES = %w[idle processing on_break offline].freeze
  AGENT_TYPES = %w[ai human].freeze

  validates :agent_name, presence: true
  validates :agent_type, inclusion: { in: AGENT_TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where.not(status: "offline") }
  scope :ai_agents, -> { where(agent_type: "ai") }
  scope :human_agents, -> { where(agent_type: "human") }
  scope :processing, -> { where(status: "processing") }

  def complete_task!(task)
    task.update!(status: "completed", completed_at: Time.current)
    increment!(:tasks_completed_today)
    increment!(:tasks_completed_week)
    increment!(:tasks_completed_month)
    update!(
      status: "idle",
      current_task: nil,
      last_active_at: Time.current,
      avg_resolution_minutes: agent_tasks.completed.average(:resolution_minutes) || 0
    )
  end
end
