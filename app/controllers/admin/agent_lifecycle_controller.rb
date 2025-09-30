# Controller for managing agent lifecycle stages visually
class Admin::AgentLifecycleController < Admin::BaseController
  before_action :ensure_futureproof_admin
  before_action :set_agent, only: [:show, :edit, :update, :add_stage, :edit_stage, :update_stage, :delete_stage]

  def index
    @agents = AiAgent.active.order(:name)
    @agent_stats = calculate_agent_stats
  end

  def show
    @lifecycle_stages = @agent.lifecycle_stages || []
    @email_templates = EmailTemplate.order(:template_type, :name)
    @stage_colors = assign_stage_colors(@lifecycle_stages)
  end

  def edit
    @lifecycle_stages = @agent.lifecycle_stages || []
    @email_templates = EmailTemplate.order(:template_type, :name)
  end

  def update
    if @agent.update(agent_params)
      flash[:success] = "#{@agent.name}'s lifecycle configuration updated successfully"
      redirect_to admin_agent_lifecycle_path(@agent)
    else
      flash[:error] = "Failed to update agent configuration"
      @lifecycle_stages = @agent.lifecycle_stages || []
      @email_templates = EmailTemplate.order(:template_type, :name)
      render :edit
    end
  end

  def add_stage
    @stage = build_new_stage
    @email_templates = EmailTemplate.order(:template_type, :name)
    render :stage_form
  end

  def edit_stage
    stage_index = params[:stage_index].to_i
    @stage = @agent.lifecycle_stages[stage_index]
    @stage_index = stage_index
    @email_templates = EmailTemplate.order(:template_type, :name)
    render :stage_form
  end

  def update_stage
    stage_index = params[:stage_index]&.to_i
    stages = @agent.lifecycle_stages || []

    if stage_index && stage_index < stages.length
      # Update existing stage
      stages[stage_index] = build_stage_from_params
    else
      # Add new stage
      stages << build_stage_from_params
    end

    if @agent.update(lifecycle_stages: stages)
      flash[:success] = "Stage '#{params[:stage_name]}' saved successfully"
      redirect_to admin_agent_lifecycle_path(@agent)
    else
      flash[:error] = "Failed to save stage"
      @stage = build_stage_from_params
      @email_templates = EmailTemplate.order(:template_type, :name)
      render :stage_form
    end
  end

  def delete_stage
    stage_index = params[:stage_index].to_i
    stages = @agent.lifecycle_stages || []

    if stage_index < stages.length
      removed_stage = stages.delete_at(stage_index)
      @agent.update(lifecycle_stages: stages)
      flash[:success] = "Stage '#{removed_stage['stage_label']}' deleted successfully"
    else
      flash[:error] = "Stage not found"
    end

    redirect_to admin_agent_lifecycle_path(@agent)
  end

  private

  def set_agent
    @agent = AiAgent.find(params[:id])
  end

  def agent_params
    params.require(:ai_agent).permit(
      lifecycle_stages: [
        :stage_name, :stage_label, :stage_description, :entry_trigger,
        :stage_color,
        automated_actions: [
          :action_type, :email_template_id, :task_type, :new_status, :message,
          delay: [:duration, :unit],
          conditions: {}
        ],
        exit_conditions: {},
        handoff_rules: [:handoff_to]
      ],
      communication_style: [:tone, :greeting, :signature]
    )
  end

  def build_new_stage
    {
      'stage_name' => '',
      'stage_label' => '',
      'stage_description' => '',
      'entry_trigger' => '',
      'stage_color' => 'blue',
      'automated_actions' => [],
      'exit_conditions' => {},
      'handoff_rules' => {}
    }
  end

  def build_stage_from_params
    {
      'stage_name' => params[:stage_name],
      'stage_label' => params[:stage_label],
      'stage_description' => params[:stage_description],
      'entry_trigger' => params[:entry_trigger],
      'stage_color' => params[:stage_color] || 'blue',
      'automated_actions' => parse_automated_actions,
      'exit_conditions' => parse_exit_conditions,
      'handoff_rules' => parse_handoff_rules
    }
  end

  def parse_automated_actions
    actions = params[:automated_actions] || []
    actions.map do |action_params|
      {
        'action_type' => action_params[:action_type],
        'email_template_id' => action_params[:email_template_id],
        'task_type' => action_params[:task_type],
        'new_status' => action_params[:new_status],
        'message' => action_params[:message],
        'delay' => {
          'duration' => action_params.dig(:delay, :duration).to_i,
          'unit' => action_params.dig(:delay, :unit) || 'minutes'
        },
        'conditions' => action_params[:conditions] || {}
      }.compact
    end.reject { |a| a['action_type'].blank? }
  end

  def parse_exit_conditions
    params[:exit_conditions] || {}
  end

  def parse_handoff_rules
    handoff_to = params[:handoff_to]
    handoff_to.present? ? { 'handoff_to' => handoff_to } : {}
  end

  def calculate_agent_stats
    {
      total_agents: AiAgent.count,
      active_agents: AiAgent.active.count,
      total_stages: AiAgent.sum { |a| (a.lifecycle_stages || []).count },
      configured_agents: AiAgent.where.not(lifecycle_stages: []).count
    }
  end

  def assign_stage_colors(stages)
    colors = ['blue', 'green', 'purple', 'orange', 'pink', 'teal']
    stages.each_with_index.map do |stage, index|
      [stage['stage_name'], stage['stage_color'] || colors[index % colors.length]]
    end.to_h
  end
end