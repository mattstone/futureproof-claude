class BorrowerPortalController < ApplicationController
  before_action :authenticate_user!
  before_action :load_application

  def dashboard
    @distributions = @application.distributions.recent.limit(10)
    @total_distributions = @application.distributions.completed_distributions.sum(:amount)
    @pending_distributions = @application.distributions.pending_distributions.sum(:amount)
  end

  def annuity_schedule
    # Show projected distribution schedule based on equity participation
    @distributions = @application.distributions.order(:distribution_date)
  end

  def loan_details
    # Show EPM equity investment details
  end

  def property_details
    # Show property information and valuation details
  end

  def documents
    # Show application documents and contracts
    @documents = []  # TODO: Add document model/storage
  end

  private

  def load_application
    @application = current_user.applications.find(params[:application_id])
    @region = params[:region]
  rescue ActiveRecord::RecordNotFound
    redirect_to dashboard_path, alert: 'Application not found or access denied.'
  end
end