module Borrower
  class MessagesController < BaseController
    before_action :set_application, only: [:index, :create]
    before_action :authorize_access!

    # List all messages for an application (conversation)
    def index
      @messages = BorrowerMessage.for_application(@application)
                                  .includes(:user, :lender)
                                  .order(created_at: :asc)
      
      # Mark borrower's unread messages from lender as read
      @messages.by_lender.unread.update_all(read_at: Time.current)
      
      @unread_count = BorrowerMessage.by_lender.unread.count
    end

    # Create a new message
    def create
      @message = BorrowerMessage.new(message_params)
      @message.application = @application
      @message.user = current_user
      @message.sender_type = "borrower"

      if @message.save
        # TODO: Send notification to lender
        redirect_to borrower_application_messages_path(@application), 
                    notice: "Message sent successfully."
      else
        flash.now[:alert] = "Failed to send message."
        @messages = @application.borrower_messages.order(created_at: :asc)
        render :index
      end
    end

    private

    def set_application
      @application = current_user.applications.find(params[:application_id])
    end

    def authorize_access!
      redirect_to borrower_root_path, alert: "Access denied" unless @application.user_id == current_user.id
    end

    def message_params
      params.require(:borrower_message).permit(:message)
    end
  end
end
