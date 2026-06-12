require "test_helper"

class Console::DevelopmentTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
  end

  # --- Prompts ----------------------------------------------------------------

  test "prompts index lists layers with open request counts" do
    get console_prompts_path
    assert_response :success
    assert_select ".console-card-title", text: "Runtime"
    assert_select ".console-badge", text: /1 open request/
  end

  test "prompt show renders deployed content and sha" do
    slot = PromptFiles.slots_for(PromptFiles::LAYERS.first).first
    get console_prompt_path(slot.key)
    assert_response :success
    assert_select "pre.console-prompt-content"
    assert_select "code.console-prompt-chip"
  end

  # --- Change requests -----------------------------------------------------------

  test "change request show records the impact verbatim" do
    request_record = prompt_change_requests(:wording_request)
    get console_prompt_change_request_path(request_record)

    assert_response :success
    assert_match PromptChangeRequest::IMPACT_QUESTION, response.body
    assert_select ".console-dl-value", text: "Wording only"
  end

  test "new change request form asks the impact question" do
    get new_console_prompt_change_request_path
    assert_response :success
    assert_match PromptChangeRequest::IMPACT_QUESTION, response.body
  end

  test "create without github bridge configured fails gracefully and keeps nothing" do
    assert_no_difference "PromptChangeRequest.count" do
      post console_prompt_change_requests_path, params: {
        prompt_change_request: {
          kind: "change_request", title: "Test", description: "Do a thing", impact_answer: "wording_only"
        }
      }
    end
    assert_response :unprocessable_entity
    assert_match(/not configured/, response.body)
  end

  # --- Audit logs -------------------------------------------------------------------

  test "audit log index filters and show parses changes" do
    get console_audit_logs_path
    assert_response :success
    assert_select "td", text: /User locked/

    get console_audit_logs_path(action_filter: "user_locked")
    assert_select "td", text: /User locked/

    get console_audit_log_path(audit_logs(:lock_event))
    assert_response :success
    assert_select ".console-dl-value", text: /Repeated failed sign-ins/
  end

  # --- Diagnostics --------------------------------------------------------------------

  test "diagnostics page renders probes and refuses error test outside production" do
    get console_diagnostics_path
    assert_response :success
    assert_select "form[action=?]", console_diagnostics_core_logic_search_path

    post console_diagnostics_test_error_path
    assert_redirected_to console_diagnostics_path
    assert_match(/only available in production/, flash[:alert])
  end

  # --- Security -------------------------------------------------------------------------

  test "security page shows lockouts and security events" do
    users(:regular_user).lock_access!(send_instructions: false)

    get console_system_security_path
    assert_response :success
    assert_select ".console-card-title", text: "Locked accounts"
    assert_select "td, li", text: /user@example.com/
    assert_select ".console-history-action", text: /user locked/
  end

  # --- Access -----------------------------------------------------------------------------

  test "lender admins are denied development and system" do
    sign_in users(:lender_admin_user)

    get console_prompts_path
    assert_redirected_to console_root_path
    get console_audit_logs_path
    assert_redirected_to console_root_path
    get console_diagnostics_path
    assert_redirected_to console_root_path
  end
end
