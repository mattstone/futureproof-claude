# Email workflow automation. The legacy admin's four glue JS files (AJAX
# tabs, duplicate Stimulus tab controller, importmap entry) are replaced by
# server-rendered pages + one console--workflow-builder Stimulus controller
# for step add/remove/reorder in the form.
class Console::EmailWorkflowsController < Console::BaseController
  before_action -> { require_capability(:manage_product) }
  before_action :set_workflow, only: [ :show, :edit, :update, :toggle_active, :duplicate, :destroy, :cancel_execution ]
  before_action :load_email_templates, only: [ :new, :create, :edit, :update ]

  def index
    @workflows = EmailWorkflow.includes(:created_by, :workflow_steps).order(created_at: :desc)
    @workflows = @workflows.where(trigger_type: params[:trigger_type]) if params[:trigger_type].present?
    @workflows = @workflows.where(active: params[:active] == "true") if params[:active].present?

    @stats = {
      total: EmailWorkflow.count,
      active: EmailWorkflow.where(active: true).count,
      executions_30d: WorkflowExecution.where("created_at >= ?", 30.days.ago).count
    }
    @last_runs = WorkflowExecution.group(:workflow_id).maximum(:created_at)
  end

  def show
    @executions = @workflow.workflow_executions
                           .includes(:target, workflow_step_executions: :step)
                           .order(created_at: :desc)
                           .limit(50)
    all_executions = @workflow.workflow_executions
    finished = all_executions.finished.count
    completed = all_executions.where(status: "completed").count
    @execution_stats = {
      total: all_executions.count,
      active: all_executions.active.count,
      failed: all_executions.where(status: "failed").count,
      success_rate: finished.positive? ? (completed * 100.0 / finished).round : nil
    }
  end

  # Stop a runaway run — the workflow itself stays active for future triggers.
  def cancel_execution
    execution = @workflow.workflow_executions.find(params[:execution_id])
    if execution.respond_to?(:cancel!) && WorkflowExecution.active.exists?(execution.id)
      execution.cancel!
      AuditLog.log_action(user: current_user, action: "workflow_execution_cancelled", resource: @workflow,
                          reason: "Execution ##{execution.id} cancelled")
      redirect_to console_email_workflow_path(@workflow), notice: "Execution ##{execution.id} cancelled."
    else
      redirect_to console_email_workflow_path(@workflow), alert: "Only active executions can be cancelled."
    end
  end

  def templates
    @template_categories = WorkflowTemplateService.templates_by_category
  end

  def create_from_template
    workflow = WorkflowTemplateService.create_from_template(params[:template], current_user)

    if workflow
      redirect_to edit_console_email_workflow_path(workflow), notice: "Workflow created from template — review and activate it."
    else
      redirect_to templates_console_email_workflows_path, alert: "Failed to create workflow from template."
    end
  end

  def new
    @workflow = EmailWorkflow.new(trigger_type: params[:trigger_type])
    @workflow.workflow_steps.build(position: 0)
  end

  def create
    @workflow = EmailWorkflow.new(workflow_params)
    @workflow.created_by = current_user
    @workflow.trigger_conditions ||= {}

    if @workflow.save
      redirect_to console_email_workflow_path(@workflow), notice: "Workflow created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @workflow.update(workflow_params)
      redirect_to console_email_workflow_path(@workflow), notice: "Workflow updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_active
    @workflow.update!(active: !@workflow.active)
    redirect_to console_email_workflow_path(@workflow), notice: "Workflow #{@workflow.active? ? 'activated' : 'deactivated'}."
  end

  def duplicate
    new_workflow = @workflow.dup
    new_workflow.name = "#{@workflow.name} (Copy)"
    new_workflow.active = false
    new_workflow.created_by = current_user

    if new_workflow.save
      @workflow.workflow_steps.each do |step|
        new_step = step.dup
        new_step.workflow = new_workflow
        new_step.save!
      end
      redirect_to edit_console_email_workflow_path(new_workflow), notice: "Duplicated as '#{new_workflow.name}'."
    else
      redirect_to console_email_workflow_path(@workflow), alert: "Failed to duplicate workflow."
    end
  end

  def destroy
    if @workflow.workflow_executions.active.exists?
      redirect_to console_email_workflow_path(@workflow),
                  alert: "Cannot delete — executions are still running. Cancel them first." and return
    end

    @workflow.destroy
    redirect_to console_email_workflows_path, notice: "Workflow deleted."
  end

  private

  def set_workflow
    @workflow = EmailWorkflow.find(params[:id])
  end

  def load_email_templates
    @email_templates = EmailTemplate.order(:template_type, :name)
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
end
