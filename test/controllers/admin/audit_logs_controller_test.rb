require "test_helper"

class Admin::AuditLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    sign_in @admin

    @log_a = AuditLog.create!(
      user: @admin,
      action: "view_application",
      resource_type: "Application",
      resource_id: 123,
      reason: "Reviewing pending case",
      region: "AU",
      ip_address: "10.0.0.1"
    )
    @log_b = AuditLog.create!(
      user: @admin,
      action: "export_compliance_report",
      resource_type: "LegalDocument",
      resource_id: 5,
      region: "US",
      ip_address: "10.0.0.2"
    )
  end

  test "GET /admin/audit_logs lists all entries" do
    get admin_audit_logs_path

    assert_response :success
    assert_match @log_a.action, response.body
    assert_match @log_b.action, response.body
  end

  test "filters by action" do
    get admin_audit_logs_path, params: { action_filter: "view_application" }

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody tr", text: /Application #123/
  end

  test "filters by resource_type" do
    get admin_audit_logs_path, params: { resource_type: "LegalDocument" }

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody tr", text: /LegalDocument #5/
  end

  test "filters by user_id" do
    other = users(:jane)
    AuditLog.create!(user: other, action: "sign_in", resource_type: "User", resource_id: other.id)

    get admin_audit_logs_path, params: { user_id: other.id }

    assert_response :success
    assert_select "tbody tr", count: 1
  end

  test "GET /admin/audit_logs/:id renders single entry" do
    get admin_audit_log_path(@log_a)

    assert_response :success
    assert_match "view_application", response.body
    assert_match "Reviewing pending case", response.body
  end

  test "non-admin users are redirected" do
    sign_out @admin
    sign_in users(:regular_user)

    get admin_audit_logs_path
    assert_response :redirect
  end
end
