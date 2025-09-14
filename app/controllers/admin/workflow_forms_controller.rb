class Admin::WorkflowFormsController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_workflow, only: [:show, :edit_trigger, :create_trigger, :update_trigger, :destroy_trigger]
  
  def index
    @workflows = BusinessProcessWorkflow.all.order(:process_type)
    @workflow_stats = calculate_workflow_stats
    
    # Export data for comparison
    export_workflow_data
  end
  
  def show
    @triggers = @workflow.triggers
    @trigger_stats = calculate_trigger_stats(@workflow)
    
    # Group triggers by complexity for better organization
    @simple_triggers = []
    @complex_triggers = []
    
    @triggers.each do |name, data|
      if has_conditions?(data)
        @complex_triggers << [name, data]
      else
        @simple_triggers << [name, data]
      end
    end
  end
  
  def new_trigger
    @workflow = BusinessProcessWorkflow.find(params[:id])
    @trigger = build_new_trigger
    @available_actions = available_actions
    @available_conditions = available_conditions
    @email_templates = EmailTemplate.order(:template_type, :name)
  end
  
  def create_trigger
    @trigger_data = build_trigger_from_params
    
    if valid_trigger?(@trigger_data)
      @workflow.add_trigger(params[:trigger_name], @trigger_data)
      
      flash[:success] = "Trigger '#{params[:trigger_name]}' created successfully"
      redirect_to admin_workflow_form_path(@workflow)
    else
      @trigger = build_new_trigger
      @available_actions = available_actions
      @available_conditions = available_conditions
      @email_templates = EmailTemplate.order(:template_type, :name)
      flash[:error] = "Please fix the errors below"
      render :new_trigger
    end
  end
  
  def edit_trigger
    @trigger_name = params[:trigger_name]
    @trigger_data = @workflow.trigger_data(@trigger_name)

    # Extract trigger information for editing
    trigger_node = @trigger_data['nodes']&.find { |n| n['type'] == 'trigger' }
    @trigger_event_type = trigger_node&.dig('config', 'event') || 'user_registered'
    @trigger_conditions = trigger_node&.dig('config', 'conditions') || {}
    @trigger_nodes = @trigger_data['nodes'] || []
    @trigger_connections = @trigger_data['connections'] || []

    @trigger = parse_trigger_for_editing(@trigger_data)
    @available_actions = available_actions
    @available_conditions = available_conditions
    @email_templates = EmailTemplate.order(:template_type, :name)
  end
  
  def update_trigger
    @trigger_data = build_trigger_from_params
    
    if valid_trigger?(@trigger_data)
      @workflow.add_trigger(params[:trigger_name], @trigger_data)
      
      flash[:success] = "Trigger '#{params[:trigger_name]}' updated successfully"
      redirect_to admin_workflow_form_path(@workflow)
    else
      @trigger_name = params[:trigger_name]
      @trigger = parse_trigger_for_editing(@trigger_data)
      @available_actions = available_actions
      @available_conditions = available_conditions
      @email_templates = EmailTemplate.order(:template_type, :name)
      flash[:error] = "Please fix the errors below"
      render :edit_trigger
    end
  end
  
  def destroy_trigger
    trigger_name = params[:trigger_name]
    
    if @workflow.trigger_exists?(trigger_name)
      @workflow.remove_trigger(trigger_name)
      flash[:success] = "Trigger '#{trigger_name}' removed successfully"
    else
      flash[:error] = "Trigger not found"
    end
    
    redirect_to admin_workflow_form_path(@workflow)
  end
  
  private

  def node_color_class(type)
    case type&.downcase
    when 'trigger'
      'admin-node-trigger'
    when 'email', 'send_email'
      'admin-node-email'
    when 'delay', 'wait'
      'admin-node-delay'
    when 'condition'
      'admin-node-condition'
    when 'webhook'
      'admin-node-webhook'
    else
      'admin-node-unknown'
    end
  end
  helper_method :node_color_class

  def node_type_color(type)
    case type&.downcase
    when 'trigger' then 'blue'
    when 'email', 'send_email' then 'green'
    when 'delay', 'wait' then 'yellow'
    when 'condition' then 'purple'
    when 'webhook' then 'orange'
    else 'gray'
    end
  end
  helper_method :node_type_color

  def get_branch_nodes(trigger_data, condition_node_id, branch_type)
    return [] unless trigger_data['connections']

    # Find connections from condition node with specified branch type
    branch_connections = trigger_data['connections'].select do |conn|
      conn['from'] == condition_node_id && conn['type'] == branch_type
    end

    # Get the nodes for these connections
    branch_node_ids = branch_connections.map { |conn| conn['to'] }
    trigger_data['nodes'].select { |node| branch_node_ids.include?(node['id']) }
  end
  helper_method :get_branch_nodes

  def available_actions
    {
      'email' => 'Send Email',
      'delay' => 'Add Delay',
      'webhook' => 'Call Webhook',
      'update_user' => 'Update User Data'
    }
  end
  helper_method :available_actions

  def action_description(action_key)
    descriptions = {
      'email' => 'Send an automated email using a template',
      'delay' => 'Wait a specified amount of time before next action',
      'webhook' => 'Send data to an external service via HTTP',
      'update_user' => 'Modify user profile or status information'
    }
    descriptions[action_key] || 'Custom action'
  end
  helper_method :action_description

  def available_conditions
    {
      'user_status' => 'User Status',
      'user_type' => 'User Type',
      'application_status' => 'Application Status',
      'contract_status' => 'Contract Status'
    }
  end
  helper_method :available_conditions

  def set_workflow
    @workflow = BusinessProcessWorkflow.find(params[:id])
  end
  
  def calculate_workflow_stats
    {
      total_workflows: BusinessProcessWorkflow.count,
      active_workflows: BusinessProcessWorkflow.active.count,
      total_triggers: BusinessProcessWorkflow.sum { |w| w.triggers.count },
      by_process_type: BusinessProcessWorkflow.group(:process_type).count
    }
  end
  
  def calculate_trigger_stats(workflow)
    triggers = workflow.triggers
    {
      total: triggers.count,
      simple: triggers.count { |_, data| !has_conditions?(data) },
      complex: triggers.count { |_, data| has_conditions?(data) },
      total_steps: triggers.sum { |_, data| (data['nodes'] || []).count }
    }
  end
  
  def has_conditions?(trigger_data)
    return false unless trigger_data['nodes']
    trigger_data['nodes'].any? { |node| node['type'] == 'condition' }
  end
  helper_method :has_conditions?
  
  def build_new_trigger
    {
      name: '',
      event_type: '',
      conditions: {},
      steps: [{ type: 'email', config: {} }],
      conditional_steps: []
    }
  end
  
  def build_trigger_from_params
    nodes = []
    connections = []
    node_counter = 1
    
    # Build trigger node
    trigger_node = {
      'id' => "trigger_#{node_counter}",
      'type' => 'trigger',
      'config' => {
        'event' => params[:event_type],
        'conditions' => parse_conditions(params[:conditions])
      },
      'position' => { 'x' => 100, 'y' => 100 }
    }
    nodes << trigger_node
    last_node_id = trigger_node['id']
    node_counter += 1
    
    # Build main flow steps
    if params[:steps].present?
      params[:steps].each do |step_params|
        next if step_params[:type].blank?
        
        node_id = "step_#{node_counter}"
        node = {
          'id' => node_id,
          'type' => step_params[:type],
          'config' => parse_step_config(step_params),
          'position' => { 'x' => 100, 'y' => 100 + (node_counter * 140) }
        }
        nodes << node
        
        # Connect to previous node
        connections << {
          'from' => last_node_id,
          'to' => node_id,
          'type' => 'next'
        }
        
        last_node_id = node_id
        node_counter += 1
      end
    end
    
    # Build conditional branches
    if params[:conditional_steps].present?
      params[:conditional_steps].each_with_index do |condition_params, index|
        next if condition_params[:condition_type].blank?
        
        # Create condition node
        condition_node_id = "condition_#{node_counter}"
        condition_node = {
          'id' => condition_node_id,
          'type' => 'condition',
          'config' => {
            'condition_type' => condition_params[:condition_type],
            'condition_value' => condition_params[:condition_value]
          },
          'position' => { 'x' => 100, 'y' => 100 + (node_counter * 140) }
        }
        nodes << condition_node
        
        # Connect to main flow
        connections << {
          'from' => last_node_id,
          'to' => condition_node_id,
          'type' => 'next'
        }
        
        node_counter += 1
        
        # Create YES branch
        if condition_params[:yes_steps].present?
          condition_params[:yes_steps].each do |yes_step|
            next if yes_step[:type].blank?
            
            yes_node_id = "yes_#{node_counter}"
            yes_node = {
              'id' => yes_node_id,
              'type' => yes_step[:type],
              'config' => parse_step_config(yes_step),
              'position' => { 'x' => 50, 'y' => 100 + (node_counter * 140) }
            }
            nodes << yes_node
            
            connections << {
              'from' => condition_node_id,
              'to' => yes_node_id,
              'type' => 'yes'
            }
            
            node_counter += 1
          end
        end
        
        # Create NO branch
        if condition_params[:no_steps].present?
          condition_params[:no_steps].each do |no_step|
            next if no_step[:type].blank?
            
            no_node_id = "no_#{node_counter}"
            no_node = {
              'id' => no_node_id,
              'type' => no_step[:type],
              'config' => parse_step_config(no_step),
              'position' => { 'x' => 150, 'y' => 100 + (node_counter * 140) }
            }
            nodes << no_node
            
            connections << {
              'from' => condition_node_id,
              'to' => no_node_id,
              'type' => 'no'
            }
            
            node_counter += 1
          end
        end
        
        last_node_id = condition_node_id
      end
    end
    
    {
      'nodes' => nodes,
      'connections' => connections,
      'created_via' => 'form_builder',
      'created_at' => Time.current.iso8601
    }
  end
  
  def parse_conditions(conditions_param)
    return {} unless conditions_param.present?
    
    # Handle different condition formats
    case conditions_param
    when Hash
      conditions_param
    when String
      begin
        JSON.parse(conditions_param)
      rescue
        { 'raw_condition' => conditions_param }
      end
    else
      {}
    end
  end
  
  def parse_step_config(step_params)
    config = {}
    
    case step_params[:type]
    when 'email'
      config.merge!({
        'email_template_id' => step_params[:email_template_id],
        'subject' => step_params[:subject],
        'from_email' => step_params[:from_email],
        'from_name' => step_params[:from_name]
      }.compact)
    when 'delay'
      config.merge!({
        'duration' => step_params[:duration],
        'unit' => step_params[:unit]
      }.compact)
    when 'webhook'
      config.merge!({
        'url' => step_params[:url],
        'method' => step_params[:method] || 'POST',
        'headers' => parse_conditions(step_params[:headers])
      }.compact)
    when 'update_user'
      config.merge!({
        'field' => step_params[:field],
        'value' => step_params[:value]
      }.compact)
    end
    
    config
  end
  
  def parse_trigger_for_editing(trigger_data)
    return build_new_trigger unless trigger_data['nodes']
    
    trigger_node = trigger_data['nodes'].find { |n| n['type'] == 'trigger' }
    email_nodes = trigger_data['nodes'].select { |n| n['type'] == 'email' || n['type'] == 'send_email' }
    condition_nodes = trigger_data['nodes'].select { |n| n['type'] == 'condition' }
    
    {
      name: '',
      event_type: trigger_node&.dig('config', 'event') || '',
      conditions: trigger_node&.dig('config', 'conditions') || {},
      steps: email_nodes.map { |node| parse_node_for_editing(node) },
      conditional_steps: condition_nodes.map { |node| parse_condition_for_editing(node, trigger_data) }
    }
  end
  
  def parse_node_for_editing(node)
    config = node['config'] || {}
    {
      type: node['type'],
      email_template_id: config['email_template_id'],
      subject: config['subject'],
      from_email: config['from_email'],
      from_name: config['from_name'],
      duration: config['duration'],
      unit: config['unit'],
      url: config['url'],
      method: config['method'],
      field: config['field'],
      value: config['value']
    }
  end
  
  def parse_condition_for_editing(condition_node, trigger_data)
    connections = trigger_data['connections'] || []
    
    # Find YES and NO branches
    yes_connections = connections.select { |c| c['from'] == condition_node['id'] && c['type'] == 'yes' }
    no_connections = connections.select { |c| c['from'] == condition_node['id'] && c['type'] == 'no' }
    
    yes_nodes = yes_connections.map { |c| trigger_data['nodes'].find { |n| n['id'] == c['to'] } }.compact
    no_nodes = no_connections.map { |c| trigger_data['nodes'].find { |n| n['id'] == c['to'] } }.compact
    
    {
      condition_type: condition_node.dig('config', 'condition_type'),
      condition_value: condition_node.dig('config', 'condition_value'),
      yes_steps: yes_nodes.map { |node| parse_node_for_editing(node) },
      no_steps: no_nodes.map { |node| parse_node_for_editing(node) }
    }
  end
  
  def valid_trigger?(trigger_data)
    trigger_data.is_a?(Hash) && 
    trigger_data['nodes'].is_a?(Array) && 
    trigger_data['connections'].is_a?(Array) &&
    trigger_data['nodes'].any?
  end
  
  def available_actions
    {
      'email' => 'Send Email',
      'delay' => 'Wait/Delay',
      'webhook' => 'Call Webhook',
      'update_user' => 'Update User Data',
      'tag_user' => 'Add/Remove Tags'
    }
  end
  
  def available_conditions
    {
      'user_status' => 'User Status',
      'user_type' => 'User Type',
      'application_status' => 'Application Status',
      'days_since_registration' => 'Days Since Registration',
      'has_completed_action' => 'Has Completed Action',
      'custom_field' => 'Custom Field Value'
    }
  end
  
  def export_workflow_data
    data = {
      timestamp: Time.current,
      system_comparison: {
        visual_system: {
          complexity: 'High - requires JavaScript, SVG, drag & drop',
          user_experience: 'Complex - learning curve for business users',
          maintenance: 'High - many moving parts, positioning bugs',
          flexibility: 'High - unlimited node arrangements',
          reliability: 'Medium - prone to UI bugs and browser issues'
        },
        form_system: {
          complexity: 'Low - standard Rails forms',
          user_experience: 'Simple - familiar form interface',
          maintenance: 'Low - standard form validation and processing',
          flexibility: 'High - supports complex conditions via structured forms',
          reliability: 'High - standard Rails patterns'
        }
      },
      current_data: {
        total_workflows: @workflow_stats[:total_workflows],
        total_triggers: @workflow_stats[:total_triggers],
        workflows_by_type: @workflow_stats[:by_process_type]
      }
    }
    
    File.write('tmp/workflow_system_comparison.json', JSON.pretty_generate(data))
  end
end