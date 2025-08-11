require 'test_helper'

class DashboardControllerTest < ActionDispatch::IntegrationTest
  def setup
    @verified_user = users(:john)
    @verified_user.update!(confirmed_at: 1.day.ago)
    
    @unverified_user = users(:jane)
    @unverified_user.update!(confirmed_at: nil)
  end

  test "verified user can access dashboard index" do
    sign_in @verified_user
    get dashboard_path
    
    assert_response :success
    assert_select 'h1', text: 'Dashboard'
  end

  test "unverified user cannot access dashboard index" do
    sign_in @unverified_user
    get dashboard_path
    
    assert_redirected_to new_user_verification_path
    assert_equal "Please verify your email address before accessing your account.", flash[:alert]
  end

  test "verified user can access dashboard applications section" do
    sign_in @verified_user
    get dashboard_path(section: 'applications')
    
    assert_response :success
    assert_select 'h1', text: 'My Applications'
  end

  test "unverified user cannot access dashboard applications section" do
    sign_in @unverified_user
    get dashboard_path(section: 'applications')
    
    assert_redirected_to new_user_verification_path
    assert_equal "Please verify your email address before accessing your account.", flash[:alert]
  end

  test "dashboard loads user data for verified users only" do
    sign_in @verified_user
    get dashboard_path
    
    assert_response :success
    # Check that instance variables are set
    assert_not_nil assigns(:applications)
    assert_not_nil assigns(:submitted_applications)
  end

  test "dashboard does not load user data for unverified users" do
    sign_in @unverified_user
    get dashboard_path
    
    assert_redirected_to new_user_verification_path
    # Instance variables should not be set due to early redirect
    assert_nil assigns(:applications)
    assert_nil assigns(:submitted_applications)
  end

  test "anonymous user redirected to sign in not verification" do
    get dashboard_path
    
    assert_redirected_to new_user_session_path
  end

  test "dashboard start_application action requires verification" do
    sign_in @unverified_user
    get '/start-application'
    
    assert_redirected_to new_user_verification_path
    assert_equal "Please verify your email address before accessing your account.", flash[:alert]
  end

  test "verified user can access start_application" do
    sign_in @verified_user
    get '/start-application'
    
    assert_response :success
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end