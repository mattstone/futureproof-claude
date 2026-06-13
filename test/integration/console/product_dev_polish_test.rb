require "test_helper"

class Console::ProductDevPolishTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
  end

  # --- Email template change history ---------------------------------------------

  test "email template page shows change history with a content diff" do
    template = email_templates(:verification_template)
    template.email_template_versions.create!(user: users(:admin_user), action: "updated",
                                             change_details: "Reworded intro",
                                             previous_content: "Old body", new_content: "New body",
                                             previous_subject: "Old subject", new_subject: "New subject")

    get console_email_template_path(template)
    assert_select ".console-card-title", text: "Change history"
    assert_match "Reworded intro", response.body
    assert_match "View content change", response.body
    assert_match "Old body", response.body
    assert_match "New body", response.body
  end

  # --- Prompt change requests ------------------------------------------------------

  test "change request index has a When column with the time" do
    get console_prompt_change_requests_path
    assert_select "th", text: "When"
  end

  test "change request show surfaces GitHub state freshness when linked" do
    req = prompt_change_requests(:wording_request)
    req.update_columns(github_url: "https://github.com/x/y/issues/1", github_number: 1,
                       github_type: "issue", state_cache: "open", state_checked_at: 2.hours.ago)

    get console_prompt_change_request_path(req)
    assert_select ".console-card-title", text: "GitHub status"
    assert_select ".console-dl-term", text: "Last checked"
  end

  # --- Audit log Region column -----------------------------------------------------

  test "audit log index shows the Region column" do
    get console_audit_logs_path
    assert_select "th", text: "Region"
  end

  # --- Diagnostics -----------------------------------------------------------------

  test "diagnostics offers application, database and view error triggers" do
    get console_diagnostics_path
    assert_select "form[action=?]", console_diagnostics_test_error_path
    assert_select "form[action=?]", console_diagnostics_test_database_error_path
    assert_select "form[action=?]", console_diagnostics_test_view_error_path
  end

  test "error triggers are refused outside production" do
    post console_diagnostics_test_database_error_path
    assert_redirected_to console_diagnostics_path
    assert_match(/only available in production/, flash[:alert])
  end
end
