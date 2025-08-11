require 'test_helper'

class SimpleVerificationTest < ActionDispatch::IntegrationTest
  def teardown
    # Clean up any users we create
    User.where(email: ['unverified@example.com', 'verified@example.com', 'unverified2@example.com', 'verified2@example.com']).delete_all
  end
  test "unverified user cannot access dashboard" do
    # Create a user without confirmation
    user = User.create!(
      email: 'unverified@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      country_of_residence: 'US',
      confirmed_at: nil  # Not verified
    )
    
    # Sign in the user
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
    
    # Should be redirected to verification page, not dashboard
    assert_redirected_to new_user_verification_path
    assert_equal "Please verify your email address to access your account.", flash[:notice]
  end

  test "verified user can access dashboard" do
    # Create a verified user
    user = User.create!(
      email: 'verified@example.com',
      password: 'password123',
      first_name: 'Verified',
      last_name: 'User',
      country_of_residence: 'US',
      confirmed_at: 1.day.ago  # Verified
    )
    
    # Sign in the user
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
    
    # Should be redirected to dashboard
    assert_redirected_to dashboard_path
  end

  test "unverified user gets redirected when trying to access dashboard directly" do
    # Create and sign in unverified user
    user = User.create!(
      email: 'unverified2@example.com',
      password: 'password123',
      first_name: 'Test',
      last_name: 'User2',
      country_of_residence: 'US',
      confirmed_at: nil
    )
    
    # Sign in
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
    
    # Try to access dashboard directly
    get dashboard_path
    
    # Should be redirected to verification
    assert_redirected_to new_user_verification_path
    assert_equal "Please verify your email address before accessing your account.", flash[:alert]
  end

  test "verified user can access dashboard directly" do
    # Create and sign in verified user
    user = User.create!(
      email: 'verified2@example.com',
      password: 'password123',
      first_name: 'Verified',
      last_name: 'User2',
      country_of_residence: 'US',
      confirmed_at: 1.day.ago
    )
    
    # Sign in
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
    
    # Access dashboard directly
    get dashboard_path
    
    # Should work fine
    assert_response :success
  end

  test "anonymous user redirected to sign in not verification" do
    get dashboard_path
    
    # Should go to sign in, not verification
    assert_redirected_to new_user_session_path
  end

  test "user can access devise pages without verification" do
    get new_user_registration_path
    assert_response :success
    
    get new_user_session_path  
    assert_response :success
    
    get new_user_password_path
    assert_response :success
  end

  test "user can access verification page" do
    get new_user_verification_path
    assert_response :success
  end
end