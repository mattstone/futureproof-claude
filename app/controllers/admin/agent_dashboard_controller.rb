class Admin::AgentDashboardController < Admin::BaseController
  before_action :ensure_futureproof_admin

  def index
    @agents = AiAgent.active.order(:name)
    @recent_actions = AgentAction.includes(:ai_agent).order(created_at: :desc).limit(50)
    @stats = calculate_dashboard_stats
  end

  def show
    @agent = AiAgent.find(params[:id])
    @actions = @agent.agent_actions.order(created_at: :desc).limit(50)
    @decision_breakdown = @agent.agent_actions.group(:decision).count
    @action_type_breakdown = @agent.agent_actions.group(:action_type).count
    @total_actions = @agent.agent_actions.count
    @avg_confidence = @agent.agent_actions.where.not(confidence: nil).average(:confidence)&.round(2) || 0
    @approval_rate = @total_actions > 0 ? (@agent.agent_actions.where(decision: 'approve').count.to_f / @total_actions * 100).round(1) : 0
    @flags_count = @agent.agent_actions.where(decision: 'flag').count
    @rejections_count = @agent.agent_actions.where(decision: 'reject').count
  end

  def override
    @action = AgentAction.find(params[:id])
    @action.override!(
      by: current_user.email,
      reason: params[:reason].presence || "Manual override by #{current_user.display_name}"
    )

    if @action.actionable_type == 'Application' && params[:decision].present?
      application = Application.find(@action.actionable_id)
      case params[:decision]
      when 'approve'
        AgentAction.create!(
          ai_agent: @action.ai_agent,
          actionable: application,
          action_type: 'decide',
          decision: 'approve',
          confidence: 1.0,
          reasoning: "Manually approved by #{current_user.display_name}: #{params[:reason]}",
          status: 'completed'
        )
      when 'reject'
        AgentAction.create!(
          ai_agent: @action.ai_agent,
          actionable: application,
          action_type: 'decide',
          decision: 'reject',
          confidence: 1.0,
          reasoning: "Manually rejected by #{current_user.display_name}: #{params[:reason]}",
          status: 'completed'
        )
      end
    end

    redirect_to admin_agent_dashboard_index_path, notice: "Decision overridden successfully."
  end

  def timeline
    @actions = AgentAction.includes(:ai_agent).order(created_at: :desc).limit(100)
    @agents = AiAgent.active.order(:name)
  end

  private

  def calculate_dashboard_stats
    stats = {}
    AiAgent.active.each do |agent|
      actions = agent.agent_actions
      total = actions.count
      approvals = actions.where(decision: 'approve').count
      stats[agent.id] = {
        total: total,
        approval_rate: total > 0 ? (approvals.to_f / total * 100).round(1) : 0,
        avg_confidence: actions.where.not(confidence: nil).average(:confidence)&.round(2) || 0,
        flags: actions.where(decision: 'flag').count,
        rejections: actions.where(decision: 'reject').count,
        last_action_at: actions.maximum(:created_at)
      }
    end
    stats
  end
end
