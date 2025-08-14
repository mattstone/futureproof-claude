class ContractMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contract_message

  def mark_as_read
    if @contract_message.contract.application.user == current_user
      @contract_message.mark_as_read!
      
      # Get updated unread count for contracts
      unread_count = Contract.joins(:application, :contract_messages)
        .where(applications: { user_id: current_user.id })
        .where(contract_messages: { message_type: 'admin_to_customer', status: 'sent' })
        .count('contract_messages.id')

      render json: { 
        success: true, 
        unread_count: unread_count,
        message: 'Contract message marked as read' 
      }
    else
      render json: { success: false, error: 'Unauthorized' }, status: :forbidden
    end
  end

  private

  def set_contract_message
    @contract_message = ContractMessage.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Contract message not found' }, status: :not_found
  end
end