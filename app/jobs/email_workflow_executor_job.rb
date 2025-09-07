class EmailWorkflowExecutorJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(execution)
    return unless execution.pending?
    
    Rails.logger.info "Starting workflow execution #{execution.id} for #{execution.target_type}##{execution.target_id}"
    
    execution.start!
  rescue => e
    Rails.logger.error "Failed to execute workflow #{execution.id}: #{e.message}"
    execution.fail_execution!(e.message)
    raise
  end
end
