module Admin
  class AdminDashboardV2Controller < ApplicationController
    include Admin::AdminHelper
    before_action :authenticate_user!
    before_action :check_admin_role

    def dashboard_v2
      # Get filtered scope based on selected jurisdiction
      apps = jurisdiction_filtered_scope(Application.all, :region)
      
      # Portfolio KPIs
      @total_applications = apps.count
      @total_capital_deployed = apps.sum(:equity_investment_amount)
      @active_investments = apps.where(status: :accepted).count
      @total_distributions = apps.joins(:user).joins("INNER JOIN applications ON distributions.application_id = applications.id").sum(:amount) rescue 0

      # Application funnel
      @pending_applications = apps.where(status: :submitted).count
      @approved_applications = apps.where(status: :accepted).count
      @rejected_applications = apps.where(status: :rejected).count

      # Distribution performance
      dist_apps = apps.pluck(:id)
      dists = dist_apps.any? ? Distribution.where(application_id: dist_apps) : Distribution.none
      @completed_distributions = dists.where(status: :completed).count
      @pending_distributions = dists.where(status: :pending).count
      @failed_distributions = dists.where(status: :failed).count

      # Regional breakdown
      @applications_by_region = apps.group(:region).count
      @capital_by_region = apps.group(:region).sum(:equity_investment_amount)

      # Recent applications
      @recent_applications = apps.order(created_at: :desc).limit(10)
      
      # Current jurisdiction display
      @current_jurisdiction = current_admin_jurisdiction
    end

    private

    def check_admin_role
      redirect_to root_path, alert: "Access denied." unless current_user.admin?
    end
  end
end
