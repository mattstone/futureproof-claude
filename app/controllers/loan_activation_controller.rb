class LoanActivationController < ApplicationController
  before_action :authenticate_user!
  before_action :load_application

  def show
    unless @application.status == 'accepted'
      redirect_to borrower_portal_path(params[:region], @application), alert: 'EPM investment is not approved.'
      return
    end
  end

  def activate
    unless @application.status == 'accepted'
      redirect_to borrower_portal_path(params[:region], @application), alert: 'EPM investment is not approved.'
      return
    end

    # EPM Investment activation - trigger initial capital disbursement to borrower
    begin
      Distribution.create!(
        application: @application,
        amount: @application.equity_investment_amount,
        distribution_date: Date.current,
        status: :pending,
        lender_margin: 0,
        notes: "Initial equity capital disbursement upon activation"
      )

      @application.update!(status: :activated)
      
      redirect_to borrower_portal_path(params[:region], @application), 
                  notice: 'EPM Investment activated successfully! Your equity capital disbursement is pending.'
    rescue StandardError => e
      redirect_to loan_activation_path(params[:region], @application), 
                  alert: "Activation failed: #{e.message}"
    end
  end

  private

  def load_application
    @application = current_user.applications.find(params[:application_id])
    @region = params[:region]
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: 'Application not found or access denied.'
  end
end
