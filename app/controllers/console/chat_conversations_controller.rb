# AI conversation oversight: quality split (Claude vs knowledge-base
# fallback), escalations, token spend, and per-message prompt provenance.
class Console::ChatConversationsController < Console::BaseController
  before_action -> { require_capability(:manage_users) }

  def index
    @conversations = scoped_conversations.includes(:user, :chat_agent).order(updated_at: :desc)

    agent_messages = ChatMessage.where(role: "agent")
    @quality = {
      total: agent_messages.count,
      claude: agent_messages.where("metadata->>'source' = ?", "claude").count,
      fallback: agent_messages.where("metadata->>'source' = ?", "knowledge_base").count,
      escalations: agent_messages.where("metadata->>'escalate' = ?", "true").count
    }

    if params[:filter] == "escalated"
      escalated_ids = agent_messages.where("metadata->>'escalate' = ?", "true")
                                    .distinct.pluck(:chat_conversation_id)
      @conversations = @conversations.where(id: escalated_ids)
    end

    @records = @conversations.page(params[:page]).per(50)

    @token_totals = agent_messages.select(:id, :metadata).find_each.each_with_object(input: 0, output: 0, cache_read: 0) do |message, acc|
      usage = message.metadata&.dig("usage") || {}
      acc[:input] += usage["input_tokens"].to_i
      acc[:output] += usage["output_tokens"].to_i
      acc[:cache_read] += usage["cache_read_input_tokens"].to_i
    end
  end

  def show
    @conversation = scoped_conversations.includes(:user, :chat_agent).find(params[:id])
    @messages = @conversation.chat_messages.chronological
  end

  private

  # Guest conversations (no user) are visible to Futureproof admins only.
  def scoped_conversations
    if policy.futureproof?
      ChatConversation.all
    else
      ChatConversation.joins(:user).where(users: { lender: policy.lender })
    end
  end
end
