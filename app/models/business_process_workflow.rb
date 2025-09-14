class BusinessProcessWorkflow < ApplicationRecord
  # Process types for the 3 main business workflows
  enum :process_type, {
    acquisition: 'acquisition',
    conversion: 'conversion',
    standard_operations: 'standard_operations'
  }
  
  # Validations
  validates :process_type, presence: true, uniqueness: true
  validates :name, presence: true
  validates :workflow_data, presence: true
  validates :active, inclusion: { in: [true, false] }
  
  # JSON structure validation
  validate :validate_workflow_data_structure
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  
  # Class methods
  def self.ensure_default_workflows!
    # Create the 3 required workflows if they don't exist
    create_workflow_if_missing('acquisition', 'Customer Acquisition', 'Workflows for acquiring new customers')
    create_workflow_if_missing('conversion', 'Customer Conversion', 'Workflows for converting prospects to customers')
    create_workflow_if_missing('standard_operations', 'Standard Operations', 'Workflows for ongoing customer management')
  end
  
  def self.create_workflow_if_missing(process_type, name, description)
    return if exists?(process_type: process_type)
    
    create!(
      process_type: process_type,
      name: name,
      description: description,
      workflow_data: { triggers: {} },
      active: true
    )
  end
  
  # Instance methods
  def triggers
    workflow_data['triggers'] || {}
  end
  
  def add_trigger(trigger_name, trigger_data = {})
    new_data = workflow_data.deep_dup
    new_data['triggers'] ||= {}
    new_data['triggers'][trigger_name] = {
      'nodes' => trigger_data['nodes'] || [],
      'connections' => trigger_data['connections'] || []
    }.merge(trigger_data)
    update!(workflow_data: new_data)
  end
  
  def remove_trigger(trigger_name)
    new_data = workflow_data.deep_dup
    new_data['triggers']&.delete(trigger_name)
    update!(workflow_data: new_data)
  end
  
  def trigger_exists?(trigger_name)
    triggers.key?(trigger_name)
  end
  
  def trigger_data(trigger_name)
    triggers[trigger_name] || {}
  end
  
  # Convert existing EmailWorkflow to new format
  def self.convert_from_email_workflow(email_workflow)
    process_type = determine_process_type_from_email_workflow(email_workflow)
    
    workflow = find_or_initialize_by(process_type: process_type)
    workflow.name ||= "#{process_type.humanize} Workflows"
    workflow.description ||= "Converted from email workflow: #{email_workflow.name}"
    
    trigger_name = email_workflow.trigger_type || 'converted_trigger'
    trigger_data = convert_email_workflow_to_trigger_format(email_workflow)
    
    workflow.add_trigger(trigger_name, trigger_data)
    workflow
  end
  
  private
  
  def validate_workflow_data_structure
    return unless workflow_data.is_a?(Hash)
    
    # Ensure triggers is a hash
    triggers = workflow_data['triggers']
    unless triggers.is_a?(Hash)
      errors.add(:workflow_data, 'triggers must be a hash')
      return
    end
    
    # Validate each trigger structure
    triggers.each do |trigger_name, trigger_data|
      unless trigger_data.is_a?(Hash)
        errors.add(:workflow_data, "trigger '#{trigger_name}' must be a hash")
        next
      end
      
      # Ensure nodes and connections exist
      unless trigger_data['nodes'].is_a?(Array)
        errors.add(:workflow_data, "trigger '#{trigger_name}' must have nodes array")
      end
      
      unless trigger_data['connections'].is_a?(Array)
        errors.add(:workflow_data, "trigger '#{trigger_name}' must have connections array")
      end
    end
  end
  
  def self.determine_process_type_from_email_workflow(email_workflow)
    case email_workflow.trigger_type&.downcase
    when 'user_registration', 'email_verification', 'welcome'
      'acquisition'
    when 'application_started', 'application_submitted', 'application_abandoned'
      'conversion'
    else
      'standard_operations'
    end
  end
  
  def self.convert_email_workflow_to_trigger_format(email_workflow)
    nodes = []
    connections = []
    
    # Create trigger node
    nodes << {
      id: 'trigger_1',
      type: 'trigger',
      config: { event: email_workflow.trigger_type },
      position: { x: 100, y: 100 }
    }
    
    # Convert workflow steps to nodes
    email_workflow.workflow_steps.order(:position).each_with_index do |step, index|
      node_id = "node_#{index + 2}"
      
      nodes << {
        id: node_id,
        type: step.step_type,
        config: step.configuration || {},
        position: { x: 100, y: 200 + (index * 140) }
      }
      
      # Create connection from previous node
      from_id = index == 0 ? 'trigger_1' : "node_#{index + 1}"
      connections << {
        from: from_id,
        to: node_id,
        type: 'next'
      }
    end
    
    {
      'nodes' => nodes,
      'connections' => connections
    }
  end
end
