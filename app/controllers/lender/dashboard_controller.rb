module Lender
  class DashboardController < BaseController
    # Lender dashboard with application pipeline overview
    def index
      # Get all applications assigned to this lender
      @applications = Application.where(lender_id: current_user.id)
                                  .includes(:user, :distributions)
                                  .order(created_at: :desc)

      # Pipeline stats
      @stats = {
        total: @applications.count,
        pending: @applications.where(status: :processing).count,
        approved: @applications.where(status: :accepted).count,
        active: @applications.where(status: :activated).count,
        rejected: @applications.where(status: :rejected).count
      }

      # Recent applications
      @recent_applications = @applications.limit(5)

      # Monthly distribution data
      @monthly_distributions = Distribution.joins(application: :lender)
                                            .where(applications: { lender_id: current_user.id }, distributions: { status: :completed })
                                            .group_by_month(:processed_at)
                                            .sum(:amount)

      # Top borrowers by income
      @top_borrowers = @applications.where(status: :activated)
                                     .sort_by { |app| app.distributions.sum(&:amount) }
                                     .reverse
                                     .first(5)
    end

    # All applications assigned to lender
    def applications
      @applications = Application.where(lender_id: current_user.id)
                                  .includes(:user, :distributions)
      
      # Filter by status
      if params[:status].present?
        @applications = @applications.where(status: params[:status])
      end

      # Sort
      case params[:sort]
      when 'newest'
        @applications = @applications.order(created_at: :desc)
      when 'oldest'
        @applications = @applications.order(created_at: :asc)
      when 'value_high'
        @applications = @applications.sort_by { |a| a.loan_amount }.reverse
      when 'value_low'
        @applications = @applications.sort_by { |a| a.loan_amount }
      else
        @applications = @applications.order(created_at: :desc)
      end

      @stats = {
        total: Application.where(lender_id: current_user.id).count,
        pending: Application.where(lender_id: current_user.id, status: :processing).count,
        approved: Application.where(lender_id: current_user.id, status: :accepted).count,
        active: Application.where(lender_id: current_user.id, status: :activated).count,
        rejected: Application.where(lender_id: current_user.id, status: :rejected).count
      }
    end

    # Individual application review
    def application_detail
      @application = Application.find(params[:id])
      authorize_application!

      @borrower = @application.user
      @messages = @application.borrower_messages.includes(:user, :lender).order(created_at: :asc)
      @distributions = @application.distributions.order(distribution_date: :desc)
    end

    # All payments made to borrowers
    def payments
      @distributions = Distribution.joins(application: :lender)
                                    .where(applications: { lender_id: current_user.id })
                                    .includes(application: :user)
                                    .order(processed_at: :desc)

      # Filter by status
      if params[:status].present?
        @distributions = @distributions.where(status: params[:status])
      end

      # Monthly totals
      @monthly_totals = @distributions.where(status: :completed)
                                       .group_by { |d| d.processed_at&.beginning_of_month }
                                       .map { |month, dists| { month: month, total: dists.sum(&:amount), count: dists.count } }
                                       .sort_by { |h| h[:month] }
                                       .reverse
    end

    # Reports and analytics
    def reports
      @applications = Application.where(lender_id: current_user.id).includes(:distributions)

      # Portfolio metrics
      @portfolio = {
        total_loan_amount: @applications.sum(:loan_amount),
        total_active_loans: @applications.where(status: :activated).count,
        total_distributed: Distribution.joins(application: :lender)
                                        .where(applications: { lender_id: current_user.id }, status: :completed)
                                        .sum(:amount),
        average_ltv: @applications.average(:ltv_ratio).to_f.round(2),
        average_property_value: @applications.average(:property_value).to_f.round(0)
      }

      # Performance metrics
      @performance = {
        approval_rate: calculate_approval_rate,
        activation_rate: calculate_activation_rate,
        avg_time_to_approval: calculate_avg_approval_time,
        avg_portfolio_yield: calculate_avg_yield
      }
    end

    # Account settings
    def account
      @lender = current_user
    end

    def update_account
      if current_user.update(account_params)
        redirect_to lender_dashboard_account_path, notice: "Account updated successfully"
      else
        flash.now[:alert] = "Failed to update account"
        render :account
      end
    end

    private

    def authorize_application!
      redirect_to lender_dashboard_applications_path, alert: "Access denied" unless @application.lender_id == current_user.id
    end

    def calculate_approval_rate
      total = Application.where(lender_id: current_user.id).count
      return 0 if total.zero?
      
      approved = Application.where(lender_id: current_user.id).where("status IN (?)", [:accepted, :activated]).count
      ((approved.to_f / total) * 100).round(1)
    end

    def calculate_activation_rate
      total = Application.where(lender_id: current_user.id, status: :accepted).count
      return 0 if total.zero?
      
      activated = Application.where(lender_id: current_user.id, status: :activated).count
      ((activated.to_f / total) * 100).round(1)
    end

    def calculate_avg_approval_time
      approved_apps = Application.where(lender_id: current_user.id)
                                  .where("status IN (?)", [:accepted, :activated])
                                  .where("approved_at IS NOT NULL")
      
      return 0 if approved_apps.empty?
      
      total_time = approved_apps.sum { |a| (a.approved_at - a.created_at).to_i / 86400 }
      (total_time / approved_apps.count).round(1)
    end

    def calculate_avg_yield
      # Average annual yield from completed distributions
      active_loans = Application.where(lender_id: current_user.id, status: :activated)
      return 0 if active_loans.empty?
      
      total_yield = active_loans.sum { |a| a.interest_rate }
      (total_yield / active_loans.count * 100).round(2)
    end

    def account_params
      params.require(:user).permit(:email, :phone_number)
    end
  end
end
