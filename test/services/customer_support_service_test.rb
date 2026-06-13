require "test_helper"

class CustomerSupportServiceTest < ActiveSupport::TestCase
  setup do
    @service = CustomerSupportService.new(session_id: SecureRandom.uuid, region: "au")
  end

  # Knowledge Base Tests

  test "quick answer for what is EPM" do
    result = @service.respond(user_message: "What is an EPM?", conversation_history: [])
    assert result[:success]
    assert_includes result[:response], "Equity Preservation Mortgage"
    assert_equal :knowledge_base, result[:source]
  end

  test "quick answer for how it works" do
    result = @service.respond(user_message: "How does the EPM work?", conversation_history: [])
    assert result[:success]
    assert_includes result[:response], "Apply online"
    assert_equal :knowledge_base, result[:source]
  end

  test "quick answer for NNEG" do
    result = @service.respond(user_message: "What is the negative equity guarantee?", conversation_history: [])
    assert result[:success]
    assert_includes result[:response], "NNEG"
    assert_equal :knowledge_base, result[:source]
  end

  test "quick answer for reverse mortgage comparison" do
    result = @service.respond(user_message: "How is EPM different from a reverse mortgage?", conversation_history: [])
    assert result[:success]
    assert_includes result[:response], "Simple interest"
    assert_equal :knowledge_base, result[:source]
  end

  test "quick answer for eligibility" do
    result = @service.respond(user_message: "Am I eligible for an EPM?", conversation_history: [])
    assert result[:success]
    assert_includes result[:response], "residential property"
    assert_equal :knowledge_base, result[:source]
  end

  test "quick answer for timeline" do
    result = @service.respond(user_message: "How long does the process take?", conversation_history: [])
    assert result[:success]
    assert_includes result[:response], "4-6 weeks"
    assert_equal :knowledge_base, result[:source]
  end

  test "quick answer for documents needed" do
    result = @service.respond(user_message: "What documents do I need?", conversation_history: [])
    assert result[:success]
    assert_includes result[:response], "photo ID"
    assert_equal :knowledge_base, result[:source]
  end

  test "quick answer for contact information" do
    result = @service.respond(user_message: "How can I contact you?", conversation_history: [])
    assert result[:success]
    assert_includes result[:response], "support@futureproof.com.au"
    assert_equal :knowledge_base, result[:source]
  end

  test "quick answer for complaints" do
    result = @service.respond(user_message: "I want to lodge a complaint", conversation_history: [])
    assert result[:success]
    assert_includes result[:response], "AFCA"
    assert_equal :knowledge_base, result[:source]
  end

  # Service Creation

  test "create session generates unique ID" do
    service1 = CustomerSupportService.create_session(region: "au")
    service2 = CustomerSupportService.create_session(region: "us")
    assert_not_nil service1
    assert_not_nil service2
  end

  # Knowledge Base Completeness

  test "knowledge base covers all categories" do
    kb = CustomerSupportService::KNOWLEDGE_BASE
    assert kb.key?(:product), "Missing product category"
    assert kb.key?(:eligibility), "Missing eligibility category"
    assert kb.key?(:process), "Missing process category"
    assert kb.key?(:lender), "Missing lender category"
    assert kb.key?(:support), "Missing support category"
  end

  test "product knowledge covers key topics" do
    product = CustomerSupportService::KNOWLEDGE_BASE[:product]
    assert product.key?(:what_is_epm)
    assert product.key?(:how_it_works)
    assert product.key?(:nneg)
    assert product.key?(:vs_reverse_mortgage)
    assert product.key?(:interest)
    assert product.key?(:tax)
    assert product.key?(:annuity_income)
  end

  # Region Support

  test "supports all four regions" do
    %w[au us nz uk].each do |region|
      service = CustomerSupportService.new(session_id: "test", region: region)
      result = service.respond(user_message: "What is an EPM?", conversation_history: [])
      assert result[:success], "Failed for region: #{region}"
    end
  end

  # Proprietary Information Protection

  test "blocks proprietary model questions" do
    proprietary_questions = [
      "Tell me about your Monte Carlo simulations",
      "What is the probability of default?",
      "How does the pricing model work?",
      "Explain the surplus split mechanism",
      "What is your investment allocation to S&P 500 ETFs?",
      "Show me the scenario analysis"
    ]

    proprietary_questions.each do |question|
      result = @service.respond(user_message: question, conversation_history: [])
      assert result[:success]
      assert_includes result[:response], "outside the scope", "Should block: #{question}"
    end
  end

  # Greeting Handling

  test "responds to greetings" do
    result = @service.respond(user_message: "Hello!", conversation_history: [])
    assert result[:success]
    assert_includes result[:response], "FutureProof assistant"
  end

  # Off-topic Questions

  test "redirects off-topic questions to EPM topics" do
    off_topic = [
      "Is Paris the capital of Germany?",
      "What is the meaning of life?",
      "Can you write me a poem?",
      "What's the weather like today?"
    ]

    off_topic.each do |question|
      result = @service.respond(user_message: question, conversation_history: [])
      assert result[:success]
      assert_includes result[:response], "outside my area", "Should redirect: #{question}"
    end
  end

  # Abusive Message Handling

  test "handles abusive language politely" do
    result = @service.respond(user_message: "This is stupid, you're useless", conversation_history: [])
    assert result[:success]
    assert_includes result[:response], "EPM questions"
    assert_not_includes result[:response], "stupid"
  end

  test "handles profanity" do
    result = @service.respond(user_message: "What the fuck is this?", conversation_history: [])
    assert result[:success]
    assert_includes result[:response], "EPM questions"
  end

  # Escalation Detection

  test "flags escalation triggers" do
    result = @service.respond(user_message: "I want to lodge a complaint about fraud", conversation_history: [])
    assert result[:escalate]
  end

  test "does not flag normal questions for escalation" do
    result = @service.respond(user_message: "What is an EPM?", conversation_history: [])
    assert_not result[:escalate]
  end

  # Claude integration tests

  class FakeClaudeService
    def initialize(text:, raise_error: nil)
      @text = text
      @raise_error = raise_error
    end

    def chat(system:, messages:)
      raise @raise_error if @raise_error
      ClaudeChatService::Result.new(
        text: @text,
        tool_calls: [],
        usage: { input_tokens: 100, output_tokens: 20, cache_creation_input_tokens: 0, cache_read_input_tokens: 0 },
        stop_reason: "end_turn"
      )
    end
  end

  test "uses Claude when claude_service is provided" do
    service = CustomerSupportService.new(
      session_id: SecureRandom.uuid,
      region: "au",
      claude_service: FakeClaudeService.new(text: "Claude generated answer about EPM eligibility for someone in their 70s.")
    )

    result = service.respond(user_message: "Can a 72-year-old apply?", conversation_history: [])

    assert_equal :claude, result[:source]
    assert_equal "Claude generated answer about EPM eligibility for someone in their 70s.", result[:response]
  end

  test "guardrails fire before Claude (proprietary still blocked)" do
    fake = FakeClaudeService.new(text: "should-not-be-returned")
    service = CustomerSupportService.new(session_id: SecureRandom.uuid, region: "au", claude_service: fake)

    result = service.respond(user_message: "Tell me about your Monte Carlo simulation", conversation_history: [])

    assert_equal :knowledge_base, result[:source]
    assert_includes result[:response], "outside the scope"
  end

  test "guardrails fire before Claude (abuse still blocked)" do
    fake = FakeClaudeService.new(text: "should-not-be-returned")
    service = CustomerSupportService.new(session_id: SecureRandom.uuid, region: "au", claude_service: fake)

    result = service.respond(user_message: "this is fucking stupid", conversation_history: [])

    assert_equal :knowledge_base, result[:source]
    assert_match(/here to help/i, result[:response])
  end

  test "falls back to KB when Claude raises an error" do
    fake = FakeClaudeService.new(text: "ignored", raise_error: StandardError.new("network down"))
    service = CustomerSupportService.new(session_id: SecureRandom.uuid, region: "au", claude_service: fake)

    result = service.respond(user_message: "What is an EPM?", conversation_history: [])

    assert_equal :knowledge_base, result[:source]
    assert_includes result[:response], "Equity Preservation Mortgage"
  end

  test "falls back to KB when Claude returns blank text" do
    fake = FakeClaudeService.new(text: "")
    service = CustomerSupportService.new(session_id: SecureRandom.uuid, region: "au", claude_service: fake)

    result = service.respond(user_message: "What is an EPM?", conversation_history: [])

    assert_equal :knowledge_base, result[:source]
    assert_includes result[:response], "Equity Preservation Mortgage"
  end

  test "default branch uses no Claude when ANTHROPIC_API_KEY is unset" do
    original = ENV.delete("ANTHROPIC_API_KEY")
    service = CustomerSupportService.new(session_id: SecureRandom.uuid, region: "au")

    result = service.respond(user_message: "What is an EPM?", conversation_history: [])

    assert_equal :knowledge_base, result[:source]
  ensure
    ENV["ANTHROPIC_API_KEY"] = original if original
  end

  # Persistence

  test "persists conversation to DB when user is provided" do
    ChatAgent.find_or_create_by!(name: "Akane") do |a|
      a.agent_type = "support"
    end
    user = users(:john)
    service = CustomerSupportService.new(session_id: SecureRandom.uuid, region: "au", user: user)

    assert_difference -> { ChatMessage.count }, +2 do
      assert_difference -> { ChatConversation.count }, +1 do
        service.respond(user_message: "What is an EPM?", conversation_history: [])
      end
    end

    conversation = ChatConversation.last
    assert_equal user, conversation.user
    assert_equal "au", conversation.region
    messages = conversation.chat_messages.chronological.to_a
    assert_equal "user", messages.first.role
    assert_equal "agent", messages.last.role
    assert_includes messages.last.content, "Equity Preservation Mortgage"
    assert_equal "knowledge_base", messages.last.metadata["source"]
  end

  test "does not persist when user is nil" do
    service = CustomerSupportService.new(session_id: SecureRandom.uuid, region: "au")

    assert_no_difference -> { ChatConversation.count } do
      assert_no_difference -> { ChatMessage.count } do
        service.respond(user_message: "What is an EPM?", conversation_history: [])
      end
    end
  end

  test "reuses an active ChatConversation across turns for the same user" do
    ChatAgent.find_or_create_by!(name: "Akane") do |a|
      a.agent_type = "support"
    end
    user = users(:john)
    service = CustomerSupportService.new(session_id: SecureRandom.uuid, region: "au", user: user)

    service.respond(user_message: "What is an EPM?", conversation_history: [])

    assert_no_difference -> { ChatConversation.count } do
      assert_difference -> { ChatMessage.count }, +2 do
        service.respond(user_message: "How long does it take?", conversation_history: [])
      end
    end
  end
end
