class WorkflowExecutionTracker < ApplicationRecord
  belongs_to :email_workflow
  belongs_to :target, polymorphic: true

  validates :trigger_type, presence: true
  validates :trigger_key, presence: true
  validates :executed_at, presence: true

  scope :for_workflow, ->(workflow) { where(email_workflow: workflow) }
  scope :for_target, ->(target) { where(target: target) }
  scope :run_once_only, -> { where(run_once: true) }
  scope :recent, -> { where(executed_at: 30.days.ago..) }

  # Check if a workflow has already been executed for a target with run_once logic
  def self.already_executed?(workflow, target, trigger_key, run_once: false)
    return false unless run_once
    
    exists?(
      email_workflow: workflow,
      target: target,
      trigger_key: trigger_key,
      run_once: true
    )
  end

  # Record a workflow execution
  def self.record_execution!(workflow, target, trigger_type, trigger_key, run_once: false)
    create!(
      email_workflow: workflow,
      target: target,
      trigger_type: trigger_type,
      trigger_key: trigger_key,
      executed_at: Time.current,
      run_once: run_once
    )
  rescue ActiveRecord::RecordNotUnique
    # Already executed - this is expected for run_once workflows
    Rails.logger.info "Workflow #{workflow.id} already executed for #{target.class.name}##{target.id} with key #{trigger_key}"
    nil
  end

  # Generate a unique trigger key for stuck status workflows
  def self.generate_stuck_status_key(status, duration, unit)
    "stuck_#{status}_#{duration}_#{unit}"
  end

  # Cleanup old execution records to prevent table growth
  def self.cleanup_old_records!
    where('executed_at < ?', 90.days.ago).delete_all
  end

  # Get execution summary for admin
  def display_summary
    "#{trigger_type.humanize} for #{target.class.name} ##{target.id} at #{executed_at.strftime('%Y-%m-%d %H:%M')}"
  end
end