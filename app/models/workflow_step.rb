class WorkflowStep < ApplicationRecord
  belongs_to :workflow, class_name: 'EmailWorkflow'
  has_many :workflow_step_executions, foreign_key: 'step_id', dependent: :destroy
  has_many :scheduled_workflow_jobs, foreign_key: 'step_id', dependent: :destroy
  
  # Enums
  enum :step_type, {
    send_email: 'send_email',
    delay: 'delay',
    condition: 'condition',
    update_status: 'update_status',
    webhook: 'webhook',
    wait_for_event: 'wait_for_event'
  }
  
  # Validations
  validates :step_type, presence: true
  validates :position, presence: true, uniqueness: { scope: :workflow_id }
  validates :configuration, presence: true
  
  # Custom validations
  validate :valid_configuration_for_step_type
  
  # Scopes
  scope :ordered, -> { order(:position) }
  scope :of_type, ->(type) { where(step_type: type) }
  
  # Instance methods
  def next_step
    workflow.workflow_steps.where('position > ?', position).ordered.first
  end
  
  def previous_step
    workflow.workflow_steps.where('position < ?', position).order(position: :desc).first
  end
  
  def execute_for(execution)
    case step_type
    when 'send_email'
      execute_send_email(execution)
    when 'delay'
      execute_delay(execution)
    when 'condition'
      execute_condition(execution)
    when 'update_status'
      execute_update_status(execution)
    else
      { success: false, error: "Unknown step type: #{step_type}" }
    end
  end
  
  private
  
  def valid_configuration_for_step_type
    case step_type
    when 'send_email'
      validate_email_configuration
    when 'delay'
      validate_delay_configuration
    when 'condition'
      validate_condition_configuration
    end
  end
  
  def validate_email_configuration
    unless configuration['email_template_id'].present?
      errors.add(:configuration, 'must include email_template_id for send_email steps')
    end
  end
  
  def validate_delay_configuration
    unless configuration['duration'].present? && configuration['unit'].present?
      errors.add(:configuration, 'must include duration and unit for delay steps')
    end
  end
  
  def validate_condition_configuration
    unless configuration['condition_type'].present?
      errors.add(:configuration, 'must include condition_type for condition steps')
    end
  end
  
  def execute_send_email(execution)
    template = EmailTemplate.find_by(id: configuration['email_template_id'])
    return { success: false, error: 'Email template not found' } unless template
    
    begin
      rendered = template.render_content(execution.context)
      
      AdminMailer.workflow_email(
        to: execution.target.email,
        subject: rendered[:subject],
        content: rendered[:content]
      ).deliver_now
      
      { success: true, message: 'Email sent successfully' }
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def execute_delay(execution)
    duration = configuration['duration'].to_i
    unit = configuration['unit']
    
    scheduled_time = case unit
                    when 'minutes' then duration.minutes.from_now
                    when 'hours' then duration.hours.from_now
                    when 'days' then duration.days.from_now
                    else 1.hour.from_now
                    end
    
    scheduled_workflow_jobs.create!(
      execution: execution,
      scheduled_for: scheduled_time
    )
    
    { success: true, message: "Scheduled for #{scheduled_time}" }
  end
  
  def execute_condition(execution)
    condition_type = configuration['condition_type']
    
    case condition_type
    when 'application_status'
      expected_status = configuration['expected_status']
      actual_status = execution.target.status
      
      result = actual_status == expected_status
      { success: true, condition_met: result, message: "Condition #{result ? 'met' : 'not met'}" }
    else
      { success: false, error: "Unknown condition type: #{condition_type}" }
    end
  end
  
  def execute_update_status(execution)
    field = configuration['field']
    value = configuration['value']
    
    return { success: false, error: 'Invalid field or value' } unless field && value
    
    begin
      execution.target.update!(field => value)
      { success: true, message: "Updated #{field} to #{value}" }
    rescue => e
      { success: false, error: e.message }
    end
  end
end
