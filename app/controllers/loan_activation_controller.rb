class LoanActivationController < ApplicationController
  before_action :authenticate_user!
  before_action :load_application

  def show
    redirect_to borrower_portal_path(params[:region], @application), alert: 'Application is not approved.' unless @application.status == 'accepted'
  end

  def activate
    unless @application.status == 'accepted'
      redirect_to borrower_portal_path(params[:region], @application), alert: 'Application is not approved.'
      return
    end

    @application.update!(status: :activated)
    redirect_to borrower_portal_path(params[:region], @application), notice: 'Loan activated successfully.'
  end

  private

  def load_application
    @application = current_user.applications.find(params[:application_id])
    @region = params[:region]
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: 'Application not found or access denied.'
  end
end
