module Admin
  class ChatConversationsController < Admin::BaseController
    def index
      @conversations = ChatConversation.includes(:user, :chat_agent)
                                       .order(updated_at: :desc)

      agent_messages = ChatMessage.where(role: 'agent')
      @quality = {
        total: agent_messages.count,
        claude: agent_messages.where("metadata->>'source' = ?", 'claude').count,
        fallback: agent_messages.where("metadata->>'source' = ?", 'knowledge_base').count,
        escalations: agent_messages.where("metadata->>'escalate' = ?", 'true').count
      }

      if params[:filter] == 'escalated'
        escalated_ids = agent_messages.where("metadata->>'escalate' = ?", 'true')
                                      .distinct.pluck(:chat_conversation_id)
        @conversations = @conversations.where(id: escalated_ids)
      end

      @conversations = @conversations.page(params[:page]).per(50)

      assistant_messages = ChatMessage.where(role: 'agent')
      @token_totals = assistant_messages.find_each.each_with_object(input: 0, output: 0, cache_read: 0) do |m, acc|
        usage = m.metadata&.dig('usage') || {}
        acc[:input] += usage['input_tokens'].to_i
        acc[:output] += usage['output_tokens'].to_i
        acc[:cache_read] += usage['cache_read_input_tokens'].to_i
      end
    end

    def show
      @conversation = ChatConversation.includes(:user, :chat_agent, :chat_messages).find(params[:id])
      @messages = @conversation.chat_messages.chronological
    end
  end
end
