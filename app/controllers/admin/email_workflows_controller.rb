class Admin::EmailWorkflowsController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_workflow, only: [:show, :edit, :update, :destroy, :toggle_active, :preview, :duplicate]
  
  def index
    @workflows = EmailWorkflow.includes(:created_by, :workflow_steps)
                              .order(created_at: :desc)
    
    # Filter by trigger type if specified
    @workflows = @workflows.where(trigger_type: params[:trigger_type]) if params[:trigger_type].present?
    
    # Filter by status if specified  
    @workflows = @workflows.where(active: params[:active] == 'true') if params[:active].present?
    
    @trigger_types = EmailWorkflow.trigger_types.keys
    @workflow_stats = calculate_workflow_stats
    
    # Load email templates for the templates tab
    @email_templates = EmailTemplate.order(:template_type, :name) if request.xhr?
  end
  
  def show
    @executions = @workflow.workflow_executions
                           .includes(:target, :workflow_step_executions)
                           .order(created_at: :desc)
                           .limit(50)
    @execution_stats = calculate_execution_stats
  end
  
  def new
    if params[:template].present?
      # Create from template
      template_workflow = WorkflowTemplateService.create_from_template(params[:template], current_admin_user)
      if template_workflow
        flash[:success] = "Workflow created from template: #{params[:template]}"
        redirect_to edit_admin_email_workflow_path(template_workflow)
        return
      else
        flash[:error] = "Failed to create workflow from template"
      end
    end
    
    @workflow = EmailWorkflow.new
    @workflow.workflow_steps.build # Start with one empty step
    @email_templates = EmailTemplate.order(:template_type, :name)
  end
  
  def templates
    @template_categories = WorkflowTemplateService.templates_by_category
    @customer_lifecycle = WorkflowTemplateService.customer_lifecycle_flow
  end
  
  def create
    @workflow = EmailWorkflow.new(workflow_params)
    @workflow.created_by = current_admin_user
    
    if @workflow.save
      flash[:success] = "Email workflow '#{@workflow.name}' has been created successfully."
      redirect_to admin_email_workflow_path(@workflow)
    else
      @email_templates = EmailTemplate.order(:template_type, :name)
      render :new
    end
  end
  
  def edit
    @email_templates = EmailTemplate.order(:template_type, :name)
  end
  
  def update
    if @workflow.update(workflow_params)
      flash[:success] = "Email workflow '#{@workflow.name}' has been updated successfully."
      redirect_to admin_email_workflow_path(@workflow)
    else
      @email_templates = EmailTemplate.order(:template_type, :name)
      render :edit
    end
  end
  
  def destroy
    workflow_name = @workflow.name
    
    # Check for active executions
    if @workflow.workflow_executions.active.exists?
      flash[:error] = "Cannot delete workflow '#{workflow_name}' because it has active executions. Please wait for them to complete or cancel them first."
      redirect_to admin_email_workflow_path(@workflow)
      return
    end
    
    @workflow.destroy
    flash[:success] = "Email workflow '#{workflow_name}' has been deleted."
    redirect_to admin_email_workflows_path
  end
  
  def toggle_active
    @workflow.update!(active: !@workflow.active)
    status = @workflow.active? ? 'activated' : 'deactivated'
    flash[:success] = "Email workflow '#{@workflow.name}' has been #{status}."
    redirect_back(fallback_location: admin_email_workflows_path)
  end
  
  def preview
    # Show a preview of how the workflow will execute
    @sample_data = generate_sample_data_for_trigger(@workflow.trigger_type)
    @preview_steps = @workflow.workflow_steps.ordered.includes(:workflow_step_executions)
  end
  
  def duplicate
    new_workflow = @workflow.dup
    new_workflow.name = "#{@workflow.name} (Copy)"
    new_workflow.active = false
    new_workflow.created_by = current_admin_user
    
    if new_workflow.save
      # Duplicate workflow steps
      @workflow.workflow_steps.each do |step|
        new_step = step.dup
        new_step.workflow = new_workflow
        new_step.save!
      end
      
      flash[:success] = "Workflow duplicated as '#{new_workflow.name}'"
      redirect_to edit_admin_email_workflow_path(new_workflow)
    else
      flash[:error] = "Failed to duplicate workflow: #{new_workflow.errors.full_messages.join(', ')}"
      redirect_to admin_email_workflow_path(@workflow)
    end
  end
  
  # AJAX endpoint for adding workflow steps
  def add_step
    @step = WorkflowStep.new
    @step_index = params[:step_index].to_i
    @email_templates = EmailTemplate.order(:template_type, :name)
    
    respond_to do |format|
      format.js { render 'admin/email_workflows/add_step' }
    end
  end
  
  private
  
  def set_workflow
    @workflow = EmailWorkflow.find(params[:id])
  end
  
  def workflow_params
    params.require(:email_workflow).permit(
      :name, :description, :trigger_type, :active,
      trigger_conditions: {},
      workflow_steps_attributes: [
        :id, :step_type, :position, :name, :description, :_destroy,
        configuration: {}
      ]
    )
  end
  
  def calculate_workflow_stats
    {
      total: EmailWorkflow.count,
      active: EmailWorkflow.active.count,
      inactive: EmailWorkflow.where(active: false).count,
      by_trigger: EmailWorkflow.group(:trigger_type).count
    }
  end
  
  def calculate_execution_stats
    executions = @workflow.workflow_executions
    {
      total: executions.count,
      completed: executions.where(status: 'completed').count,
      failed: executions.where(status: 'failed').count,
      running: executions.where(status: 'running').count,
      pending: executions.where(status: 'pending').count,
      success_rate: calculate_success_rate(executions)
    }
  end
  
  def calculate_success_rate(executions)
    total = executions.finished.count
    return 0 if total.zero?
    ((executions.where(status: 'completed').count.to_f / total) * 100).round(1)
  end
  
  def generate_sample_data_for_trigger(trigger_type)
    case trigger_type
    when 'application_created'
      {
        user: {
          first_name: 'John',
          last_name: 'Doe',
          email: 'john@example.com'
        },
        application: {
          home_value: 500000,
          status: 'created',
          address: '123 Sample Street, Sample City'
        }
      }
    when 'application_status_changed'
      {
        user: {
          first_name: 'Jane',
          last_name: 'Smith', 
          email: 'jane@example.com'
        },
        application: {
          home_value: 750000,
          status: 'submitted',
          previous_status: 'created',
          address: '456 Sample Avenue, Sample City'
        }
      }
    when 'user_registered'
      {
        user: {
          first_name: 'Mike',
          last_name: 'Johnson',
          email: 'mike@example.com',
          country_of_residence: 'Australia'
        }
      }
    else
      { user: { first_name: 'Sample', last_name: 'User', email: 'sample@example.com' } }
    end
  end
end