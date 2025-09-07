class DelayedWorkflowContinuationJob < ApplicationJob
  queue_as :default

  def perform(execution_id, delay_node_id, workflow_data)
    execution = WorkflowExecution.find_by(id: execution_id)
    return unless execution&.workflow&.active?

    Rails.logger.info "Continuing delayed workflow execution #{execution_id} after delay node #{delay_node_id}"

    nodes = workflow_data['nodes'] || []
    connections = workflow_data['connections'] || []
    
    # Find the delay node that triggered this continuation
    delay_node = nodes.find { |node| node['id'] == delay_node_id }
    return unless delay_node

    # Find and process next nodes after the delay
    next_nodes = find_next_nodes(delay_node, nodes, connections)
    
    service = WorkflowExecutionService.new(execution.email_workflow, execution.target, execution.context)
    
    next_nodes.each do |node|
      service.send(:process_node_chain, node, nodes, connections, execution)
    end

    Rails.logger.info "Completed delayed workflow continuation for execution #{execution_id}"
  rescue => e
    Rails.logger.error "Error in DelayedWorkflowContinuationJob: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def find_next_nodes(current_node, nodes, connections)
    relevant_connections = connections.select { |conn| conn['from'] == current_node['id'] }
    
    relevant_connections.map do |connection|
      nodes.find { |node| node['id'] == connection['to'] }
    end.compact
  end
end