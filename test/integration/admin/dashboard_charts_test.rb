require "test_helper"

class Admin::DashboardChartsTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_user)
    sign_in @admin
  end

  test "dashboard renders with D3 chart controllers" do
    get admin_dashboard_index_path
    assert_response :success

    # Verify all 4 D3 chart elements are present
    assert_select '[data-controller="dashboard-chart"]', count: 4

    # Verify chart type attributes
    assert_select '[data-dashboard-chart-type-value="bar"]', count: 2
    assert_select '[data-dashboard-chart-type-value="area"]', count: 2

    # Verify FUM Monthly chart
    assert_select '[data-dashboard-chart-type-value="bar"]' do |elements|
      # First bar chart should be FUM Monthly
      assert elements[0].parent.parent.text.include?("Funds Under Management - Monthly")
    end

    # Verify FUM Cumulative chart
    assert_select '[data-dashboard-chart-type-value="area"]' do |elements|
      # First area chart should be FUM Cumulative
      assert elements[0].parent.parent.text.include?("Funds Under Management - Cumulative")
    end

    # Verify Application Growth chart
    assert_select '.dashboard-card' do |cards|
      growth_card = cards.find { |c| c.text.include?("Application Growth") }
      assert growth_card, "Application Growth card should exist"
      assert_select growth_card, '[data-controller="dashboard-chart"]'
    end

    # Verify Conversion Rate chart with max value
    assert_select '[data-dashboard-chart-max-value="100"]', count: 1
  end

  test "chart data is properly formatted as JSON" do
    get admin_dashboard_index_path
    assert_response :success

    # Extract one of the data attributes to verify JSON structure
    doc = Nokogiri::HTML(response.body)
    chart_element = doc.at_css('[data-dashboard-chart-data-value]')

    assert chart_element, "Chart element with data should exist"

    data_json = chart_element['data-dashboard-chart-data-value']
    data = JSON.parse(data_json)

    # Verify data structure
    assert data.is_a?(Array), "Data should be an array"

    if data.any?
      first_item = data.first
      assert first_item.key?("label"), "Each data point should have a label"
      assert first_item.key?("value"), "Each data point should have a value"
    end
  end

  test "charts have minimum height for proper rendering" do
    get admin_dashboard_index_path
    assert_response :success

    # All charts should have minimum height of 400px
    assert_select '[data-controller="dashboard-chart"][style*="min-height: 400px"]', count: 4
  end

  test "dashboard includes dashboard-chart controller in JavaScript" do
    # Verify the Stimulus controller file exists
    controller_path = Rails.root.join('app/javascript/controllers/dashboard_chart_controller.js')
    assert File.exist?(controller_path), "Dashboard chart controller should exist"

    # Verify it's a valid Stimulus controller
    content = File.read(controller_path)
    assert_match(/import.*Controller.*from.*stimulus/, content)
    assert_match(/export default class extends Controller/, content)
    assert_match(/renderBarChart/, content)
    assert_match(/renderAreaChart/, content)
  end
end