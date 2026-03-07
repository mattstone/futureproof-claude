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
    assert product.key?(:annuity_cap)
  end

  # Region Support

  test "supports all four regions" do
    %w[au us nz uk].each do |region|
      service = CustomerSupportService.new(session_id: "test", region: region)
      result = service.respond(user_message: "What is an EPM?", conversation_history: [])
      assert result[:success], "Failed for region: #{region}"
    end
  end
end
