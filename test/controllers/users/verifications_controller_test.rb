require "test_helper"

class Users::VerificationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get users_verifications_new_url
    assert_response :success
  end

  test "should get create" do
    get users_verifications_create_url
    assert_response :success
  end

  test "should get resend" do
    get users_verifications_resend_url
    assert_response :success
  end
end
