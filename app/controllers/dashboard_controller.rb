class DashboardController < ApplicationController
  before_action :authenticate_user!
  layout 'dashboard'

  def index
    @applications = current_user.applications.recent
    @current_application = @applications.in_progress.first
    @submitted_applications = @applications.completed
    @section = params[:section] # Track which section is active
    
    # Load messaging data for submitted applications
    if @submitted_applications.any?
      @submitted_applications = @submitted_applications.includes(
        application_messages: [:ai_agent, :sender, :replies]
      )
    end
    
    # Load contract data if contracts section is active
    if @section == 'contracts'
      @contracts = Contract.joins(:application)
                          .where(applications: { user_id: current_user.id })
                          .includes(contract_messages: [:sender, :replies], application: [:user])
      @contracts_with_unread = @contracts.joins(:contract_messages)
                                       .where(contract_messages: { status: 'sent', message_type: 'admin_to_customer' })
                                       .distinct
    end
  end

  def start_application
    # Show start application page
  end
end