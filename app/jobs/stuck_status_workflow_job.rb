class StuckStatusWorkflowJob < ApplicationJob
  queue_as :default
  
  def perform
    Rails.logger.info "Starting StuckStatusWorkflowJob execution"
    
    begin
      process_stuck_applications
      process_stuck_contracts
      cleanup_old_execution_records
    rescue => e
      Rails.logger.error "Error in StuckStatusWorkflowJob: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    ensure
      Rails.logger.info "Completed StuckStatusWorkflowJob execution"
    end
  end

  private

  def process_stuck_applications
    workflows = EmailWorkflow.active.where(
      trigger_type: ['application_stuck_at_status']
    )
    
    workflows.each do |workflow|
      process_application_workflow(workflow)
    end
  end

  def process_stuck_contracts
    workflows = EmailWorkflow.active.where(
      trigger_type: ['contract_stuck_at_status'] 
    )
    
    workflows.each do |workflow|
      process_contract_workflow(workflow)
    end
  end

  def process_application_workflow(workflow)
    config = parse_workflow_config(workflow)
    return unless config

    status = config['stuck_status']
    duration = config['stuck_duration']&.to_i
    unit = config['stuck_unit'] || 'days'
    run_once = config['run_once'] || false

    return unless status && duration

    # Find applications stuck at this status for the specified duration
    stuck_applications = find_stuck_applications(status, duration, unit)
    trigger_key = WorkflowExecutionTracker.generate_stuck_status_key(status, duration, unit)

    Rails.logger.info "Found #{stuck_applications.count} applications stuck at #{status} for #{duration} #{unit}"

    stuck_applications.each do |application|
      next if WorkflowExecutionTracker.already_executed?(workflow, application, trigger_key, run_once: run_once)

      begin
        # Execute the workflow for this application
        WorkflowExecutionService.new(workflow, application).execute!
        
        # Record the execution
        WorkflowExecutionTracker.record_execution!(
          workflow, 
          application, 
          'application_stuck_at_status',
          trigger_key,
          run_once: run_once
        )
        
        Rails.logger.info "Executed workflow #{workflow.id} for stuck application #{application.id}"
      rescue => e
        Rails.logger.error "Failed to execute workflow #{workflow.id} for application #{application.id}: #{e.message}"
      end
    end
  end

  def process_contract_workflow(workflow)
    config = parse_workflow_config(workflow)
    return unless config

    status = config['stuck_contract_status']
    duration = config['stuck_duration']&.to_i
    unit = config['stuck_unit'] || 'days'
    run_once = config['run_once'] || false

    return unless status && duration

    # Find contracts stuck at this status for the specified duration
    stuck_contracts = find_stuck_contracts(status, duration, unit)
    trigger_key = WorkflowExecutionTracker.generate_stuck_status_key(status, duration, unit)

    Rails.logger.info "Found #{stuck_contracts.count} contracts stuck at #{status} for #{duration} #{unit}"

    stuck_contracts.each do |contract|
      next if WorkflowExecutionTracker.already_executed?(workflow, contract, trigger_key, run_once: run_once)

      begin
        # Execute the workflow for this contract
        WorkflowExecutionService.new(workflow, contract).execute!
        
        # Record the execution
        WorkflowExecutionTracker.record_execution!(
          workflow,
          contract,
          'contract_stuck_at_status',
          trigger_key,
          run_once: run_once
        )
        
        Rails.logger.info "Executed workflow #{workflow.id} for stuck contract #{contract.id}"
      rescue => e
        Rails.logger.error "Failed to execute workflow #{workflow.id} for contract #{contract.id}: #{e.message}"
      end
    end
  end

  def find_stuck_applications(status, duration, unit)
    time_threshold = duration.send(unit).ago

    Application.where(status: status)
               .where('updated_at <= ?', time_threshold)
               .includes(:user)
  end

  def find_stuck_contracts(status, duration, unit)
    time_threshold = duration.send(unit).ago

    Contract.where(status: status)
            .where('updated_at <= ?', time_threshold)
            .includes(application: :user)
  end

  def parse_workflow_config(workflow)
    # Get the trigger node configuration from the workflow data
    workflow_data = workflow.workflow_builder_data || {}
    nodes = workflow_data['nodes'] || []
    trigger_node = nodes.find { |node| node['type'] == 'trigger' }
    
    trigger_node&.dig('config') || {}
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse workflow config for workflow #{workflow.id}: #{e.message}"
    nil
  end

  def cleanup_old_execution_records
    Rails.logger.info "Cleaning up old workflow execution records"
    deleted_count = WorkflowExecutionTracker.cleanup_old_records!
    Rails.logger.info "Cleaned up #{deleted_count} old execution records"
  end
end