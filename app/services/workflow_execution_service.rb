class WorkflowExecutionService
  attr_reader :workflow, :target, :context

  def initialize(workflow, target, context = {})
    @workflow = workflow
    @target = target
    @context = context
  end

  def execute!
    return unless workflow&.active?

    Rails.logger.info "Executing workflow #{workflow.id} for #{target.class.name}##{target.id}"

    execution = create_workflow_execution
    process_workflow_steps(execution)
    
    execution
  rescue => e
    Rails.logger.error "Failed to execute workflow #{workflow.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def create_workflow_execution
    workflow.workflow_executions.create!(
      target: target,
      status: 'processing',
      context: context,
      started_at: Time.current
    )
  end

  def process_workflow_steps(execution)
    workflow_data = workflow.workflow_builder_data || {}
    nodes = workflow_data['nodes'] || []
    connections = workflow_data['connections'] || []

    # Find the trigger node (starting point)
    trigger_node = nodes.find { |node| node['type'] == 'trigger' }
    return unless trigger_node

    # Process nodes starting from trigger
    process_node_chain(trigger_node, nodes, connections, execution)
    
    execution.update!(
      status: 'completed',
      completed_at: Time.current
    )
  end

  def process_node_chain(current_node, nodes, connections, execution)
    case current_node['type']
    when 'trigger'
      # Trigger node is just the starting point, move to next nodes
      next_nodes = find_next_nodes(current_node, nodes, connections)
      next_nodes.each { |node| process_node_chain(node, nodes, connections, execution) }

    when 'email'
      process_email_node(current_node, execution)
      next_nodes = find_next_nodes(current_node, nodes, connections)
      next_nodes.each { |node| process_node_chain(node, nodes, connections, execution) }

    when 'delay'
      process_delay_node(current_node, execution)
      # Delay nodes don't immediately continue - they schedule the next steps

    when 'condition'
      if evaluate_condition(current_node)
        next_nodes = find_next_nodes(current_node, nodes, connections, 'true')
        next_nodes.each { |node| process_node_chain(node, nodes, connections, execution) }
      else
        next_nodes = find_next_nodes(current_node, nodes, connections, 'false')
        next_nodes.each { |node| process_node_chain(node, nodes, connections, execution) }
      end

    when 'update'
      process_update_node(current_node, execution)
      next_nodes = find_next_nodes(current_node, nodes, connections)
      next_nodes.each { |node| process_node_chain(node, nodes, connections, execution) }
    end
  end

  def find_next_nodes(current_node, nodes, connections, condition_result = nil)
    relevant_connections = connections.select { |conn| conn['from'] == current_node['id'] }
    
    # For condition nodes, filter by the condition result
    if current_node['type'] == 'condition' && condition_result
      relevant_connections = relevant_connections.select { |conn| conn['condition'] == condition_result }
    end

    relevant_connections.map do |connection|
      nodes.find { |node| node['id'] == connection['to'] }
    end.compact
  end

  def process_email_node(node, execution)
    config = node['config'] || {}
    template_id = config['email_template_id']
    subject_override = config['subject']
    
    return unless template_id

    template = EmailTemplate.find_by(id: template_id)
    return unless template

    Rails.logger.info "Sending email using template #{template_id} for execution #{execution.id}"

    # Get the target (application, contract, etc.) and user
    target = execution.target
    user = case target
           when Application
             target.user
           when Contract
             target.application&.user
           else
             nil
           end

    return unless user&.email

    # Render the email content
    rendered_content = template.render_content({
      user: user,
      application: target.is_a?(Application) ? target : target.application,
      contract: target.is_a?(Contract) ? target : nil,
      target: target
    })

    # Use subject override if provided
    final_subject = subject_override || rendered_content[:subject]

    # Send the email directly using WorkflowMailer
    WorkflowMailer.send_workflow_email(
      to: user.email,
      subject: final_subject,
      body: rendered_content[:content]
    ).deliver_now

    Rails.logger.info "✅ Email sent successfully to #{user.email} with subject: #{final_subject}"
  end

  def process_delay_node(node, execution)
    config = node['config'] || {}
    duration = config['duration']&.to_i || 1
    unit = config['unit'] || 'days'

    delay_time = duration.send(unit)
    
    Rails.logger.info "Scheduling delayed execution in #{duration} #{unit} for execution #{execution.id}"

    # Schedule continuation of workflow after delay
    DelayedWorkflowContinuationJob.set(wait: delay_time).perform_later(
      execution.id,
      node['id'],
      workflow.workflow_builder_data
    )
  end

  def evaluate_condition(node)
    config = node['config'] || {}
    condition_type = config['condition_type']

    case condition_type
    when 'status_unchanged'
      original_status = context[:from_status] || context[:original_status]
      current_status = target.status.to_s
      original_status == current_status

    when 'user_attribute'
      attribute = config['attribute']
      operator = config['operator']
      value = config['value']
      
      return false unless attribute && operator && value

      target_value = target.send(attribute) if target.respond_to?(attribute)
      compare_values(target_value, operator, value)

    else
      true
    end
  rescue => e
    Rails.logger.error "Error evaluating condition: #{e.message}"
    false
  end

  def compare_values(target_value, operator, expected_value)
    case operator
    when 'equals'
      target_value.to_s == expected_value.to_s
    when 'not_equals'
      target_value.to_s != expected_value.to_s
    when 'contains'
      target_value.to_s.include?(expected_value.to_s)
    when 'greater_than'
      target_value.to_f > expected_value.to_f
    when 'less_than'
      target_value.to_f < expected_value.to_f
    else
      false
    end
  end

  def process_update_node(node, execution)
    config = node['config'] || {}
    update_type = config['update_type']

    case update_type
    when 'status_change'
      new_status = config['new_status']
      if new_status && target.respond_to?(:status=)
        Rails.logger.info "Updating #{target.class.name}##{target.id} status to #{new_status}"
        target.update!(status: new_status)
      end

    when 'attribute_update'
      attribute = config['attribute']
      value = config['value']
      
      if attribute && value && target.respond_to?("#{attribute}=")
        Rails.logger.info "Updating #{target.class.name}##{target.id} #{attribute} to #{value}"
        target.update!(attribute => value)
      end
    end
  rescue => e
    Rails.logger.error "Error processing update node: #{e.message}"
  end
end