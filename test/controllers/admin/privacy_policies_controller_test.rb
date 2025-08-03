require "test_helper"

class Admin::PrivacyPoliciesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_privacy_policies_index_url
    assert_response :success
  end

  test "should get show" do
    get admin_privacy_policies_show_url
    assert_response :success
  end

  test "should get new" do
    get admin_privacy_policies_new_url
    assert_response :success
  end

  test "should get create" do
    get admin_privacy_policies_create_url
    assert_response :success
  end

  test "should get edit" do
    get admin_privacy_policies_edit_url
    assert_response :success
  end

  test "should get update" do
    get admin_privacy_policies_update_url
    assert_response :success
  end

  test "should get activate" do
    get admin_privacy_policies_activate_url
    assert_response :success
  end

  test "should get preview" do
    get admin_privacy_policies_preview_url
    assert_response :success
  end
end
