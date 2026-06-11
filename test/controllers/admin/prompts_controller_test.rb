require "test_helper"

class Admin::PromptsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @admin = users(:admin_user)
  end

  test "non-admin is blocked" do
    sign_in users(:regular_user)
    get admin_prompts_path
    assert_redirected_to root_path
  end

  test "admin sees all prompt layers and slots" do
    sign_in @admin
    get admin_prompts_path
    assert_response :success
    assert_select "h3", text: /Core/
    assert_select "h3", text: /Runtime/
    assert_select "code", text: "support_chat"
    assert_select "code", text: "master"
  end

  test "show renders the deployed content for a slot" do
    sign_in @admin
    get admin_prompt_path("support_chat")
    assert_response :success
    assert_select "pre.prompt-content", text: /HARD RULES/
  end

  test "unknown slot redirects with alert" do
    sign_in @admin
    get admin_prompt_path("bogus")
    assert_redirected_to admin_prompts_path
  end
end
