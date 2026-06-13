require "test_helper"

# The Console is the primary admin surface; the legacy /admin stays live but
# deprecated, reachable only from the Console nav footer.
class Console::AdminEntryTest < ActionDispatch::IntegrationTest
  test "an admin lands on the Console after signing in" do
    user = users(:admin_user)
    user.update!(password: "Console!Entry1", password_confirmation: "Console!Entry1")
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    post user_session_path, params: {
      user: { email: user.email, password: "Console!Entry1" }
    }
    assert_redirected_to console_root_path
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "the Console nav footer links to the deprecated admin" do
    sign_in users(:admin_user)
    get console_root_path
    assert_select "a.console-nav-legacy[href='/admin']", text: /Deprecated admin/
  end

  test "the legacy admin is still reachable" do
    sign_in users(:admin_user)
    get admin_root_path
    assert_response :success
  end
end
