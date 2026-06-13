require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    sign_in @admin
  end

  test "GET /admin renders the executive dashboard with three tiers" do
    get admin_root_path

    assert_response :success
    assert_select "section#recommendations"
    assert_select "section#financial-overview"
    assert_select "section#customer-acquisition-overview"
    assert_select "section#customer-service-overview"
    assert_select "section#risk-overview"
    assert_select "section#trends"
  end

  test "GET /admin/dashboard renders the same dashboard" do
    get admin_dashboard_path

    assert_response :success
    assert_select "div.dashboard-overview-grid"
  end

  test "dashboard does not render the deleted in-page anchor nav" do
    get admin_root_path

    assert_select "nav.dashboard-nav", count: 0
  end

  test "dashboard does not surface customer-level individual items" do
    # Customer-level items (priority inbox with per-app cards) belong on
    # /admin/customer_service, not the executive dashboard.
    get admin_root_path

    assert_select "div.priority-inbox", count: 0
    assert_select "div.priority-item", count: 0
  end

  test "overview cards link to the correct drill-down pages" do
    get admin_root_path

    assert_select "a[href=?]", scorecard_admin_lenders_path
    assert_select "a[href=?]", scorecard_admin_brokers_path
    assert_select "a[href=?]", admin_customer_service_path
    assert_select "a[href=?]", admin_cohorts_path
  end

  test "non-admin users are redirected" do
    sign_out @admin
    sign_in users(:regular_user)

    get admin_root_path
    assert_response :redirect
  end

  test "unauthenticated users are redirected to sign in" do
    sign_out @admin

    get admin_root_path
    assert_response :redirect
  end
end
