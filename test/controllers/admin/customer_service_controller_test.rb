require 'test_helper'

class Admin::CustomerServiceControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    sign_in @admin
  end

  test "GET /admin/customer_service renders all sections" do
    get admin_customer_service_path

    assert_response :success
    assert_select 'h2', text: /Customer Service/i
    assert_match 'Priority inbox', response.body
    assert_match 'Borrower messages awaiting reply', response.body
    assert_match 'Stalled applications', response.body
    assert_match 'Escalated chat conversations', response.body
    assert_match 'Open support tickets', response.body
  end

  test "shows health snapshot KPIs" do
    get admin_customer_service_path

    assert_response :success
    assert_match 'Open conversations', response.body
    assert_match 'Awaiting reply', response.body
    assert_match 'Avg response time', response.body
    assert_match 'Escalations this week', response.body
  end

  test "non-admin users are redirected" do
    sign_out @admin
    sign_in users(:regular_user)

    get admin_customer_service_path
    assert_response :redirect
  end

  test "unauthenticated users are redirected to sign in" do
    sign_out @admin

    get admin_customer_service_path
    assert_response :redirect
  end
end
