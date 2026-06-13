require "test_helper"

class Admin::ScorecardsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    sign_in @admin
  end

  test "GET /admin/brokers/scorecard renders" do
    get scorecard_admin_brokers_path

    assert_response :success
    assert_match "Broker Scorecard", response.body
    assert_select "table.admin-table"
  end

  test "broker scorecard shows referral counts and approval rate" do
    get scorecard_admin_brokers_path
    assert_response :success

    assert_select "thead th", text: /30d/
    assert_select "thead th", text: /90d/
    assert_select "thead th", text: /Approval rate/
    assert_select "thead th", text: /Commission earned/
  end

  test "GET /admin/lenders/scorecard renders" do
    get scorecard_admin_lenders_path

    assert_response :success
    assert_match "Lender Capacity", response.body
    assert_select "table.admin-table"
  end

  test "lender scorecard shows utilisation and weighted cost of capital" do
    get scorecard_admin_lenders_path
    assert_response :success

    assert_select "thead th", text: /Utilisation/
    assert_select "thead th", text: /Weighted cost of capital/
    assert_match "Concentration index", response.body
  end

  test "GET /admin/cohorts renders the vintage report" do
    get admin_cohorts_path

    assert_response :success
    assert_match "Vintage Cohort Report", response.body
    assert_select "table.admin-table"
  end

  test "non-admin users are redirected from all three reports" do
    sign_out @admin
    sign_in users(:regular_user)

    get scorecard_admin_brokers_path
    assert_response :redirect

    get scorecard_admin_lenders_path
    assert_response :redirect

    get admin_cohorts_path
    assert_response :redirect
  end
end
