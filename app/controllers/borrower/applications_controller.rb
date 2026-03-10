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

    # Show EPM loan details, payment schedule, contract
    def show
      @lender = @application.lender
      @contract = @application.contract
      @distributions = @application.distributions.order(:processed_at)

      # Calculate current loan metrics
      @loan_summary = {
        original_amount: @application.equity_investment_amount,
        term_years: @application.participation_term_years,
        property_value: @application.home_value,
        equity_percentage: @application.equity_percentage,
        status: @application.status.humanize,
        total_paid: @distributions.where(status: "completed").sum(:amount),
        remaining_payments: @distributions.where(status: ["pending", "processing"]).count,
        next_payment: calculate_next_payout
      }
    end

    private

    def set_application
      @application = Application.find(params[:id])
    end

    def authorize_borrower_access!
      redirect_to borrower_root_path, alert: "Access denied" unless @application.user_id == current_user.id
    end

    def calculate_next_payout
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
