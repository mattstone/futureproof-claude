require 'test_helper'

class MinimalVerificationTest < ActionDispatch::IntegrationTest
  def setup
    # Clean up any existing test users
    User.where(email: ['test-unverified@example.com', 'test-verified@example.com']).destroy_all
  end

  def teardown
    # Clean up test users
    User.where(email: ['test-unverified@example.com', 'test-verified@example.com', 'test-verification@example.com']).destroy_all
  end

  test "unverified user cannot access dashboard and gets redirected" do
    # Create unverified user
    unverified_user = User.create!(
      email: 'test-unverified@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: nil
    )

    # Try to sign in
    post user_session_path, params: {
      user: { email: unverified_user.email, password: 'password123' }
    }

    # Should redirect to verification page, not dashboard
    expected_redirect = new_users_verification_path(email: unverified_user.email)
    assert_redirected_to expected_redirect
    follow_redirect!
    assert_response :success
  end

  test "verified user can access dashboard" do
    # Create verified user
    verified_user = User.create!(
      email: 'test-verified@example.com',
      password: 'password123',
      first_name: 'Verified',
      last_name: 'User',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: 1.day.ago
    )

    # Sign in
    post user_session_path, params: {
      user: { email: verified_user.email, password: 'password123' }
    }

    # Should redirect to dashboard
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
  end

  test "anonymous user can access public pages" do
    get new_user_session_path
    assert_response :success

    get new_user_registration_path
    assert_response :success

    # Create a user first to test verification page access
    user = User.create!(
      email: 'test-verification@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'Verification',
      country_of_residence: 'US',
      terms_accepted: '1',
      confirmed_at: nil
    )
    
    get new_users_verification_path(email: user.email)
    assert_response :success
    
    # Clean up
    user.destroy
  end
end