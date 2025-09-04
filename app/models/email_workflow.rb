class EmailWorkflow < ApplicationRecord
  belongs_to :created_by, class_name: 'User'
  has_many :workflow_steps, foreign_key: 'workflow_id', dependent: :destroy
  has_many :workflow_executions, foreign_key: 'workflow_id', dependent: :destroy
  
  # Nested attributes
  accepts_nested_attributes_for :workflow_steps, allow_destroy: true
  
  # Enums
  enum :trigger_type, {
    application_status_changed: 'application_status_changed',
    application_created: 'application_created', 
    user_registered: 'user_registered',
    time_delay: 'time_delay',
    document_uploaded: 'document_uploaded',
    inactivity: 'inactivity',
    contract_signed: 'contract_signed'
  }
  
  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :trigger_type, presence: true
  validates :trigger_conditions, presence: true
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_trigger, ->(trigger) { where(trigger_type: trigger) }
  
  # Instance methods
  def can_trigger_for?(target, conditions = {})
    return false unless active?
    
    case trigger_type
    when 'application_status_changed'
      target.is_a?(Application) && 
        trigger_conditions['from_status'].nil? || 
        conditions[:from_status].to_s == trigger_conditions['from_status']
    when 'application_created'
      target.is_a?(Application)
    when 'user_registered'
      target.is_a?(User)
    else
      true
    end
  end
  
  def execute_for(target, context = {})
    return unless can_trigger_for?(target, context)
    
    execution = workflow_executions.create!(
      target: target,
      status: 'pending',
      context: context
    )
    
    EmailWorkflowExecutorJob.perform_later(execution)
    execution
  end
end
