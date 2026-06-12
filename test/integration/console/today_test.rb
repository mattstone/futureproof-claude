require "test_helper"

class Console::TodayTest < ActionDispatch::IntegrationTest
  test "futureproof admin sees the full work queue with attention signals" do
    sign_in users(:admin_user)
    get console_root_path

    assert_response :success
    assert_select ".console-stat", count: 5
    assert_select ".console-stat-label", text: "Applications awaiting decision"
    assert_select ".console-stat-label", text: "Open change requests"
    assert_select ".console-card-title", text: "Needs attention"
    assert_select ".console-attention"
  end

  test "lender admin sees their own queue and no platform signals" do
    sign_in users(:lender_admin_user)
    get console_root_path

    assert_response :success
    assert_select ".console-stat", count: 3
    assert_select ".console-stat-label", { text: "Open change requests", count: 0 }
    assert_select ".console-attention", count: 0
  end
end
