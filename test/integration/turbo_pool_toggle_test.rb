require "test_helper"

class TurboPoolToggleTest < ActionDispatch::IntegrationTest
  def setup
    # Create test data without fixtures to avoid foreign key issues
    @admin_user = User.create!(
      email: "admin@test.com",
      password: "password123", 
      password_confirmation: "password123",
      confirmed_at: Time.current,
      futureproof_admin: true
    )
    
    @lender = Lender.create!(
      name: "Test Lender",
      email: "lender@test.com"
    )
    
    @wholesale_funder = WholesaleFunder.create!(
      name: "Test Wholesale Funder",
      country: "Australia", 
      currency: "AUD"
    )
    
    @funder_pool = FunderPool.create!(
      wholesale_funder: @wholesale_funder,
      name: "Test Pool",
      amount: 1000000,
      allocated: 0,
      total_rate: 5.0
    )
  end

  test "turbo stream toggle creates new relationship when none exists" do
    # Sign in as admin
    post user_session_path, params: {
      user: { email: @admin_user.email, password: "password123" }
    }
    
    # Ensure no existing relationship
    assert_nil LenderFunderPool.find_by(lender: @lender, funder_pool: @funder_pool)
    
    # Submit toggle request
    assert_difference("LenderFunderPool.count", 1) do
      post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
           params: { funder_pool_id: @funder_pool.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    
    # Verify relationship was created and is active
    relationship = LenderFunderPool.find_by(lender: @lender, funder_pool: @funder_pool)
    assert relationship
    assert relationship.active?
    
    # Verify turbo stream response contains updated button
    assert_includes response.body, "<turbo-stream"
    assert_includes response.body, 'action="replace"'
    assert_includes response.body, "pool-toggle-#{@funder_pool.id}"
    assert_includes response.body, "pool-toggle-btn active"
    assert_includes response.body, "Active"
    
    # Verify flash message
    assert_includes response.body, "alert alert-success"
    assert_includes response.body, "#{@funder_pool.name}"
  end

  test "turbo stream toggle deactivates existing active relationship" do
    # Sign in as admin
    post user_session_path, params: {
      user: { email: @admin_user.email, password: "password123" }
    }
    
    # Create existing active relationship
    relationship = LenderFunderPool.create!(
      lender: @lender,
      funder_pool: @funder_pool,
      active: true
    )
    
    # Submit toggle request
    assert_no_difference("LenderFunderPool.count") do
      post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
           params: { funder_pool_id: @funder_pool.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    
    assert_response :success
    
    # Verify relationship was deactivated
    relationship.reload
    assert_not relationship.active?
    
    # Verify turbo stream response contains updated button
    assert_includes response.body, "pool-toggle-btn inactive"
    assert_includes response.body, "Inactive"
    assert_includes response.body, "deactivated"
  end

  test "turbo stream toggle activates existing inactive relationship" do
    # Sign in as admin  
    post user_session_path, params: {
      user: { email: @admin_user.email, password: "password123" }
    }
    
    # Create existing inactive relationship
    relationship = LenderFunderPool.create!(
      lender: @lender,
      funder_pool: @funder_pool,
      active: false
    )
    
    # Submit toggle request
    post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
         params: { funder_pool_id: @funder_pool.id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    
    # Verify relationship was activated
    relationship.reload
    assert relationship.active?
    
    # Verify turbo stream response
    assert_includes response.body, "pool-toggle-btn active"
    assert_includes response.body, "Active"
    assert_includes response.body, "activated"
  end

  test "controller sets proper instance variables for turbo stream template" do
    # Sign in as admin
    post user_session_path, params: {
      user: { email: @admin_user.email, password: "password123" }
    }
    
    post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
         params: { funder_pool_id: @funder_pool.id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    # Verify controller assigned instance variables properly
    assert assigns(:lender)
    assert assigns(:funder_pool)
    assert assigns(:relationship)
    assert assigns(:success)
    assert assigns(:message)
    
    assert_equal @lender, assigns(:lender)
    assert_equal @funder_pool, assigns(:funder_pool)
    assert assigns(:success)
  end
end