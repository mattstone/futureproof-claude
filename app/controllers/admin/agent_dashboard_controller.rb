module Admin
  class AgentDashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    def index
      @agents = AgentPerformance.includes(:daily_metrics).order(:agent_type)
      @recent_tasks = AgentTask.completed.order(completed_at: :desc).limit(20)
    end

    private

    def authorize_admin!
      redirect_to root_path unless current_user.admin?
    end
  end
end
