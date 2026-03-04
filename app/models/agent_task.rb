class AgentTask < ApplicationRecord
  belongs_to :agent_performance

  STATUSES = %w[pending in_progress completed escalated].freeze
  TASK_TYPES = %w[application_review document_verify customer_query compliance_check report_generation onboarding_assist loan_setup status_update].freeze
  PRIORITIES = %w[low normal high urgent].freeze

  validates :task_type, inclusion: { in: TASK_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :priority, inclusion: { in: PRIORITIES }

  scope :pending, -> { where(status: "pending") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }
  scope :recent, -> { order(completed_at: :desc) }
  scope :today, -> { where("completed_at >= ?", Time.current.beginning_of_day) }
end
