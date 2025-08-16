require "test_helper"

class Admin::WholesaleFunderIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    # Create minimal test data without fixtures
    @lender = Lender.create!(
      name: "Test Lender",
      lender_type: "lender",
      country: "Australia",
      contact_email: "test@lender.com"
    )
    
    @wholesale_funder = WholesaleFunder.create!(
      name: "Test Wholesale Funder",
      country: "Australia",
      currency: "AUD"
    )
    
    @funder_pool = FunderPool.create!(
      wholesale_funder: @wholesale_funder,
      name: "Test Pool",
      amount: 100000
    )
    
    @admin_user = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "Admin",
      user_type: "futureproof_admin"
    )
  end

  def teardown
    # Cleanup test data
    LenderFunderPool.where(lender: @lender).destroy_all
    LenderWholesaleFunder.where(lender: @lender).destroy_all
    @funder_pool&.destroy
    @wholesale_funder&.destroy
    @lender&.destroy
    @admin_user&.destroy
  end

  test "lender show page displays wholesale funder selection interface" do
    sign_in(@admin_user)
    
    get admin_lender_path(@lender)
    assert_response :success
    
    # Check for wholesale funder selection elements
    assert_select "button#toggle-wholesale-funder-selection"
    assert_select "div#wholesale-funder-selection"
    assert_select "div#available-wholesale-funders"
  end

  test "available_wholesale_funders endpoint returns json data" do
    sign_in(@admin_user)
    
    get available_wholesale_funders_admin_lender_path(@lender), 
        headers: { "Accept" => "application/json" }
    
    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type
    
    json_response = JSON.parse(response.body)
    assert json_response.key?("wholesale_funders")
    assert json_response["wholesale_funders"].is_a?(Array)
    
    # Should include our test wholesale funder
    wholesale_funder_ids = json_response["wholesale_funders"].map { |wf| wf["id"] }
    assert_includes wholesale_funder_ids, @wholesale_funder.id
  end

  test "pool toggle creates new relationship when none exists" do
    sign_in(@admin_user)
    
    assert_difference("LenderFunderPool.count") do
      post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
           params: { funder_pool_id: @funder_pool.id }, 
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    
    relationship = LenderFunderPool.find_by(lender: @lender, funder_pool: @funder_pool)
    assert relationship
    assert relationship.active?
  end

  test "pool toggle deactivates existing relationship" do
    sign_in(@admin_user)
    
    # Create existing active relationship
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
    
    assert_response :success
    
    relationship.reload
    assert_not relationship.active?
  end

  test "pool toggle activates inactive relationship" do
    sign_in(@admin_user)
    
    # Create existing inactive relationship
    relationship = LenderFunderPool.create!(
      lender: @lender,
      funder_pool: @funder_pool,
      active: false
    )
    
    post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
         params: { funder_pool_id: @funder_pool.id }, 
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    
    relationship.reload
    assert relationship.active?
  end

  test "add wholesale funder creates relationship" do
    sign_in(@admin_user)
    
    assert_difference("LenderWholesaleFunder.count") do
      post add_wholesale_funder_admin_lender_wholesale_funders_path(@lender), 
           params: { wholesale_funder_id: @wholesale_funder.id },
           headers: { "Accept" => "application/json" }
    end
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_includes json_response["message"], @wholesale_funder.name
    
    relationship = LenderWholesaleFunder.find_by(
      lender: @lender, 
      wholesale_funder: @wholesale_funder
    )
    assert relationship
    assert relationship.active?
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }
  end
end