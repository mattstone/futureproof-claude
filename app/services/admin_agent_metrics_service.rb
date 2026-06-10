class AdminAgentMetricsService
  AgentCard = Struct.new(
    :agent, :total, :today, :week, :approval_rate, :avg_confidence,
    :last_action_at, :active,
    keyword_init: true
  )

  AgentRoster = Struct.new(:performances, :recent_tasks, keyword_init: true)

  def call
    {
      summary: summary,
      cards: cards,
      roster: roster
    }
  end

  def summary
    {
      total_today: AgentAction.where('created_at >= ?', Time.current.beginning_of_day).count,
      total_week: AgentAction.where('created_at >= ?', 1.week.ago).count,
      total_all: AgentAction.count,
      avg_confidence: AgentAction.where.not(confidence: nil).average(:confidence)&.round(2) || 0,
      flags_count: AgentAction.where(decision: 'flag', status: 'completed').count,
      escalations_count: AgentAction.where(action_type: 'escalate', status: 'completed').count,
      decision_distribution: AgentAction.where.not(decision: nil).group(:decision).count
    }
  rescue => e
    Rails.logger.error("AdminAgentMetricsService#summary error: #{e.message}")
    empty_summary
  end

  def cards
    AiAgent.active.order(:name).map { |agent| build_card(agent) }
  rescue => e
    Rails.logger.error("AdminAgentMetricsService#cards error: #{e.message}")
    []
  end

  def roster
    AgentRoster.new(
      performances: AgentPerformance.order(:agent_type, :agent_name),
      recent_tasks: AgentTask.completed.order(completed_at: :desc).limit(20)
    )
  rescue => e
    Rails.logger.error("AdminAgentMetricsService#roster error: #{e.message}")
    AgentRoster.new(performances: AgentPerformance.none, recent_tasks: AgentTask.none)
  end

  private

  def build_card(agent)
    actions = agent.agent_actions
    total = actions.count
    approvals = actions.where(decision: 'approve').count
    last_action = actions.maximum(:created_at)

    AgentCard.new(
      agent: agent,
      total: total,
      today: actions.where('created_at >= ?', Time.current.beginning_of_day).count,
      week: actions.where('created_at >= ?', 1.week.ago).count,
      approval_rate: total.positive? ? (approvals.to_f / total * 100).round(1) : 0,
      avg_confidence: actions.where.not(confidence: nil).average(:confidence)&.round(2) || 0,
      last_action_at: last_action,
      active: last_action.present? && last_action > 1.hour.ago
    )
  end

  def empty_summary
    {
      total_today: 0, total_week: 0, total_all: 0,
      avg_confidence: 0, flags_count: 0, escalations_count: 0,
      decision_distribution: {}
    }
  end
end
