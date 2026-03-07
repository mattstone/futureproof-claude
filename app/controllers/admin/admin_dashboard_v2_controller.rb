module Admin
  class AdminDashboardV2Controller < ApplicationController
    before_action :authenticate_user!
    before_action :check_admin_role

    def dashboard_v2
      # Portfolio KPIs
      @total_applications = Application.count
      @total_capital_deployed = Application.sum(:equity_investment_amount)
      @active_investments = Application.where(status: :accepted).count
      @total_distributions = Distribution.sum(:amount)

      # Application funnel
      @pending_applications = Application.where(status: :submitted).count
      @approved_applications = Application.where(status: :accepted).count
      @rejected_applications = Application.where(status: :rejected).count

      # Distribution performance
      @completed_distributions = Distribution.where(status: :completed).count
      @pending_distributions = Distribution.where(status: :pending).count
      @failed_distributions = Distribution.where(status: :failed).count

      # Regional breakdown
      @applications_by_region = Application.group(:region).count
      @capital_by_region = Application.group(:region).sum(:equity_investment_amount)

      # Recent applications
      @recent_applications = Application.order(created_at: :desc).limit(10)
    end

    private

    def check_admin_role
      redirect_to root_path, alert: "Access denied." unless current_user.admin?
    end
  end
end
