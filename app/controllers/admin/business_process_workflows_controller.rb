class Admin::BusinessProcessWorkflowsController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :check_v2_access
  before_action :set_workflow, only: [:show, :edit, :update, :destroy, :add_trigger, :remove_trigger, :edit_trigger]
  
  def index
    @workflows = BusinessProcessWorkflow.all.order(:process_type)
    @workflow_stats = calculate_workflow_stats
    
    # Show workflow system version switch for admins
    @can_switch_version = current_user.admin?
    @current_version = WorkflowSystem::VERSION
  end
  
  def show
    @triggers = @workflow.triggers
    @selected_trigger = params[:trigger] || @triggers.keys.first
    @trigger_data = @selected_trigger ? @workflow.trigger_data(@selected_trigger) : {}
  end
  
  def edit
    @selected_trigger = params[:trigger] || @workflow.triggers.keys.first
    @trigger_data = @selected_trigger ? @workflow.trigger_data(@selected_trigger) : {}
    @available_node_types = available_node_types
    @email_templates = EmailTemplate.order(:template_type, :name)
  end
  
  def update
    if @workflow.update(workflow_params)
      flash[:success] = "Workflow updated successfully"
      redirect_to admin_business_process_workflow_path(@workflow)
    else
      flash[:error] = "Failed to update workflow"
      render :edit
    end
  end
  
  def add_trigger
    trigger_name = params[:trigger_name]
    
    if trigger_name.blank?
      flash[:error] = "Trigger name cannot be blank"
      redirect_back(fallback_location: admin_business_process_workflow_path(@workflow))
      return
    end
    
    if @workflow.trigger_exists?(trigger_name)
      flash[:error] = "Trigger '#{trigger_name}' already exists"
      redirect_back(fallback_location: admin_business_process_workflow_path(@workflow))
      return
    end
    
    # Create basic trigger structure
    trigger_data = {
      'nodes' => [
        {
          'id' => 'trigger_1',
          'type' => 'trigger',
          'config' => { 'event' => params[:trigger_event] || 'custom_event' },
          'position' => { 'x' => 100, 'y' => 100 }
        }
      ],
      'connections' => []
    }
    
    @workflow.add_trigger(trigger_name, trigger_data)
    flash[:success] = "Trigger '#{trigger_name}' added successfully"
    redirect_to edit_admin_business_process_workflow_path(@workflow, trigger: trigger_name)
  end
  
  def remove_trigger
    trigger_name = params[:trigger_name]
    
    if @workflow.trigger_exists?(trigger_name)
      @workflow.remove_trigger(trigger_name)
      flash[:success] = "Trigger '#{trigger_name}' removed successfully"
    else
      flash[:error] = "Trigger '#{trigger_name}' not found"
    end
    
    redirect_to admin_business_process_workflow_path(@workflow)
  end
  
  def update_trigger
    trigger_name = params[:trigger_name]
    trigger_data = JSON.parse(params[:trigger_data])
    
    # Validate the trigger data structure
    unless trigger_data.is_a?(Hash) && trigger_data['nodes'].is_a?(Array) && trigger_data['connections'].is_a?(Array)
      render json: { error: 'Invalid trigger data structure' }, status: 422
      return
    end
    
    @workflow.add_trigger(trigger_name, trigger_data)
    render json: { success: true, message: 'Trigger updated successfully' }
  rescue JSON::ParserError
    render json: { error: 'Invalid JSON format' }, status: 422
  rescue => e
    render json: { error: e.message }, status: 422
  end
  
  private
  
  def set_workflow
    @workflow = BusinessProcessWorkflow.find(params[:id])
  end
  
  def workflow_params
    params.require(:business_process_workflow).permit(:name, :description, :active)
  end
  
  def check_v2_access
    unless WorkflowSystem.use_v2_for_user?(current_user, params)
      flash[:error] = "Access to new workflow system not available. Contact administrator."
      redirect_to admin_email_workflows_path
    end
  end
  
  def calculate_workflow_stats
    {
      total_workflows: BusinessProcessWorkflow.count,
      active_workflows: BusinessProcessWorkflow.active.count,
      total_triggers: BusinessProcessWorkflow.sum { |w| w.triggers.count },
      by_process_type: BusinessProcessWorkflow.group(:process_type).count
    }
  end
  
  def available_node_types
    {
      'trigger' => 'Trigger Event',
      'email' => 'Send Email',
      'delay' => 'Wait/Delay',
      'condition' => 'Conditional Branch',
      'webhook' => 'Call Webhook',
      'update_user' => 'Update User Data',
      'tag_user' => 'Add/Remove Tags'
    }
  end
end