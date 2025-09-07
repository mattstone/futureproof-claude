class WorkflowExecution < ApplicationRecord
  belongs_to :workflow, class_name: 'EmailWorkflow'
  belongs_to :target, polymorphic: true
  has_many :workflow_step_executions, foreign_key: 'execution_id', dependent: :destroy
  has_many :scheduled_workflow_jobs, foreign_key: 'execution_id', dependent: :destroy
  
  # Enums
  enum :status, {
    pending: 'pending',
    processing: 'processing',
    running: 'running',
    completed: 'completed',
    failed: 'failed',
    cancelled: 'cancelled',
    paused: 'paused'
  }
  
  # Validations
  validates :status, presence: true
  validates :current_step_position, presence: true
  
  # Scopes
  scope :active, -> { where(status: ['pending', 'processing', 'running', 'paused']) }
  scope :finished, -> { where(status: ['completed', 'failed', 'cancelled']) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Instance methods
  def start!
    return false unless pending?
    
    update!(
      status: 'running',
      started_at: Time.current
    )
    
    execute_next_step
  end
  
  def current_step
    workflow.workflow_steps.find_by(position: current_step_position)
  end
  
  def next_step
    workflow.workflow_steps.where('position > ?', current_step_position).ordered.first
  end
  
  def execute_next_step
    step = current_step
    return complete! unless step
    
    step_execution = workflow_step_executions.create!(
      step: step,
      status: 'running',
      started_at: Time.current
    )
    
    begin
      result = step.execute_for(self)
      
      if result[:success]
        step_execution.update!(
          status: 'completed',
          completed_at: Time.current,
          result: result
        )
        
        # Move to next step unless it's a delay step
        unless step.step_type == 'delay'
          self.current_step_position += 1
          save!
          execute_next_step
        end
      else
        step_execution.update!(
          status: 'failed',
          completed_at: Time.current,
          result: result,
          error_message: result[:error]
        )
        
        fail_execution!(result[:error])
      end
    rescue => e
      step_execution.update!(
        status: 'failed',
        completed_at: Time.current,
        error_message: e.message
      )
      
      fail_execution!(e.message)
    end
  end
  
  def complete!
    update!(
      status: 'completed',
      completed_at: Time.current
    )
  end
  
  def fail_execution!(error_message)
    update!(
      status: 'failed',
      completed_at: Time.current,
      last_error: error_message
    )
  end
  
  def pause!
    update!(status: 'paused')
  end
  
  def resume!
    return false unless paused?
    update!(status: 'running')
    execute_next_step
  end
  
  def cancel!
    # Cancel any scheduled jobs
    scheduled_workflow_jobs.where(status: 'scheduled').update_all(status: 'cancelled')
    
    update!(
      status: 'cancelled',
      completed_at: Time.current
    )
  end
  
  def duration
    return nil unless started_at
    end_time = completed_at || Time.current
    end_time - started_at
  end
  
  def progress_percentage
    total_steps = workflow.workflow_steps.count
    return 0 if total_steps.zero?
    
    (current_step_position.to_f / total_steps * 100).round(1)
  end
end
