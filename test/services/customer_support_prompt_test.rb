require "test_helper"
require "tmpdir"

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

  # ============================================================
  # File-borne prompt (docs/prompts/runtime/) — golden equality
  # ============================================================

  def legacy_build(region)
    [
      CustomerSupportPrompt::PERSONA,
      "",
      CustomerSupportPrompt::GUARDRAILS,
      "",
      "## Knowledge base",
      "",
      CustomerSupportPrompt.knowledge_section,
      "",
      "## Region context",
      "",
      CustomerSupportPrompt.region_context(region)
    ].join("\n")
  end

  test "file-borne prompt byte-equals the legacy hardcoded prompt for every region" do
    %w[au us nz uk other].each do |region|
      assert_equal legacy_build(region), CustomerSupportPrompt.build(region: region),
                   "file-borne prompt diverged from legacy constants for region #{region}"
    end
  end

  test "build_with_refs records the content sha of each slot used" do
    result = CustomerSupportPrompt.build_with_refs(region: 'uk')

    assert_equal CustomerSupportPrompt.build(region: 'uk'), result[:text]
    assert_equal PromptFiles.sha(:runtime, 'support_chat'), result[:slots]['runtime/support_chat']
    assert_equal PromptFiles.sha(:runtime, 'support_chat_region_uk'), result[:slots]['runtime/support_chat_region_uk']
  end

  test "unknown region uses the default region slot" do
    result = CustomerSupportPrompt.build_with_refs(region: 'fr')

    assert result[:slots].key?('runtime/support_chat_region_default')
    assert_includes result[:text], "User region not specified"
  end

  test "falls back to hardcoded constants when prompt files are missing" do
    Dir.mktmpdir do |empty_root|
      PromptFiles.reset_cache!
      PromptFiles.root = empty_root

      result = CustomerSupportPrompt.build_with_refs(region: 'au')

      assert_equal :fallback, result[:slots]['runtime/support_chat']
      assert_equal :fallback, result[:slots]['runtime/support_chat_region_au']
      assert_includes result[:text], "You are the FutureProof assistant"
      assert_includes result[:text], "AFCA"
    end
  ensure
    PromptFiles.reset_cache!
  end
end
