require 'test_helper'

class EmailVerificationRequiredTest < ActionDispatch::IntegrationTest
  def setup
    @verified_user = users(:john)
    @verified_user.update!(confirmed_at: 1.day.ago)
    
    @unverified_user = users(:jane)
    @unverified_user.update!(confirmed_at: nil)
    
    @admin_user = users(:admin_user)
    @admin_user.update!(confirmed_at: 1.day.ago, admin: true)
  end

  test "verified user can access dashboard" do
    sign_in @verified_user
    get dashboard_path
    
    assert_response :success
    assert_select 'h1', text: 'Dashboard'
  end

  test "unverified user cannot access dashboard" do
    sign_in @unverified_user
    get dashboard_path
    
    assert_redirected_to new_user_verification_path
    assert_equal "Please verify your email address before accessing your account.", flash[:alert]
  end

  test "unverified user redirected to verification on sign in" do
    post user_session_path, params: {
      user: { email: @unverified_user.email, password: 'password123' }
    }
    
    assert_redirected_to new_user_verification_path
    assert_equal "Please verify your email address to access your account.", flash[:notice]
  end

  test "verified user redirected to dashboard on sign in" do
    post user_session_path, params: {
      user: { email: @verified_user.email, password: 'password123' }
    }
    
    assert_redirected_to dashboard_path
  end

  test "verified admin user redirected to admin dashboard on sign in" do
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
    
    assert_redirected_to admin_root_path
  end

  test "unverified user cannot access applications" do
    sign_in @unverified_user
    get applications_path
    
    assert_redirected_to new_user_verification_path
    assert_equal "Please verify your email address before accessing your account.", flash[:alert]
  end

  test "unverified user cannot access application details" do
    application = applications(:mortgage_application)
    sign_in @unverified_user
    get application_path(application)
    
    assert_redirected_to new_user_verification_path
    assert_equal "Please verify your email address before accessing your account.", flash[:alert]
  end

  test "unverified user can access verification pages" do
    sign_in @unverified_user
    get new_user_verification_path
    
    assert_response :success
    assert_select 'h1', text: /verify/i
  end

  test "unverified user can access devise registration pages" do
    get new_user_registration_path
    
    assert_response :success
  end

  test "unverified user can access devise session pages" do
    get new_user_session_path
    
    assert_response :success
  end

  test "unverified user can access devise password reset pages" do
    get new_user_password_path
    
    assert_response :success
  end

  test "email verification requirement blocks multiple protected routes" do
    sign_in @unverified_user
    
    protected_routes = [
      dashboard_path,
      applications_path,
      edit_user_registration_path
    ]
    
    protected_routes.each do |route|
      get route
      assert_redirected_to new_user_verification_path, 
        "Route #{route} should redirect unverified users to verification page"
      
      # Clear flash for next request
      flash.clear
    end
  end

  test "verification requirement does not affect verified users on protected routes" do
    sign_in @verified_user
    
    protected_routes = [
      dashboard_path,
      applications_path,
      edit_user_registration_path
    ]
    
    protected_routes.each do |route|
      get route
      assert_response :success, "Route #{route} should be accessible to verified users"
    end
  end

  test "user becomes verified after email confirmation" do
    # Start with unverified user
    sign_in @unverified_user
    get dashboard_path
    assert_redirected_to new_user_verification_path
    
    # Confirm the user
    @unverified_user.update!(confirmed_at: Time.current)
    
    # Now they can access dashboard
    get dashboard_path
    assert_response :success
  end

  test "admin users must still be verified" do
    unverified_admin = users(:admin_user)
    unverified_admin.update!(confirmed_at: nil, admin: true)
    
    sign_in unverified_admin
    get admin_root_path
    
    assert_redirected_to new_user_verification_path
    assert_equal "Please verify your email address before accessing your account.", flash[:alert]
  end

  test "verification check runs before other before_actions" do
    # This test ensures ensure_email_verified! runs after authenticate_user! 
    # but before other protected actions
    sign_in @unverified_user
    
    # Try to access a route that would load unread messages
    get dashboard_path
    
    # Should be redirected before any message loading happens
    assert_redirected_to new_user_verification_path
    
    # @unread_message_count should not be set since verification failed
    assert_nil assigns(:unread_message_count)
  end

  test "verification bypass works for devise controllers" do
    # Test that sign up works for unverified users
    get new_user_registration_path
    assert_response :success
    
    # Test that sign in works
    get new_user_session_path
    assert_response :success
    
    # Test password reset works
    get new_user_password_path
    assert_response :success
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end