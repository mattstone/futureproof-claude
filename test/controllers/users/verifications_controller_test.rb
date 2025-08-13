require "test_helper"

class Users::VerificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      first_name: 'Test',
      last_name: 'User',
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      country_of_residence: 'Australia',
      mobile_country_code: '+61',
      mobile_number: '412345678',
      terms_accepted: true
    )
  end

  test "should get new verification page" do
    get new_users_verification_path
    assert_response :success
    assert_select 'form'
  end

  test "should handle verification creation" do
    post users_verifications_path, params: {
      verification: {
        email: @user.email,
        verification_code: '123456'
      }
    }
    assert_response :redirect
  end

  test "should handle verification resend" do
    post resend_users_verifications_path, params: {
      email: @user.email
    }
    assert_response :redirect
  end
end
