require 'test_helper'

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  def setup
    @verified_user = users(:john)
    @verified_user.update!(confirmed_at: 1.day.ago)
    
    @unverified_user = users(:jane)
    @unverified_user.update!(confirmed_at: nil)
    
    @admin_user = users(:admin_user)
    @admin_user.update!(confirmed_at: 1.day.ago, admin: true)
  end

  test "ensure_email_verified! allows verified users" do
    sign_in @verified_user
    get dashboard_path
    
    assert_response :success
    assert_nil flash[:alert]
  end

  test "ensure_email_verified! blocks unverified users" do
    sign_in @unverified_user
    get dashboard_path
    
    assert_redirected_to new_user_verification_path
    assert_equal "Please verify your email address before accessing your account.", flash[:alert]
  end

  test "ensure_email_verified! skips check for anonymous users" do
    # Without sign in, should get redirected to sign in page, not verification
    get dashboard_path
    
    assert_redirected_to new_user_session_path
  end

  test "after_sign_in_path_for returns verification path for unverified users" do
    post user_session_path, params: {
      user: { email: @unverified_user.email, password: 'password123' }
    }
    
    assert_redirected_to new_user_verification_path
    assert_equal "Please verify your email address to access your account.", flash[:notice]
  end

  test "after_sign_in_path_for returns dashboard for verified regular users" do
    post user_session_path, params: {
      user: { email: @verified_user.email, password: 'password123' }
    }
    
    assert_redirected_to dashboard_path
  end

  test "after_sign_in_path_for returns admin root for verified admin users" do
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
    
    assert_redirected_to admin_root_path
  end

  test "after_sign_in_path_for handles pending message access for verified users" do
    # Set up pending message access
    session[:pending_message_access] = {
      'user_id' => @verified_user.id,
      'token_verified' => true,
      'expires_at' => 1.hour.from_now.to_i
    }
    
    post user_session_path, params: {
      user: { email: @verified_user.email, password: 'password123' }
    }
    
    assert_redirected_to dashboard_path
    assert_nil session[:pending_message_access]
  end

  test "after_sign_in_path_for ignores pending message access for unverified users" do
    # Set up pending message access
    session[:pending_message_access] = {
      'user_id' => @unverified_user.id,
      'token_verified' => true,
      'expires_at' => 1.hour.from_now.to_i
    }
    
    post user_session_path, params: {
      user: { email: @unverified_user.email, password: 'password123' }
    }
    
    # Should still redirect to verification, ignoring pending message access
    assert_redirected_to new_user_verification_path
    # Session should remain intact for after verification
    assert session[:pending_message_access].present?
  end

  test "verification_or_devise_controller? returns true for devise controllers" do
    # Test sign in page (devise controller)
    get new_user_session_path
    assert_response :success
  end

  test "verification_or_devise_controller? returns true for verification controller" do
    get new_user_verification_path
    assert_response :success
  end

  test "load_unread_message_count is not called for unverified users" do
    sign_in @unverified_user
    
    # Mock the method to track if it's called
    ApplicationController.any_instance.expects(:load_unread_message_count).never
    
    get dashboard_path
    
    assert_redirected_to new_user_verification_path
  end

  test "load_unread_message_count is called for verified users" do
    sign_in @verified_user
    
    get dashboard_path
    
    assert_response :success
    # The method should have run and set the instance variable
    assert_not_nil assigns(:unread_message_count)
  end

  test "multiple requests by unverified user consistently redirect to verification" do
    sign_in @unverified_user
    
    # Try multiple protected routes
    routes = [dashboard_path, applications_path, edit_user_registration_path]
    
    routes.each do |route|
      get route
      assert_redirected_to new_user_verification_path
      follow_redirect!
      assert_response :success
    end
  end

  test "verification requirement persists across session" do
    sign_in @unverified_user
    
    # Try to access dashboard
    get dashboard_path
    assert_redirected_to new_user_verification_path
    
    # Try again in same session
    get dashboard_path
    assert_redirected_to new_user_verification_path
    
    # Verify user (simulate email confirmation)
    @unverified_user.update!(confirmed_at: Time.current)
    
    # Now should be able to access
    get dashboard_path
    assert_response :success
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end