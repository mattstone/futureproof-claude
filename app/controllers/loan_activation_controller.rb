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

    # EPM Investment activation - could trigger first distribution
    @application.update!(
      updated_at: Time.current  # Mark as activated, status stays 'accepted' 
    )
    
    # TODO: Trigger initial distribution to borrower
    
    redirect_to borrower_portal_path(params[:region], @application), 
                notice: 'EPM Investment activated successfully! Your equity partnership is now active.'
  end

  private

  def load_application
    @application = current_user.applications.find(params[:application_id])
    @region = params[:region]
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: 'Application not found or access denied.'
  end
end
