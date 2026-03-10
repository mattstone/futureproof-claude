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

    # Show payment history with filtering
    def payment_history
      @period = params[:period] || 'all'
      service = BorrowerIncomeService.new(@application)
      @distributions = service.distributions_by_period(@period)
      @summary = service.period_summary(@distributions)
    end

    # Show loan documents
    def documents
      @contract = @application.contract
      @documents = [@application.contract].compact
    end

    # Download contract PDF
    def download_contract
      respond_to do |format|
        format.pdf do
          render action: :contract, layout: false
        end
      end
    end

    # Download monthly income statements PDF
    def download_statements
      respond_to do |format|
        format.pdf do
          render action: :income_statements, layout: false
        end
      end
    end

    # Download key facts sheet PDF
    def download_key_facts
      respond_to do |format|
        format.pdf do
          render action: :key_facts, layout: false
        end
      end
    end

    # Download payment receipt PDF
    def download_receipt
      distribution = @application.distributions.find(params[:distribution_id])
      
      if distribution.user_id != current_user.id && distribution.lender_id != current_user.id
        return redirect_to borrower_root_path, alert: "Access denied"
      end

      @distribution = distribution
      respond_to do |format|
        format.pdf do
          render action: 'distributions/receipt', layout: false
        end
      end
    end

    # Show EPM income dashboard - customer receives monthly guaranteed income
    def show
      @lender = @application.lender
      @contract = @application.contract
      @distributions = @application.distributions.order(:distribution_date)

      # Use service to calculate income summary
      service = BorrowerIncomeService.new(@application)
      @income_summary = service.income_summary
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
