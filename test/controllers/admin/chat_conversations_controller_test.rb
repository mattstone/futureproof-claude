require 'test_helper'

class Admin::ChatConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    sign_in @admin

    @agent = ChatAgent.create!(name: 'Akane (test)', agent_type: 'support', status: 'active')
    @user = users(:john)
    @conversation = ChatConversation.create!(user: @user, chat_agent: @agent, region: 'au', status: 'active')
    ChatMessage.create!(chat_conversation: @conversation, role: 'user', content: 'What is EPM?')
    ChatMessage.create!(
      chat_conversation: @conversation,
      role: 'agent',
      content: 'An Equity Preservation Mortgage is...',
      metadata: {
        source: 'claude',
        usage: { 'input_tokens' => 200, 'output_tokens' => 50, 'cache_read_input_tokens' => 1000 }
      }
    )
  end

  test "GET /admin/chat_conversations renders index" do
    get admin_chat_conversations_path

    assert_response :success
    assert_match 'AI Conversations', response.body
    assert_select 'tbody tr', minimum: 1
  end

  test "index shows token totals" do
    # Computed, not hardcoded — fixtures may add agent messages with usage.
    expected_cache = ChatMessage.where(role: 'agent').sum do |m|
      m.metadata&.dig('usage', 'cache_read_input_tokens').to_i
    end

    get admin_chat_conversations_path

    assert_response :success
    assert_match ActiveSupport::NumberHelper.number_to_delimited(expected_cache), response.body
  end

  test "GET /admin/chat_conversations/:id renders transcript" do
    get admin_chat_conversation_path(@conversation)

    assert_response :success
    assert_match 'What is EPM?', response.body
    assert_match 'Equity Preservation Mortgage', response.body
    assert_match 'claude', response.body
  end

  test "non-admin users are redirected" do
    sign_out @admin
    sign_in users(:regular_user)

    get admin_chat_conversations_path
    assert_response :redirect
  end
end
