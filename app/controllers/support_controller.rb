class SupportController < ApplicationController
  # No authentication required — support chat is public
  skip_before_action :authenticate_user!, raise: false

  def chat
    @region = params[:region] || "au"
    @session_id = session[:support_session_id] ||= SecureRandom.uuid
    @messages = session[:support_messages] || []
  end

  def send_message
    @region = params[:region] || "au"
    @session_id = session[:support_session_id] ||= SecureRandom.uuid

    message = params[:message]&.strip
    if message.blank? || message.length > 5000
      render json: { success: false, error: "Message must be between 1 and 5000 characters." }, status: :unprocessable_entity
      return
    end

    # Build conversation history from session
    history = (session[:support_messages] || []).last(10).map do |msg|
      { role: msg["role"], content: msg["content"] }
    end

    # Get response
    service = CustomerSupportService.new(session_id: @session_id, region: @region)
    result = service.respond(user_message: message, conversation_history: history)

    # Store in session
    session[:support_messages] ||= []
    session[:support_messages] << { "role" => "user", "content" => message, "timestamp" => Time.current.iso8601 }
    session[:support_messages] << {
      "role" => "assistant",
      "content" => result[:response],
      "timestamp" => Time.current.iso8601,
      "source" => result[:source].to_s
    }

    # Keep session manageable (last 30 messages)
    session[:support_messages] = session[:support_messages].last(30)

    render json: {
      success: result[:success],
      user_message: {
        sender: "You",
        content: message,
        timestamp: Time.current.iso8601
      },
      assistant_message: {
        sender: "FutureProof Support",
        content: result[:response],
        timestamp: Time.current.iso8601,
        source: result[:source].to_s
      },
      escalate: result[:escalate] || false
    }
  end

  def clear
    session.delete(:support_messages)
    session.delete(:support_session_id)
    redirect_to support_chat_path(params[:region] || "au"), notice: "Conversation cleared."
  end
end
