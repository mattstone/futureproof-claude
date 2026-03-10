module Borrower
  class ApplicationsController < BaseController
    before_action :set_application, only: [:show]
    before_action :authorize_borrower_access!, only: [:show]

    # List all EPM applications for current borrower
    def index
      @applications = current_user.applications.includes(:lender, :distributions)
                                               .order(created_at: :desc)

      @stats = {
        total: @applications.count,
        active: @applications.where(status: [:submitted, :processing, :accepted]).count,
        completed: @applications.where(status: :activated).count,
        rejected: @applications.where(status: :rejected).count
      }
    end

    # Show EPM income dashboard - customer receives monthly guaranteed income
    def show
      @lender = @application.lender
      @contract = @application.contract
      @distributions = @application.distributions.order(:distribution_date)

      # Calculate EPM income metrics
      @income_summary = {
        property_value: @application.home_value,
        mortgage_amount: @application.equity_investment_amount,
        ltv: @application.equity_percentage,
        term_years: @application.participation_term_years,
        status: @application.status.humanize,
        total_income_received: @distributions.where(status: "completed").sum(:amount),
        next_income: calculate_next_income,
        remaining_income_payments: @distributions.where(status: ["pending", "processing"]).count
      }
    end

    private

    def set_application
      @application = Application.find(params[:id])
    end

    def authorize_borrower_access!
      redirect_to borrower_root_path, alert: "Access denied" unless @application.user_id == current_user.id
    end

    def calculate_next_income
      pending = @application.distributions.where(status: ["pending", "processing"]).order(:distribution_date).first
      if pending
        {
          date: pending.distribution_date&.to_date,
          amount: pending.amount
        }
      else
        nil
      end
    end
  end
end
