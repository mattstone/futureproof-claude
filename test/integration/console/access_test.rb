require "test_helper"

class Console::AccessTest < ActionDispatch::IntegrationTest
  test "anonymous users are sent to sign in" do
    get console_root_path
    assert_redirected_to new_user_session_path
  end

  test "non-admin users are turned away at the door" do
    sign_in users(:regular_user)
    get console_root_path
    assert_redirected_to root_path
    follow_redirect!
    assert_match "Access denied", flash[:alert]
  end

  test "futureproof admin sees the Today page" do
    sign_in users(:admin_user)
    get console_root_path
    assert_response :success
    assert_select ".console-page-title", text: "Today"
    assert_select ".console-jurisdiction-select"
  end

  test "futureproof admin can switch jurisdiction" do
    sign_in users(:admin_user)
    get console_root_path
    assert_equal "Summary", session[:console_jurisdiction]

    post console_set_jurisdiction_path, params: { jurisdiction: "AU" }
    assert_equal "AU", session[:console_jurisdiction]
  end

  test "invalid jurisdiction values are ignored" do
    sign_in users(:admin_user)
    get console_root_path
    post console_set_jurisdiction_path, params: { jurisdiction: "MARS" }
    assert_equal "Summary", session[:console_jurisdiction]
  end

  test "lender admin is pinned to their lender's country" do
    sign_in users(:lender_admin_user)
    get console_root_path
    assert_response :success
    assert_equal "AU", session[:console_jurisdiction]
    # No switcher rendered — jurisdiction shown as a fixed chip instead
    assert_select ".console-jurisdiction-select", count: 0
    assert_select ".console-jurisdiction-pinned", text: "AU"

    # And the switch endpoint refuses to move them
    post console_set_jurisdiction_path, params: { jurisdiction: "UK" }
    get console_root_path
    assert_equal "AU", session[:console_jurisdiction]
  end

  test "console uses its own session key, separate from the old admin" do
    sign_in users(:admin_user)
    post set_jurisdiction_path, params: { admin_jurisdiction: "NZ" } # old admin switcher
    get console_root_path
    assert_equal "Summary", session[:console_jurisdiction]
    assert_equal "NZ", session[:admin_jurisdiction]
  end
end
