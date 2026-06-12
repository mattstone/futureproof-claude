# Email workflow automation. The legacy admin's four glue JS files (AJAX
# tabs, duplicate Stimulus tab controller, importmap entry) are replaced by
# server-rendered pages + one console--workflow-builder Stimulus controller
# for step add/remove/reorder in the form.
class Console::EmailWorkflowsController < Console::BaseController
  before_action -> { require_capability(:manage_product) }
  before_action :set_workflow, only: [ :show, :edit, :update, :toggle_active, :duplicate ]
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
  end

  def show
    @executions = @workflow.workflow_executions
                           .includes(:target, :workflow_step_executions)
                           .order(created_at: :desc)
                           .limit(50)
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
