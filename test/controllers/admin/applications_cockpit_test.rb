require "test_helper"

class Admin::ApplicationsCockpitTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @admin = users(:admin_user)
    sign_in @admin
    @submitted = applications(:submitted_application)
    @accepted = applications(:accepted_application)
  end

  # --- item 1: accepted applications are reachable ---

  test "default index shows the active pipeline without accepted" do
    get admin_applications_path
    assert_response :success
    assert_no_match "application-row-#{@accepted.id}", response.body
  end

  test "accepted applications are reachable via the status filter" do
    get admin_applications_path(status: "accepted")
    assert_response :success
    assert_match "application-row-#{@accepted.id}", response.body
  end

  test "search finds accepted applications by id" do
    post search_admin_applications_path(format: :turbo_stream), params: { search: @accepted.id.to_s }
    assert_response :success
    assert_match "application-row-#{@accepted.id}", response.body
  end

  # --- item 2: real approval workflow ---

  test "approve drives the full workflow and sets approved terms" do
    lender = lenders(:futureproof)
    post approve_admin_application_path(@submitted), params: {
      loan_amount: 600_000, interest_rate: 7.66, term_years: 25, lender_id: lender.id
    }
    assert_redirected_to admin_application_path(@submitted)
    @submitted.reload
    assert @submitted.status_accepted?
    assert_equal 600_000, @submitted.approved_loan_amount.to_i
    assert_equal 25, @submitted.approved_term_years
    assert_equal lender, @submitted.lender
  end

  test "approve without required fields is refused" do
    post approve_admin_application_path(@submitted), params: { loan_amount: 0 }
    assert_redirected_to admin_application_path(@submitted)
    assert_match(/needs a loan amount/, flash[:alert])
    assert_not @submitted.reload.status_accepted?
  end

  test "reject requires a reason and records it" do
    post reject_admin_application_path(@submitted), params: { rejected_reason: "" }
    assert_match(/reason is required/, flash[:alert])

    post reject_admin_application_path(@submitted), params: { rejected_reason: "Property value too low" }
    @submitted.reload
    assert @submitted.status_rejected?
    assert_equal "Property value too low", @submitted.rejected_reason
  end

  # --- item 8: quotes panel ---

  test "show renders the quotes panel with snapshots" do
    Quote.create!(application: @submitted, product_version: EpmModelConfig.model_version,
                  home_value: 1_500_000, term_years: 30, income_payout_term: 10,
                  monthly_income: 2_500, annual_income: 30_000, issued_at: Time.current)
    get admin_application_path(@submitted)
    assert_response :success
    assert_select ".quotes-panel code", text: EpmModelConfig.model_version
    assert_select ".quotes-panel", text: /2,500/
  end

  test "show renders compliance panel with not-started state" do
    get admin_application_path(@submitted)
    assert_select ".compliance-panel", text: /KYC/
    assert_select ".compliance-panel .admin-badge", text: "Not started"
  end

  # --- decision panel rendering ---

  test "decision panel offers approve and reject for submitted applications" do
    get admin_application_path(@submitted)
    assert_select ".decision-panel form[action=?]", approve_admin_application_path(@submitted)
    assert_select ".decision-panel form[action=?]", reject_admin_application_path(@submitted)
  end

  test "decision panel shows approved summary for accepted applications" do
    @accepted.update_columns(equity_investment_amount: 500_000, equity_percentage: 7.5, participation_term_years: 20)
    get admin_application_path(@accepted)
    assert_select ".decision-panel-approved", text: /Approved/
  end

  # --- agent action override ---

  test "agent action override requires a reason and records it" do
    action = AgentAction.create!(ai_agent: AiAgent.first || AiAgent.create!(name: "Test Agent", agent_type: "operations"),
                                 actionable: @submitted, action_type: "decide", decision: "flag", status: "completed")

    post override_admin_agent_action_path(action), params: { reason: "" },
         headers: { "HTTP_REFERER" => admin_application_path(@submitted) }
    assert_match(/reason is required/, flash[:alert])

    post override_admin_agent_action_path(action), params: { reason: "Manual review cleared the flag" },
         headers: { "HTTP_REFERER" => admin_application_path(@submitted) }
    action.reload
    assert_equal "overridden", action.status
    assert_equal "Manual review cleared the flag", action.override_reason
    assert AuditLog.exists?(action: "agent_action_overridden", resource_id: action.id)
  end
end
