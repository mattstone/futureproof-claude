class ConvertEmailWorkflowsToBusinessProcessWorkflows < ActiveRecord::Migration[8.0]
  def up
    # Ensure the 3 default workflows exist
    BusinessProcessWorkflow.ensure_default_workflows!
    
    # Convert existing EmailWorkflows to BusinessProcessWorkflow triggers
    EmailWorkflow.where(active: true).find_each do |email_workflow|
      begin
        # Determine which business process this workflow belongs to
        process_type = determine_process_type(email_workflow.trigger_type)
        business_workflow = BusinessProcessWorkflow.find_by(process_type: process_type)
        
        # Create trigger name based on email workflow
        trigger_name = generate_trigger_name(email_workflow)
        
        # Skip if trigger already exists
        next if business_workflow.trigger_exists?(trigger_name)
        
        # Convert workflow data
        if email_workflow.workflow_builder_data.present?
          # New format - already has nodes and connections
          trigger_data = email_workflow.workflow_builder_data.dup
        else
          # Old format - convert from workflow_steps
          trigger_data = convert_from_workflow_steps(email_workflow)
        end
        
        # Add metadata
        trigger_data['source'] = {
          'email_workflow_id' => email_workflow.id,
          'name' => email_workflow.name,
          'description' => email_workflow.description,
          'trigger_conditions' => email_workflow.trigger_conditions
        }
        
        # Add trigger to business workflow
        business_workflow.add_trigger(trigger_name, trigger_data)
        
        puts "Converted: #{email_workflow.name} -> #{process_type}/#{trigger_name}"
        
      rescue => e
        puts "Error converting workflow #{email_workflow.id}: #{e.message}"
      end
    end
  end
  
  def down
    # Remove converted triggers (keep the business process workflows)
    BusinessProcessWorkflow.all.each do |workflow|
      triggers_to_remove = []
      workflow.triggers.each do |trigger_name, trigger_data|
        if trigger_data['source']&.key?('email_workflow_id')
          triggers_to_remove << trigger_name
        end
      end
      
      triggers_to_remove.each do |trigger_name|
        workflow.remove_trigger(trigger_name)
      end
    end
  end
  
  private
  
  def determine_process_type(trigger_type)
    case trigger_type&.downcase
    when 'user_registered', 'user_registration', 'email_verification', 'welcome'
      'acquisition'
    when 'application_created', 'application_submitted', 'application_abandoned', 'application_status_changed', 'application_stuck_at_status'
      'conversion'
    else
      'standard_operations'
    end
  end
  
  def generate_trigger_name(email_workflow)
    # Create a URL-friendly trigger name
    base_name = email_workflow.name.downcase
      .gsub(/[^a-z0-9\s]/, '')
      .gsub(/\s+/, '_')
      .gsub(/_{2,}/, '_')
      .gsub(/^_|_$/, '')
    
    # Add trigger type if it exists
    if email_workflow.trigger_type.present?
      "#{email_workflow.trigger_type}_#{base_name}"
    else
      base_name
    end
  end
  
  def convert_from_workflow_steps(email_workflow)
    nodes = []
    connections = []
    
    # Create trigger node
    trigger_config = {
      'event' => email_workflow.trigger_type,
      'conditions' => email_workflow.trigger_conditions || {}
    }
    
    nodes << {
      'id' => 'trigger_1',
      'type' => 'trigger',
      'config' => trigger_config,
      'position' => { 'x' => 100, 'y' => 100 }
    }
    
    # Convert workflow steps to nodes
    email_workflow.workflow_steps.order(:position).each_with_index do |step, index|
      node_id = "node_#{index + 2}"
      
      nodes << {
        'id' => node_id,
        'type' => step.step_type || 'action',
        'config' => step.configuration || {},
        'position' => { 'x' => 100, 'y' => 200 + (index * 140) }
      }
      
      # Create connection from previous node
      from_id = index == 0 ? 'trigger_1' : "node_#{index + 1}"
      connections << {
        'from' => from_id,
        'to' => node_id,
        'type' => 'next'
      }
    end
    
    {
      'nodes' => nodes,
      'connections' => connections
    }
  end
end
