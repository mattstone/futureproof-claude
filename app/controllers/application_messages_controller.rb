class ApplicationMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_application_message

  def mark_as_read
    if @application_message.application.user == current_user
      @application_message.mark_as_read!
      
      # Get updated unread count
      unread_count = current_user.applications.joins(:application_messages)
        .where(application_messages: { message_type: 'admin_to_customer', status: 'sent' })
        .count('application_messages.id')

      render json: { 
        success: true, 
        unread_count: unread_count,
        message: 'Message marked as read' 
      }
    else
      render json: { success: false, error: 'Unauthorized' }, status: :forbidden
    end
  end

  private

  def set_application_message
    @application_message = ApplicationMessage.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Message not found' }, status: :not_found
  end
end