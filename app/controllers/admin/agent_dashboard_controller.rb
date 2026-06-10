module Admin
  class AgentDashboardController < Admin::BaseController
    # authenticate_user! and authorization already applied by BaseController

    def index
      @agents = AgentPerformance.order(:agent_type)
      @recent_tasks = AgentTask.completed.order(completed_at: :desc).limit(20)
    end

    private

    def authorize_admin!
      redirect_to root_path unless current_user.admin?
    end
  end
end
