require "test_helper"

# Regression coverage for page errors found by crawling the admin as a real
# authenticated user (2026-06-12): pages that rendered 500s or had
# never-working forms.
class Admin::DrilldownRegressionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    sign_in users(:admin_user)
  end

  test "contract show renders with related records strip" do
    get admin_contract_path(contracts(:active_contract))
    assert_response :success
    assert_select ".related-records"
  end

  test "broker show renders (phone column, not contact_telephone)" do
    get admin_broker_path(brokers(:one))
    assert_response :success
  end

  test "broker edit form posts to the admin route and saves" do
    broker = brokers(:one)
    get edit_admin_broker_path(broker)
    assert_response :success
    assert_select "form[action=?]", admin_broker_path(broker)

    patch admin_broker_path(broker), params: { broker: { name: "Renamed Broker", phone: "0400000000" } }
    assert_redirected_to admin_broker_path(broker)
    assert_equal "Renamed Broker", broker.reload.name
  end

  test "sidebar has the Development group with prompts and external links" do
    get admin_dashboard_path
    assert_select ".admin-nav-group-header", text: "Development"
    assert_select "a[href=?]", admin_prompts_path
    assert_select "a[href='https://futureproof-staging.fly.dev']"
  end
end
