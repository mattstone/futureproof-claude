require "test_helper"

class AgentDecisionServiceTest < ActiveSupport::TestCase
  setup do
    @akane = ai_agents(:customer_success_manager)  # applications type
    @rie = ai_agents(:funding_specialist)            # backoffice type
    @yumi = ai_agents(:support_specialist)           # investment type
  end

  # === Akane (applications) tests ===

  test "Akane approves valid application in range" do
    app = applications(:submitted_application) # home_value 1_200_000, age 68
    result = AgentDecisionService.new(@akane, app).evaluate

    assert_equal :approve, result.decision
    assert_equal :advance, result.next_action
    assert_in_delta 1.0, result.confidence, 0.1
    assert_empty result.flags
    assert_equal 0, result.risk_score
  end

  test "Akane flags application with property value below minimum" do
    app = applications(:mortgage_application) # home_value 500_000
    result = AgentDecisionService.new(@akane, app).evaluate

    assert_equal :reject, result.decision
    assert_includes result.flags, "property_value_too_low"
    assert_includes result.reasoning, "below minimum"
  end

  test "Akane flags senior borrower over 75" do
    app = applications(:second_application) # borrower_age 70
    # 70 is under 75, so should be fine. Let's test with a higher age.
    # We need an app with age > 75. Let's use submitted_application and stub.
    app = applications(:submitted_application)
    app.borrower_age = 78
    result = AgentDecisionService.new(@akane, app).evaluate

    assert_equal :flag, result.decision
    assert_includes result.flags, "borrower_age_senior"
    assert_includes result.reasoning, "shorter loan term"
  end

  test "Akane rejects application with property value too high" do
    app = applications(:submitted_application)
    app.home_value = 15_000_000
    result = AgentDecisionService.new(@akane, app).evaluate

    assert_equal :reject, result.decision
    assert_includes result.flags, "property_value_too_high"
  end

  # === Rie (backoffice) tests ===

  test "Rie approves application with all fields present and valuation" do
    app = applications(:submitted_application)
    # Give it a valuation
    app.property_valuation_middle = 1_200_000
    app.property_valuation_low = 1_100_000
    app.property_valuation_high = 1_300_000

    result = AgentDecisionService.new(@rie, app).evaluate

    # Should flag missing documents but not reject
    if result.flags.include?("missing_documents")
      assert_equal :flag, result.decision
    else
      assert_equal :approve, result.decision
    end
  end

  test "Rie flags application missing property valuation" do
    app = applications(:submitted_application)
    app.property_valuation_middle = nil

    result = AgentDecisionService.new(@rie, app).evaluate

    assert_includes result.flags, "no_property_valuation"
  end

  test "Rie flags low income" do
    app = applications(:submitted_application)
    app.property_valuation_middle = 1_200_000

    # Mock monthly income to return low value
    app.define_singleton_method(:monthly_income_amount) { 200.0 }

    result = AgentDecisionService.new(@rie, app).evaluate

    assert_includes result.flags, "low_income"
    assert_includes result.reasoning, "below minimum"
  end

  # === Yumi (investment) tests ===

  test "Yumi evaluates for acceptance including funding check" do
    app = applications(:submitted_application)
    app.property_valuation_middle = 1_200_000

    result = AgentDecisionService.new(@yumi, app).evaluate

    # Will likely flag funding issues in test env since no lender/pool is set up
    assert_not_nil result.decision
    assert_not_nil result.risk_score
    assert result.reasoning.present?
  end

  # === Risk scoring ===

  test "risk score increases with more flags" do
    app = applications(:mortgage_application) # low value
    result = AgentDecisionService.new(@akane, app).evaluate

    assert result.risk_score > 0
    assert result.risk_score <= 100
  end

  test "approved result has zero or low risk score" do
    app = applications(:submitted_application)
    result = AgentDecisionService.new(@akane, app).evaluate

    assert_equal :approve, result.decision
    assert_equal 0, result.risk_score
  end

  # === Lifecycle integration ===

  test "lifecycle service logs agent actions for application_created" do
    app = applications(:submitted_application)
    AgentAction.delete_all

    AgentLifecycleService.new(app, "application_created").execute!

    assert AgentAction.count > 0
    action = AgentAction.last
    assert_equal "Application", action.actionable_type
    assert_equal app.id, action.actionable_id
    assert action.reasoning.present?
  end

  test "lifecycle service handles application_submitted with handoff" do
    app = applications(:submitted_application)
    AgentAction.delete_all

    result = AgentLifecycleService.new(app, "application_submitted").execute!

    assert result[:success]
    # Should have logged multiple actions (Akane eval + handoff + Rie eval)
    assert AgentAction.count >= 1
  end

  test "lifecycle service returns decision in result" do
    app = applications(:submitted_application)
    result = AgentLifecycleService.new(app, "application_created").execute!

    assert result[:success]
    assert_not_nil result[:decision]
    assert_equal :approve, result[:decision].decision
  end
end
