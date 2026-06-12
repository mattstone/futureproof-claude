require "test_helper"

class Admin::UserSecurityTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @admin = users(:admin_user)
    @user = users(:regular_user)
    sign_in @admin
  end

  test "show renders the security panel with sign-in activity" do
    get admin_user_path(@user)
    assert_response :success
    assert_select ".security-panel", text: /Sign-ins/
    assert_select ".security-panel form[action=?]", lock_admin_user_path(@user)
    assert_select ".security-panel form[action=?]", send_reset_password_admin_user_path(@user)
  end

  test "lock and unlock toggle access and are audited" do
    post lock_admin_user_path(@user)
    assert @user.reload.access_locked?
    assert AuditLog.exists?(action: "user_locked", resource_id: @user.id)

    post unlock_admin_user_path(@user)
    assert_not @user.reload.access_locked?
    assert AuditLog.exists?(action: "user_unlocked", resource_id: @user.id)
  end

  test "send_reset_password emails the user and is audited" do
    assert_emails 1 do
      post send_reset_password_admin_user_path(@user)
    end
    assert AuditLog.exists?(action: "password_reset_sent", resource_id: @user.id)
  end

  test "sidebar shows attention badges when work is pending" do
    Rails.cache.delete("admin/attention_counts")
    get admin_dashboard_path
    assert_response :success
    # submitted/processing fixtures exist, so the applications badge renders
    assert_select "span.nav-badge"
  end
end
