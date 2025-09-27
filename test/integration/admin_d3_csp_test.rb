require 'test_helper'

class AdminD3CspTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_user)
    sign_in @admin

    # Create test data with pool allocation data that caused the utilization.toFixed error
    @wholesale_funder = WholesaleFunder.create!(
      name: "Test Funder",
      country: "Australia",
      currency: "AUD"
    )

    @funder_pool = FunderPool.create!(
      name: "Test Pool",
      wholesale_funder: @wholesale_funder,
      amount: 1000000,
      allocated: 500000
    )
  end

  test "dashboard data contains properly formatted pool allocation data" do
    get admin_root_path
    assert_response :success

    response_body = response.body

    # Extract pool allocation data
    pool_data_match = response_body.match(/data-d3-dashboard-pool-allocation-data-value="([^"]*)"/)
    assert pool_data_match, "Pool allocation data should be present"

    pool_data = JSON.parse(CGI.unescapeHTML(pool_data_match[1]))
    assert pool_data.is_a?(Array), "Pool allocation data should be an array"

    if pool_data.any?
      first_pool = pool_data.first
      assert first_pool.key?('utilization'), "Pool data should have utilization key"
      # Utilization might be string or numeric, but should be convertible to float
      utilization_value = first_pool['utilization']
      assert (utilization_value.is_a?(Numeric) || utilization_value.is_a?(String)), "Utilization should be numeric or string"
      assert !Float(utilization_value).nil?, "Utilization should be convertible to number"
      assert first_pool.key?('name'), "Pool data should have name key"
      assert first_pool.key?('allocated'), "Pool data should have allocated key"
      assert first_pool.key?('total'), "Pool data should have total key"
    end
  end

  test "dashboard renders without CSP violations in HTML structure" do
    get admin_root_path
    assert_response :success

    response_body = response.body

    # Check that no inline styles are present in D3 chart containers
    d3_chart_sections = response_body.scan(/<div[^>]*class="[^"]*d3-chart[^"]*"[^>]*>.*?<\/div>/m)

    d3_chart_sections.each do |section|
      assert_no_match(/style="[^"]*"/, section, "D3 chart containers should not have inline styles")
    end

    # Verify D3 controller is properly attached with data
    assert_match(/data-controller="d3-dashboard"/, response_body)
    assert_match(/data-d3-dashboard-application-growth-data-value/, response_body)
    assert_match(/data-d3-dashboard-pool-allocation-data-value/, response_body)
  end

  test "dashboard includes all required CSS classes for D3 styling" do
    get admin_root_path
    assert_response :success

    # Check that admin CSS is included which contains our D3 styles
    response_body = response.body
    assert_match(/admin-[a-f0-9]+\.css/, response_body, "Admin CSS should be included")
  end

  private

  def sign_in(user)
    post user_session_path, params: { user: { email: user.email, password: 'password' } }
  end
end