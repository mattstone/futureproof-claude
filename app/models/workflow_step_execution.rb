class WorkflowStepExecution < ApplicationRecord
  belongs_to :execution, class_name: 'WorkflowExecution'
  belongs_to :step, class_name: 'WorkflowStep'
  
  enum :status, {
    pending: 'pending',
    running: 'running', 
    completed: 'completed',
    failed: 'failed'
  }
  
  validates :status, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  
  def duration
    return nil unless started_at
    end_time = completed_at || Time.current
    end_time - started_at
  end
end
