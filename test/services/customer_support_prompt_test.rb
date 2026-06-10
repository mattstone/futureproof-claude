require "test_helper"

class CustomerSupportPromptTest < ActiveSupport::TestCase
  test "build includes persona, guardrails, and knowledge base" do
    prompt = CustomerSupportPrompt.build(region: 'au')

    assert_includes prompt, "You are the FutureProof assistant"
    assert_includes prompt, "HARD RULES"
    assert_includes prompt, "Knowledge base"
    assert_includes prompt, "Equity Preservation Mortgage"
  end

  test "build includes proprietary guardrail" do
    prompt = CustomerSupportPrompt.build

    assert_includes prompt, "Monte Carlo"
    assert_includes prompt, "outside the scope"
  end

  test "build includes never-call-it-a-loan rule" do
    prompt = CustomerSupportPrompt.build

    assert_includes prompt, 'NEVER call the EPM a "loan"'
  end

  test "build inserts AU region context" do
    prompt = CustomerSupportPrompt.build(region: 'au')

    assert_includes prompt, 'Australia'
    assert_includes prompt, 'AFCA'
  end

  test "build inserts US region context" do
    prompt = CustomerSupportPrompt.build(region: 'us')

    assert_includes prompt, 'United States'
    assert_includes prompt, 'HECM'
  end

  test "build inserts UK region context" do
    prompt = CustomerSupportPrompt.build(region: 'uk')

    assert_includes prompt, 'FCA'
    assert_includes prompt, 'Inheritance Tax'
  end

  test "knowledge_section contains all KB categories" do
    section = CustomerSupportPrompt.knowledge_section

    CustomerSupportService::KNOWLEDGE_BASE.keys.each do |category|
      assert_includes section, category.to_s.humanize
    end
  end
end
