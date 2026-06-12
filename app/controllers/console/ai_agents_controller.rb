# The AI agent operations area: roster + performance on the index, per-agent
# detail with lifecycle stage management (stages are a JSON array on the
# agent — same storage as the legacy admin, simpler editing).
class Console::AiAgentsController < Console::BaseController
  before_action -> { require_capability(:view_system) }
  before_action :set_agent, only: [ :show, :edit_stage, :update_stage, :delete_stage ]

  def index
    @agents = AiAgent.order(:name)
    @performances = AgentPerformance.order(:agent_type)
    @recent_tasks = AgentTask.completed.order(completed_at: :desc).limit(20)
    @stats = {
      total_agents: AiAgent.count,
      active_agents: AiAgent.active.count,
      tasks_today: @performances.sum(:tasks_completed_today),
      avg_resolution: @performances.average(:avg_resolution_minutes).to_i,
      avg_satisfaction: @performances.average(:satisfaction_score)&.round(1)
    }
  end

  def show
    @lifecycle_stages = @agent.lifecycle_stages || []
    @performance = AgentPerformance.find_by(agent_name: @agent.name)
    @recent_actions = AgentAction.where(ai_agent: @agent).order(created_at: :desc).limit(20)
    @email_templates = EmailTemplate.order(:template_type, :name)
  end

  def edit_stage
    @stage_index = params[:stage_index].presence&.to_i
    @stage = @stage_index ? (@agent.lifecycle_stages || [])[@stage_index] : blank_stage
    @email_templates = EmailTemplate.order(:template_type, :name)
  end

  def update_stage
    stage_index = params[:stage_index].presence&.to_i
    stages = @agent.lifecycle_stages || []

    if stage_index && stage_index < stages.length
      stages[stage_index] = build_stage_from_params
    else
      stages << build_stage_from_params
    end

    if @agent.update(lifecycle_stages: stages)
      redirect_to console_ai_agent_path(@agent), notice: "Stage '#{params[:stage_label]}' saved."
    else
      redirect_to console_ai_agent_path(@agent), alert: "Failed to save stage."
    end
  end

  def delete_stage
    stage_index = params[:stage_index].to_i
    stages = @agent.lifecycle_stages || []

    if stage_index < stages.length
      removed = stages.delete_at(stage_index)
      @agent.update(lifecycle_stages: stages)
      redirect_to console_ai_agent_path(@agent), notice: "Stage '#{removed['stage_label']}' deleted."
    else
      redirect_to console_ai_agent_path(@agent), alert: "Stage not found."
    end
  end

  private

  def set_agent
    @agent = AiAgent.find(params[:id])
  end

  def blank_stage
    {
      "stage_name" => "", "stage_label" => "", "stage_description" => "",
      "entry_trigger" => "", "stage_color" => "blue",
      "automated_actions" => [], "exit_conditions" => {}, "handoff_rules" => {}
    }
  end

  def build_stage_from_params
    {
      "stage_name" => params[:stage_name],
      "stage_label" => params[:stage_label],
      "stage_description" => params[:stage_description],
      "entry_trigger" => params[:entry_trigger],
      "stage_color" => params[:stage_color].presence || "blue",
      "automated_actions" => parse_automated_actions,
      "exit_conditions" => {},
      "handoff_rules" => params[:handoff_to].present? ? { "handoff_to" => params[:handoff_to] } : {}
    }
  end

  def parse_automated_actions
    (params[:automated_actions] || []).filter_map do |action|
      next if action[:action_type].blank?

      {
        "action_type" => action[:action_type],
        "email_template_id" => action[:email_template_id],
        "task_type" => action[:task_type],
        "new_status" => action[:new_status],
        "message" => action[:message],
        "delay" => {
          "duration" => action.dig(:delay, :duration).to_i,
          "unit" => action.dig(:delay, :unit).presence || "minutes"
        }
      }.compact
    end
  end
end
