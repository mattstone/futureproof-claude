class ScheduledWorkflowJob < ApplicationRecord
  belongs_to :execution, class_name: 'WorkflowExecution'
  belongs_to :step, class_name: 'WorkflowStep'
  
  enum :status, {
    scheduled: 'scheduled',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed',
    cancelled: 'cancelled'
  }
  
  validates :scheduled_for, presence: true
  validates :status, presence: true
  validates :attempts, presence: true
  
  scope :ready_to_process, -> { where('scheduled_for <= ? AND status = ?', Time.current, 'scheduled') }
  scope :failed_jobs, -> { where(status: 'failed') }
  
  def ready_to_execute?
    scheduled? && scheduled_for <= Time.current
  end
  
  def execute!
    return false unless ready_to_execute?
    
    update!(status: 'processing')
    
    begin
      execution.current_step_position = step.position
      execution.save!
      execution.execute_next_step
      
      update!(status: 'completed')
      true
    rescue => e
      increment_attempts!
      update!(status: 'failed', last_error: e.message)
      false
    end
  end
  
  private
  
  def increment_attempts!
    self.attempts += 1
    save!
  end
end
