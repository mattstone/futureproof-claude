class ScheduledWorkflowProcessorJob < ApplicationJob
  queue_as :default
  
  # This job runs regularly to process scheduled workflow steps
  def perform
    Rails.logger.info "Processing scheduled workflow jobs..."
    
    processed_count = 0
    failed_count = 0
    
    ScheduledWorkflowJob.ready_to_process.find_each do |job|
      begin
        if job.execute!
          processed_count += 1
          Rails.logger.info "Successfully executed scheduled job #{job.id}"
        else
          failed_count += 1
          Rails.logger.warn "Failed to execute scheduled job #{job.id}: #{job.last_error}"
        end
      rescue => e
        failed_count += 1
        Rails.logger.error "Error processing scheduled job #{job.id}: #{e.message}"
      end
    end
    
    Rails.logger.info "Processed #{processed_count} scheduled jobs, #{failed_count} failed"
  end
end
