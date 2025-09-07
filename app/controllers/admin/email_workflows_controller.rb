class Admin::EmailWorkflowsController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_workflow, only: [:show, :edit, :update, :destroy, :toggle_active, :preview, :duplicate, :trigger_conditions]
  
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
    
    # Handle Turbo frame requests for filtering
    if turbo_frame_request?
      render partial: 'workflows_content', locals: { workflows: @workflows, workflow_stats: @workflow_stats }
    end
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
      template_workflow = WorkflowTemplateService.create_from_template(params[:template], current_user)
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
  
  def email_templates_content
    @email_templates = EmailTemplate.order(:template_type, :name).page(params[:page]).per(10)
    render partial: 'templates_content', layout: false
  end
  
  def bulk_create
    # Handle bulk template creation
    if params[:create_all_templates] == 'true'
      handle_bulk_template_creation('all')
    elsif params[:create_category_templates].present?
      handle_bulk_template_creation(params[:create_category_templates])
    else
      flash[:alert] = "Invalid bulk creation request"
      redirect_to admin_email_workflows_path
    end
  end
  
  def create
    @workflow = EmailWorkflow.new(workflow_params)
    @workflow.created_by = current_user
    
    if @workflow.save
      flash[:success] = "Workflow '#{@workflow.name}' has been created successfully."
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
      flash[:success] = "Workflow '#{@workflow.name}' has been updated successfully."
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
    flash[:success] = "Workflow '#{workflow_name}' has been deleted."
    redirect_to admin_email_workflows_path
  end
  
  def toggle_active
    @workflow.update!(active: !@workflow.active)
    status = @workflow.active? ? 'activated' : 'deactivated'
    flash[:success] = "Workflow '#{@workflow.name}' has been #{status}."
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
    new_workflow.created_by = current_user
    
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
  
  def trigger_conditions
    # Handle both existing workflows and new workflow creation
    if @workflow.nil?
      # This is for new workflow creation
      @workflow = EmailWorkflow.new
      @workflow.trigger_type = params[:trigger_type]
    else
      # Update the trigger type for existing workflow if provided
      @workflow.trigger_type = params[:trigger_type] if params[:trigger_type].present?
    end
    
    render partial: 'trigger_conditions', locals: { form: nil, workflow: @workflow }, layout: false
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
    @workflow = EmailWorkflow.find(params[:id]) if params[:id].present? && params[:id] != 'new'
  end
  
  def handle_bulk_template_creation(category_type)
    created_workflows = []
    failed_workflows = []
    
    templates_to_create = case category_type
                         when 'all'
                           WorkflowTemplateService.available_templates
                         when 'onboarding'
                           WorkflowTemplateService.onboarding_templates
                         when 'operational'
                           WorkflowTemplateService.operational_templates
                         when 'end_of_contract'
                           WorkflowTemplateService.end_of_contract_templates
                         else
                           []
                         end
    
    if templates_to_create.empty?
      flash[:alert] = "No templates found for category: #{category_type}"
      redirect_to admin_email_workflows_path
      return
    end

    Rails.logger.info "Creating #{templates_to_create.count} workflow templates for category: #{category_type}"
    
    # Use transaction to ensure data integrity
    ActiveRecord::Base.transaction do
      templates_to_create.each do |template_data|
        begin
          # Check if workflow with this name already exists
          existing_workflow = EmailWorkflow.find_by(name: template_data[:name])
          if existing_workflow
            failed_workflows << { name: template_data[:name], error: "Workflow already exists" }
            next
          end
          
          # Create workflow from template
          workflow = WorkflowTemplateService.create_from_template(template_data[:name], current_user)
          if workflow && workflow.persisted?
            created_workflows << workflow
            Rails.logger.info "Successfully created workflow: #{workflow.name}"
          else
            error_message = workflow&.errors&.full_messages&.join(', ') || "Unknown error"
            failed_workflows << { name: template_data[:name], error: error_message }
            Rails.logger.error "Failed to create workflow '#{template_data[:name]}': #{error_message}"
          end
          
        rescue => e
          Rails.logger.error "Exception creating workflow from template '#{template_data[:name]}': #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          failed_workflows << { name: template_data[:name], error: e.message }
        end
      end
      
      # If too many failures, rollback the transaction
      if failed_workflows.count > templates_to_create.count / 2
        Rails.logger.error "Too many failures (#{failed_workflows.count}/#{templates_to_create.count}), rolling back transaction"
        raise ActiveRecord::Rollback
      end
    end
    
    # Prepare flash messages
    if created_workflows.any?
      success_message = "Successfully created #{created_workflows.count} workflow template(s)"
      if created_workflows.count <= 5
        success_message += ": #{created_workflows.map(&:name).join(', ')}"
      end
      flash[:success] = success_message
      Rails.logger.info "Bulk creation completed: #{created_workflows.count} workflows created"
    end
    
    if failed_workflows.any?
      if failed_workflows.count <= 3
        error_details = failed_workflows.map { |f| "#{f[:name]} (#{f[:error]})" }.join(', ')
        flash[:alert] = "Failed to create #{failed_workflows.count} workflow(s): #{error_details}"
      else
        flash[:alert] = "Failed to create #{failed_workflows.count} workflow templates. Check logs for details."
      end
      Rails.logger.error "Bulk creation failures: #{failed_workflows.count} workflows failed"
    end
    
    if created_workflows.empty? && failed_workflows.any?
      flash[:alert] = "No workflows were created. Please check the error messages and try again."
    end
    
    # Redirect back to workflows index
    redirect_to admin_email_workflows_path
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