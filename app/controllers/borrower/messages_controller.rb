module Borrower
  class MessagesController < BaseController
    before_action :set_application, only: [ :index, :create, :mark_as_read ]
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

    # Create a new message (called by ActionCable)
    def create
      @message = BorrowerMessage.new(message_params)
      @message.application = @application
      @message.user = current_user

      # Determine sender type (borrower or lender)
      @message.sender_type = @application.user_id == current_user.id ? :borrower : :lender

      if @application.lender_id != current_user.id && @application.user_id != current_user.id
        return head :forbidden
      end

      @message.lender_id = current_user.id if @message.sender_type == :lender

      if @message.save
        # Broadcast to all subscribers (handled by after_create callback in model)
        render json: { success: true, message_id: @message.id }
      else
        render json: { success: false, errors: @message.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # Mark individual message as read
    def mark_as_read
      @message = BorrowerMessage.find(params[:id])

      # Verify access
      if @message.application_id != @application.id
        return head :forbidden
      end

      @message.mark_as_read! if @message.read_at.nil? && @message.from_lender?

      render json: { success: true }
    end

    private

    def set_application
      @application = current_user.applications.find(params[:application_id])
    end

    def authorize_access!
      is_borrower = @application.user_id == current_user.id
      is_lender = @application.lender_id == current_user.id
      redirect_to borrower_root_path, alert: "Access denied" unless is_borrower || is_lender
    end

    def message_params
      params.require(:message).permit(:message) if params[:message]
    end
  end
end
