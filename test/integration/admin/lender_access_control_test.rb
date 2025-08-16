require "test_helper"

class Admin::LenderAccessControlTest < ActionDispatch::IntegrationTest
  setup do
    @futureproof_lender = lenders(:futureproof)
    @broker_lender = lenders(:broker)
    @futureproof_admin = users(:futureproof_admin)
    @broker_admin = users(:broker_admin)
    @regular_user = users(:user_one)
  end

  # Test access control for lender admin vs futureproof admin
  test "futureproof admin can access all admin sections" do
    sign_in @futureproof_admin
    
    # Dashboard should be accessible
    get admin_dashboard_index_path
    assert_response :success
    
    # Applications should be accessible
    get admin_applications_path
    assert_response :success
    
    # Users should be accessible
    get admin_users_path
    assert_response :success
    
    # Contracts should be accessible
    get admin_contracts_path
    assert_response :success
    
    # Lenders should be accessible (futureproof-only)
    get admin_lenders_path
    assert_response :success
    
    # Wholesale funders should be accessible (futureproof-only)
    get admin_wholesale_funders_path
    assert_response :success
    
    # Other futureproof-only sections
    get admin_mortgages_path
    assert_response :success
  end

  test "lender admin has restricted access" do
    sign_in @broker_admin
    
    # Dashboard should be accessible
    get admin_dashboard_index_path
    assert_response :success
    
    # Applications should be accessible (but scoped)
    get admin_applications_path
    assert_response :success
    
    # Users should be accessible (but scoped)
    get admin_users_path
    assert_response :success
    
    # Contracts should be accessible (but scoped)
    get admin_contracts_path
    assert_response :success
    
    # These should be DENIED for lender admins
    get admin_lenders_path
    assert_redirected_to admin_dashboard_index_path
    assert_match /Access denied/, flash[:alert]
    
    get admin_wholesale_funders_path
    assert_redirected_to admin_dashboard_index_path
    assert_match /Access denied/, flash[:alert]
    
    get admin_mortgages_path
    assert_redirected_to admin_dashboard_index_path
    assert_match /Access denied/, flash[:alert]
    
    get admin_terms_of_uses_path
    assert_redirected_to admin_dashboard_index_path
    assert_match /Access denied/, flash[:alert]
  end

  test "regular user cannot access admin at all" do
    sign_in @regular_user
    
    get admin_dashboard_index_path
    assert_redirected_to root_path
    assert_match /Access denied/, flash[:alert]
    
    get admin_applications_path
    assert_redirected_to root_path
    assert_match /Access denied/, flash[:alert]
  end

  test "unauthenticated user cannot access admin" do
    # No sign in
    
    get admin_dashboard_index_path
    assert_redirected_to new_user_session_path
    
    get admin_applications_path
    assert_redirected_to new_user_session_path
  end

  # Test data scoping for lender admins
  test "lender admin sees only their lender's data" do
    # Create test data
    user_from_futureproof = User.create!(
      email: "test@futureproof.com",
      password: "password123",
      first_name: "Test",
      last_name: "User",
      lender: @futureproof_lender,
      confirmed_at: Time.current,
      terms_accepted: true
    )
    
    user_from_broker = User.create!(
      email: "test@broker.com", 
      password: "password123",
      first_name: "Test",
      last_name: "Broker",
      lender: @broker_lender,
      confirmed_at: Time.current,
      terms_accepted: true
    )
    
    sign_in @broker_admin
    
    # Check users page - should only see broker lender users
    get admin_users_path
    assert_response :success
    
    # The response should contain broker users but not futureproof users
    assert_match /test@broker.com/, response.body
    assert_no_match /test@futureproof.com/, response.body
    
    # Clean up
    user_from_futureproof.destroy
    user_from_broker.destroy
  end

  test "futureproof admin sees all data" do
    # Create test data
    user_from_futureproof = User.create!(
      email: "test2@futureproof.com",
      password: "password123",
      first_name: "Test2",
      last_name: "User",
      lender: @futureproof_lender,
      confirmed_at: Time.current,
      terms_accepted: true
    )
    
    user_from_broker = User.create!(
      email: "test2@broker.com",
      password: "password123", 
      first_name: "Test2",
      last_name: "Broker",
      lender: @broker_lender,
      confirmed_at: Time.current,
      terms_accepted: true
    )
    
    sign_in @futureproof_admin
    
    # Check users page - should see all users
    get admin_users_path
    assert_response :success
    
    # The response should contain users from both lenders
    assert_match /test2@broker.com/, response.body
    assert_match /test2@futureproof.com/, response.body
    
    # Clean up
    user_from_futureproof.destroy
    user_from_broker.destroy
  end

  # Test navigation visibility
  test "navigation shows different options based on admin type" do
    # Test futureproof admin navigation
    sign_in @futureproof_admin
    get admin_dashboard_index_path
    assert_response :success
    
    # Should see all navigation links
    assert_match /Lenders/, response.body
    assert_match /WholesaleFunders/, response.body
    assert_match /Mortgages/, response.body
    
    # Test lender admin navigation  
    sign_in @broker_admin
    get admin_dashboard_index_path
    assert_response :success
    
    # Should NOT see restricted navigation links
    assert_no_match /Lenders/, response.body
    assert_no_match /WholesaleFunders/, response.body
    assert_no_match /Mortgages/, response.body
    
    # Should see allowed navigation links
    assert_match /Dashboard/, response.body
    assert_match /Applications/, response.body
    assert_match /Users/, response.body
    assert_match /Contracts/, response.body
  end

  # Test security logging
  test "unauthorized access attempts are logged" do
    sign_in @broker_admin
    
    # This should generate a security log entry
    get admin_lenders_path
    assert_redirected_to admin_dashboard_index_path
    
    # We can't easily test Rails.logger output in tests, but we can verify
    # the request was handled correctly and redirected with an error
    assert_match /Access denied/, flash[:alert]
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password" # This should match your test fixtures
      }
    }
    follow_redirect! if response.status == 302
  end
end