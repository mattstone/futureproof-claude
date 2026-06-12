require "test_helper"

class Admin::ChatOversightTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    sign_in users(:admin_user)
    agent = ChatAgent.first || ChatAgent.create!(name: "Akane", agent_type: "support", status: "active")
    @conversation = ChatConversation.create!(user: users(:regular_user), chat_agent: agent, status: "active", region: "au")
    @conversation.chat_messages.create!(role: "user", content: "Help")
    @conversation.chat_messages.create!(
      role: "agent", content: "Sure",
      metadata: { source: "claude", escalate: true,
                  prompt_slots: { "runtime/support_chat" => "abc123def456" } }
    )
    @kb_conversation = ChatConversation.create!(user: users(:jane), chat_agent: agent, status: "active", region: "au")
    @kb_conversation.chat_messages.create!(role: "agent", content: "KB answer", metadata: { source: "knowledge_base" })
  end

  test "index shows quality stats and escalation filter" do
    get admin_chat_conversations_path
    assert_response :success
    assert_select ".admin-stat-label", text: "Answered by Claude"
    assert_select ".admin-stat-label", text: "Knowledge-base fallbacks"
    assert_match "Escalated only", response.body
  end

  test "escalated filter narrows to escalated conversations" do
    get admin_chat_conversations_path(filter: "escalated")
    assert_response :success
    assert_match "conversation", response.body.downcase
    assert_select "a[href=?]", admin_chat_conversation_path(@conversation)
    assert_select "a[href=?]", admin_chat_conversation_path(@kb_conversation), count: 0
  end

  test "show renders prompt slot chips on agent messages" do
    get admin_chat_conversation_path(@conversation)
    assert_response :success
    assert_select "code.prompt-slot-chip", text: /support_chat@abc123d/
  end
end
