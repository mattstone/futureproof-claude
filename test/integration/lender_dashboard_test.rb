require "test_helper"

class LenderDashboardTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin_user)
    @regular_user = users(:regular_user)
    @lender = lenders(:futureproof)
    @admin_user.update!(lender: @lender)
    @regular_user.update!(lender: nil)  # Ensure regular user has no lender

    @application = applications(:mortgage_application)
    @application.update!(
      lender: @lender,
      status: :accepted,
      equity_investment_amount: 100000,
      equity_percentage: 25.5
    )

    sign_in @admin_user
  end

  test "should access lender dashboard index" do
    get lender_dashboard_index_path(region: "au")
    assert_response :success
    assert_select "h1", text: "Equity Partner Dashboard"
    assert_select "div", text: /Active Investments/
    assert_select "div", text: /Capital Deployed/
  end

  test "should show correct EPM metrics on dashboard" do
    get lender_dashboard_index_path(region: "au")
    assert_response :success
    # Should show equity investment amount, not loan amount
    assert_select "div", text: /\$100,000.00/
  end

  test "should access applications page" do
    get lender_dashboard_applications_path(region: "au")
    assert_response :success
    assert_select "h1", text: "EPM Investment Applications"
    assert_select "h3", text: "Pending Review"
    assert_select "h3", text: "Active EPM Investments"
  end

  test "should access payments/distributions page" do
    # Create test distribution
    @application.distributions.create!(
      amount: 5000,
      distribution_date: Date.current,
      status: :completed,
      payment_method: "ach"
    )

    get lender_dashboard_payments_path(region: "au")
    assert_response :success
    assert_select "h1", text: "Distribution Schedule"
    assert_select "td", text: "$5,000.00"
  end

  test "should access application detail page" do
    get lender_dashboard_application_detail_path(region: "au", id: @application.id)
    assert_response :success
  end

  test "should deny access to non-lender users" do
    sign_out @admin_user
    sign_in @regular_user

    get lender_dashboard_index_path(region: "au")
    assert_redirected_to dashboard_path
    assert_match /access denied/i, flash[:alert]
  end

  test "should show EPM terminology not loan terminology" do
    get lender_dashboard_index_path(region: "au")
    assert_response :success

    # Should use EPM terms
    response_body = response.body
    assert_includes response_body, "Equity Partner"
    assert_includes response_body, "Capital Deployed"
    assert_includes response_body, "Active Investments"

    # Should NOT use loan terms
    refute_includes response_body, "Total Loans"
    refute_includes response_body, "Loan Amount"
    refute_includes response_body, "Capital Disbursed"
  end

  test "should show correct equity investment amounts in applications" do
    get lender_dashboard_applications_path(region: "au")
    assert_response :success

    # Should display equity_investment_amount
    assert_select "td", text: "$100,000.00"
    assert_select "td", text: "25.5%"  # equity_percentage
  end

  test "should access reports page" do
    get lender_dashboard_reports_path(region: "au")
    assert_response :success
  end
end
