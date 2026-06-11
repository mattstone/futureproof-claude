require "test_helper"

class Admin::PromptChangeRequestsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @admin = users(:admin_user)
  end

  def valid_params(overrides = {})
    {
      prompt_change_request: {
        kind: "change_request",
        title: "Stop offering phone callbacks",
        description: "The support agent should direct users to email instead.",
        impact_answer: "wording_only",
        impact_details: ""
      }.merge(overrides)
    }
  end

  test "non-admin is blocked" do
    sign_in users(:regular_user)
    get admin_prompt_change_requests_path
    assert_redirected_to root_path
  end

  test "admin can open the new change request form with the impact question" do
    sign_in @admin
    get new_admin_prompt_change_request_path(kind: "change_request")
    assert_response :success
    assert_select "legend", text: PromptChangeRequest::IMPACT_QUESTION
  end

  test "direct edit form prefills the current deployed content" do
    sign_in @admin
    get new_admin_prompt_change_request_path(kind: "direct_edit", slot: "support_chat")
    assert_response :success
    assert_select "textarea", text: /HARD RULES/
  end

  test "create without a configured bridge fails cleanly and leaves no orphan record" do
    sign_in @admin
    assert_no_difference -> { PromptChangeRequest.count } do
      post admin_prompt_change_requests_path, params: valid_params
    end
    assert_response :unprocessable_entity
    assert_match(/not configured/, flash[:alert])
  end

  test "create with invalid impact answer re-renders with errors" do
    sign_in @admin
    assert_no_difference -> { PromptChangeRequest.count } do
      post admin_prompt_change_requests_path,
           params: valid_params(impact_answer: "affects_data", impact_details: "")
    end
    assert_response :unprocessable_entity
  end

  test "show displays the recorded impact question and answer" do
    pcr = PromptChangeRequest.create!(
      user: @admin, kind: :change_request, title: "T", description: "D",
      impact_answer: :affects_functionality, impact_details: "Changes escalation"
    )
    sign_in @admin
    get admin_prompt_change_request_path(pcr)
    assert_response :success
    assert_select "blockquote.impact-question", text: PromptChangeRequest::IMPACT_QUESTION
    assert_select "p", text: /Changes escalation/
  end
end
