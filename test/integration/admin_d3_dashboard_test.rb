require 'test_helper'

class AdminD3DashboardTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_user)
    sign_in @admin

    # Create some test data
    @user1 = User.create!(
      email: 'test1@example.com',
      first_name: 'Test',
      last_name: 'User1',
      country_of_residence: 'Australia',
      password: 'password',
      confirmed_at: 1.month.ago,
      terms_accepted: true,
      lender: lenders(:futureproof)
    )

    @application1 = Application.create!(
      user: @user1,
      address: "123 Test St, Sydney NSW 2000",
      home_value: 800000,
      property_state: "primary_residence",
      ownership_status: "individual",
      borrower_age: 35,
      status: 'submitted'
    )
  end

  test "admin dashboard loads with D3 controller and data attributes" do
    get admin_root_path
    assert_response :success

    # Verify D3 controller is attached
    assert_select '[data-controller="d3-dashboard"]'

    # Verify data attributes for charts are present
    assert_select '[data-d3-dashboard-application-growth-data-value]'
    assert_select '[data-d3-dashboard-conversion-growth-data-value]'
    assert_select '[data-d3-dashboard-monthly-fum-data-value]'
    assert_select '[data-d3-dashboard-cumulative-fum-data-value]'
    assert_select '[data-d3-dashboard-status-distribution-value]'
    assert_select '[data-d3-dashboard-pool-allocation-data-value]'
  end

  test "dashboard has D3 chart target elements" do
    get admin_root_path
    assert_response :success

    # Verify all D3 chart targets are present
    assert_select '[data-d3-dashboard-target="applicationGrowthChart"]'
    assert_select '[data-d3-dashboard-target="conversionChart"]'
    assert_select '[data-d3-dashboard-target="fumMonthlyChart"]'
    assert_select '[data-d3-dashboard-target="fumCumulativeChart"]'
    assert_select '[data-d3-dashboard-target="statusDistributionChart"]'
    assert_select '[data-d3-dashboard-target="poolUtilizationChart"]'
  end

  test "dashboard chart containers have proper CSS classes" do
    get admin_root_path
    assert_response :success

    # Verify D3 chart containers have the correct CSS class
    assert_select '.d3-chart', count: 6
    assert_select '.d3-chart[data-d3-dashboard-target="applicationGrowthChart"]'
    assert_select '.d3-chart[data-d3-dashboard-target="conversionChart"]'
  end

  test "dashboard data attributes contain valid JSON" do
    get admin_root_path
    assert_response :success

    response_body = response.body

    # Extract data attributes from response
    application_growth_match = response_body.match(/data-d3-dashboard-application-growth-data-value="([^"]*)"/)
    assert application_growth_match, "Application growth data attribute should be present"

    # Parse and verify JSON is valid
    growth_data = JSON.parse(CGI.unescapeHTML(application_growth_match[1]))
    assert growth_data.is_a?(Hash), "Application growth data should be a hash"

    status_distribution_match = response_body.match(/data-d3-dashboard-status-distribution-value="([^"]*)"/)
    assert status_distribution_match, "Status distribution data attribute should be present"

    status_data = JSON.parse(CGI.unescapeHTML(status_distribution_match[1]))
    assert status_data.is_a?(Hash), "Status distribution data should be a hash"
  end

  test "dashboard includes D3 chart CSS styles" do
    get admin_root_path
    assert_response :success

    # Check that the response includes references to admin CSS (which now includes D3 styles)
    response_body = response.body
    assert_match(/admin-[a-f0-9]+\.css/, response_body, "Admin CSS should be included")
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: 'password' } }
  end
end