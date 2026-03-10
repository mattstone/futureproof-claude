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

    # Show EPM loan details - borrower receives one-time capital payout
    def show
      @lender = @application.lender
      @contract = @application.contract

      # Calculate EPM loan metrics (borrower receives capital once)
      @loan_summary = {
        equity_amount: @application.equity_investment_amount,
        term_years: @application.participation_term_years,
        property_value: @application.home_value,
        equity_percentage: @application.equity_percentage,
        status: @application.status.humanize,
        capital_received: @application.status_activated? ? @application.equity_investment_amount : 0
      }
    end

    private

    def set_application
      @application = Application.find(params[:id])
    end

    def authorize_borrower_access!
      redirect_to borrower_root_path, alert: "Access denied" unless @application.user_id == current_user.id
    end
  end
end
