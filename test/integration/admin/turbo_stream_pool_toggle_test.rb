require "test_helper"

class Admin::TurboStreamPoolToggleTest < ActionDispatch::IntegrationTest
  def setup
    # Create test data without relying on fixtures
    @admin_user = User.create!(
      email: "admin@test.com",
      password: "password123",
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
    
    # Sign in admin user
    post user_session_path, params: {
      user: { email: @admin_user.email, password: "password123" }
    }
  end

  test "toggle_pool responds with turbo stream format" do
    post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
         params: { funder_pool_id: @funder_pool.id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    
    # Verify turbo stream content
    assert_includes response.body, "<turbo-stream"
    assert_includes response.body, 'action="replace"'
    assert_includes response.body, "pool-toggle-#{@funder_pool.id}"
  end

  test "toggle_pool creates relationship when none exists" do
    assert_difference("LenderFunderPool.count", 1) do
      post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
           params: { funder_pool_id: @funder_pool.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    
    relationship = LenderFunderPool.find_by(lender: @lender, funder_pool: @funder_pool)
    assert relationship
    assert relationship.active?
  end

  test "toggle_pool toggles existing relationship" do
    # Create existing relationship
    relationship = LenderFunderPool.create!(
      lender: @lender,
      funder_pool: @funder_pool,
      active: true
    )
    
    assert_no_difference("LenderFunderPool.count") do
      post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
           params: { funder_pool_id: @funder_pool.id },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    
    relationship.reload
    assert_not relationship.active?
  end

  test "turbo stream response includes flash message" do
    post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
         params: { funder_pool_id: @funder_pool.id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_includes response.body, "alert alert-success"
    assert_includes response.body, @funder_pool.name
    assert_includes response.body, "activated"
  end

  test "turbo stream response updates button correctly" do
    post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
         params: { funder_pool_id: @funder_pool.id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    # Should show active button
    assert_includes response.body, "pool-toggle-btn active"
    assert_includes response.body, "<span class=\"toggle-text\">\n        Active\n      </span>"
  end

  test "JSON fallback still works" do
    post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
         params: { funder_pool_id: @funder_pool.id },
         headers: { "Accept" => "application/json" }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_includes json_response["message"], @funder_pool.name
  end
end