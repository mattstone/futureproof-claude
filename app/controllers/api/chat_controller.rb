module Api
  class ChatController < ApplicationController
    skip_before_action :authenticate_user!, only: [:create]
    before_action :set_region

    # POST /api/chat/send
    def send_message
      message_text = params[:message]
      return render json: { error: "Message required" }, status: :unprocessable_entity if message_text.blank?

      router = AiAgentRouter.new(
        message: message_text,
        region: @region,
        user: current_user
      )

      response = router.route_and_respond

      if current_user
        conversation = ChatConversation.find_or_create_by(user: current_user, status: "active")
        ChatMessage.create!(
          chat_conversation: conversation,
          user_message: message_text,
          agent_response: response[:response],
          agent_type: response[:agent_type]
        )
      end

      render json: response
    end

    # GET /api/chat/conversations
    def conversations
      return render json: { error: "Unauthorized" }, status: :unauthorized unless current_user

      conversations = current_user.chat_conversations.recent
      render json: conversations.map { |c|
        {
          id: c.id,
          agent: c.chat_agent&.name,
          status: c.status,
          message_count: c.message_count,
          updated_at: c.updated_at
        }
      }
    end

    private

    def set_region
      @region = params[:region]&.downcase || RegionHelper.default_region
    end
  end
end
