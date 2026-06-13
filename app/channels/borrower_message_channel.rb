class BorrowerMessageChannel < ApplicationCable::Channel
  def subscribed
    @application = Application.find(params[:application_id])
    authorize_access!

    stream_for @application

    # Mark all messages from other party as read when user subscribes
    @application.borrower_messages.unread.where.not(user_id: current_user.id).each(&:mark_as_read!)
  end

  def unsubscribed
    # Any cleanup when user leaves the channel
  end

  def send_message(data)
    @application = Application.find(params[:application_id])
    authorize_access!

    # Determine sender type (borrower or lender)
    sender_type = @application.user_id == current_user.id ? :borrower : :lender
    lender = sender_type == :lender ? current_user : nil

    message = @application.borrower_messages.create!(
      user_id: current_user.id,
      lender_id: lender&.id,
      message: data["message"],
      sender_type: sender_type
    )

    # Broadcast to all subscribers of this application's channel
    BorrowerMessageChannel.broadcast_to(
      @application,
      {
        id: message.id,
        user_name: current_user.full_name,
        user_avatar: avatar_url(current_user),
        sender_type: sender_type,
        message: message.message,
        created_at: message.created_at.strftime("%H:%M %p"),
        is_current_user: true
      }
    )
  end

  private

  def authorize_access!
    # Only borrower and assigned lender can access this channel
    is_borrower = @application.user_id == current_user.id
    is_lender = @application.lender_id == current_user.id

    reject unless is_borrower || is_lender
  end

  def avatar_url(user)
    # Return initials-based avatar or gravatar
    "https://api.dicebear.com/7.x/initials/svg?seed=#{user.full_name}"
  end
end
