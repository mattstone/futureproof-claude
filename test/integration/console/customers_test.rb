require "test_helper"

class Console::CustomersTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
  end

  # --- Users show & security ---------------------------------------------------

  test "user show renders identity, security panel and applications" do
    user = users(:regular_user)
    get console_user_path(user)

    assert_response :success
    assert_select ".console-card-title", text: "Identity"
    assert_select ".console-card-title", text: "Security"
    assert_select "form[action=?]", lock_console_user_path(user)
    assert_select "form[action=?]", send_reset_password_console_user_path(user)
  end

  test "lock and unlock are applied and audit-logged" do
    user = users(:regular_user)

    assert_difference -> { AuditLog.count }, 1 do
      post lock_console_user_path(user)
    end
    assert user.reload.access_locked?

    post unlock_console_user_path(user)
    assert_not user.reload.access_locked?
  end

  test "send reset password emails the user and logs" do
    user = users(:regular_user)
    assert_emails 1 do
      post send_reset_password_console_user_path(user)
    end
    assert_redirected_to console_user_path(user)
  end

  test "edit updates identity fields" do
    user = users(:regular_user)
    patch console_user_path(user), params: { user: { first_name: "Renamed", last_name: "Person", email: user.email, country_of_residence: "Australia" } }
    assert_redirected_to console_user_path(user)
    assert_equal "Renamed", user.reload.first_name
  end

  test "lender admins cannot toggle the admin flag" do
    sign_in users(:lender_admin_user)
    target = users(:lender_admin_user)

    patch console_user_path(target), params: { user: { first_name: target.first_name, last_name: target.last_name, email: target.email, admin: "0" } }
    assert target.reload.admin?, "admin flag should be ignored for lender admins"
  end

  # --- Chat conversations ---------------------------------------------------------

  test "conversation index shows quality stats and table" do
    get console_chat_conversations_path

    assert_response :success
    assert_select ".console-stat-label", text: "Agent messages"
    assert_select ".console-stat-label", text: /Escalations/
    assert_select "td", text: users(:regular_user).email
  end

  test "escalated filter narrows the list" do
    get console_chat_conversations_path(filter: "escalated")
    assert_response :success
    # fixture conversation has no escalation flag, so it disappears
    assert_select "td", { text: users(:regular_user).email, count: 0 }
  end

  test "transcript renders messages with source and prompt chips" do
    conversation = chat_conversations(:support_conversation)
    get console_chat_conversation_path(conversation)

    assert_response :success
    assert_select ".console-message", count: 2
    assert_select ".console-chat-meta", text: /claude/
    assert_select "code.console-prompt-chip", text: /support_chat@abc1234/
  end

  test "lender admin cannot see other lenders' conversations" do
    sign_in users(:lender_admin_user)
    get console_chat_conversation_path(chat_conversations(:support_conversation))
    assert_response :not_found
  end
end
