class Api::ChatController < ApplicationController
  skip_before_action :authenticate_user!, only: [:create, :guest_message]
  skip_before_action :ensure_email_verified!, only: [:create, :guest_message]

  # POST /api/chat
  # Create a new conversation or send a message to existing one
  def create
    message_text = params[:message]
    conversation_id = params[:conversation_id]
    region = params[:region] || current_region

    if message_text.blank?
      return render json: { success: false, error: "Message cannot be blank" }, status: :unprocessable_entity
    end

    # Find or create conversation
    conversation = if conversation_id.present?
      ChatConversation.find_by(id: conversation_id)
    end

    # Route message to appropriate agent
    routing = AiAgentRouter.route(
      message: message_text,
      user: current_user,
      page_context: params[:page_context],
      region: region
    )

    if routing[:agent].nil?
      return render json: { success: false, error: "No agent available" }, status: :service_unavailable
    end

    # Create conversation if needed
    conversation ||= ChatConversation.create!(
      user: current_user,
      chat_agent: routing[:agent],
      region: region,
      subject: message_text.truncate(100)
    )

    # Save user message
    user_message = conversation.chat_messages.create!(
      role: "user",
      content: message_text
    )

    # Save agent response
    agent_message = conversation.chat_messages.create!(
      role: "agent",
      content: routing[:response],
      metadata: {
        agent_type: routing[:agent_type],
        confidence: routing[:confidence]
      }
    )

    render json: {
      success: true,
      conversation_id: conversation.id,
      agent: {
        name: routing[:agent].name,
        type: routing[:agent].agent_type,
        emoji: routing[:agent].avatar_emoji
      },
      messages: [
        { id: user_message.id, role: "user", content: user_message.content, created_at: user_message.created_at },
        { id: agent_message.id, role: "agent", content: agent_message.content, created_at: agent_message.created_at }
      ]
    }
  end

  # POST /api/chat/guest
  # Quick response without persisting (for anonymous users)
  def guest_message
    message_text = params[:message]
    region = params[:region] || "us"

    if message_text.blank?
      return render json: { success: false, error: "Message cannot be blank" }, status: :unprocessable_entity
    end

    routing = AiAgentRouter.route(
      message: message_text,
      region: region
    )

    render json: {
      success: true,
      agent_type: routing[:agent_type],
      response: routing[:response],
      confidence: routing[:confidence]
    }
  end

  # GET /api/chat/conversations
  # List user's conversations
  def conversations
    conversations = ChatConversation.where(user: current_user)
                                    .includes(:chat_agent, :chat_messages)
                                    .recent
                                    .limit(20)

    render json: {
      success: true,
      conversations: conversations.map { |c|
        {
          id: c.id,
          agent_name: c.chat_agent.name,
          agent_type: c.chat_agent.agent_type,
          agent_emoji: c.chat_agent.avatar_emoji,
          subject: c.subject,
          status: c.status,
          message_count: c.message_count,
          last_message: c.last_message&.content&.truncate(100),
          updated_at: c.updated_at
        }
      }
    }
  end

  # GET /api/chat/conversations/:id/messages
  def messages
    conversation = ChatConversation.find(params[:id])

    # Ensure user owns this conversation
    unless conversation.user == current_user || current_user&.admin?
      return render json: { success: false, error: "Not authorized" }, status: :forbidden
    end

    messages = conversation.chat_messages.chronological

    render json: {
      success: true,
      conversation_id: conversation.id,
      messages: messages.map { |m|
        {
          id: m.id,
          role: m.role,
          content: m.content,
          created_at: m.created_at
        }
      }
    }
  end
end
