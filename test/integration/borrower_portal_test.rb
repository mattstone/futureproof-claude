require "test_helper"

class BorrowerPortalTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:regular_user)
    @application = applications(:mortgage_application)
    @application.update!(user: @user, status: :accepted)
    @region = "au"
    sign_in @user
  end

  test "should access borrower portal dashboard" do
    get borrower_portal_path(region: @region, application_id: @application.id)
    assert_response :success
    assert_select "h1", text: "Borrower Portal"
    assert_select "div", text: /Application ##{@application.id}/
  end

  test "should access annuity schedule page" do
    get borrower_portal_annuity_schedule_path(region: @region, application_id: @application.id)
    assert_response :success
    assert_select "h1", text: "Distribution Schedule"
    assert_select "h3", text: "Investment Summary"
  end

  test "should access loan details page" do
    get borrower_portal_loan_details_path(region: @region, application_id: @application.id)
    assert_response :success
    assert_select "h1", text: "EPM Investment Details"
    assert_select "h3", text: "Investment Terms"
  end

  test "should access property details page" do
    get borrower_portal_property_details_path(region: @region, application_id: @application.id)
    assert_response :success
    assert_select "h1", text: "Property Details"
    assert_select "h3", text: "Property Information"
  end

  test "should access documents page" do
    get borrower_portal_documents_path(region: @region, application_id: @application.id)
    assert_response :success
    assert_select "h1", text: "Documents & Contracts"
    assert_select "h3", text: "Application Documents"
  end

  test "should deny access to other user's application" do
    other_user = users(:admin_user)
    other_application = applications(:second_application)
    other_application.update!(user: other_user)

    get borrower_portal_path(region: @region, application_id: other_application.id)
    assert_redirected_to dashboard_path
    assert_match /access denied/i, flash[:alert]
  end

  test "should require authentication" do
    sign_out @user
    get borrower_portal_path(region: @region, application_id: @application.id)
    assert_redirected_to new_user_session_path
  end

  test "should display distribution data on dashboard" do
    # Create test distribution
    distribution = @application.distributions.create!(
      amount: 1000.50,
      distribution_date: Date.current,
      status: :completed,
      payment_method: "ach"
    )

    get borrower_portal_path(region: @region, application_id: @application.id)
    assert_response :success
    assert_select "td", text: "$1,000.50"
    assert_select "span", text: "Completed"
  end

  test "should show EPM fields on loan details" do
    @application.update!(
      equity_investment_amount: 100000,
      equity_percentage: 25.5,
      participation_term_years: 10
    )

    get borrower_portal_loan_details_path(region: @region, application_id: @application.id)
    assert_response :success
    assert_select "span", text: "$100,000.00"
    assert_select "span", text: "25.5%"
    assert_select "span", text: "10 years"
  end

  test "should show property valuation on property details" do
    @application.update!(
      address: "123 Test Street, Sydney NSW",
      home_value: 800000,
      property_type: "house",
      property_valuation_low: 750000,
      property_valuation_middle: 800000,
      property_valuation_high: 850000
    )

    get borrower_portal_property_details_path(region: @region, application_id: @application.id)
    assert_response :success
    assert_select "span", text: "123 Test Street, Sydney NSW"
    assert_select "span", text: "$800,000.00"
    assert_select "span", text: "$750,000.00"
    assert_select "span", text: "$850,000.00"
  end
end
