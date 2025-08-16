require "test_helper"

class Admin::LenderWholesaleFundersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @lender = lenders(:one)
    @wholesale_funder = wholesale_funders(:one)
    @funder_pool = funder_pools(:one)
    @admin_user = users(:admin)
    sign_in @admin_user
  end

  test "should get new" do
    get new_admin_lender_wholesale_funder_path(@lender)
    assert_response :success
    assert_select ".wholesale-funders-interface"
    assert_select ".interface-instructions"
  end

  test "should create lender wholesale funder" do
    assert_difference("LenderWholesaleFunder.count") do
      post admin_lender_wholesale_funders_path(@lender), params: {
        lender_wholesale_funder: {
          wholesale_funder_id: @wholesale_funder.id,
          active: true
        }
      }
    end

    assert_redirected_to admin_lender_path(@lender)
    assert_equal "Wholesale funder relationship was successfully created.", flash[:notice]
  end

  test "should destroy lender wholesale funder" do
    lender_wholesale_funder = LenderWholesaleFunder.create!(
      lender: @lender,
      wholesale_funder: @wholesale_funder,
      active: true
    )

    assert_difference("LenderWholesaleFunder.count", -1) do
      delete admin_lender_wholesale_funder_path(@lender, lender_wholesale_funder)
    end

    assert_redirected_to admin_lender_path(@lender)
  end

  test "toggle_pool should respond to turbo_stream format" do
    post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
         params: { funder_pool_id: @funder_pool.id }, 
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
  end

  test "toggle_pool should create new lender funder pool relationship when none exists" do
    assert_difference("LenderFunderPool.count") do
      post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
           params: { funder_pool_id: @funder_pool.id }, 
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    
    relationship = LenderFunderPool.find_by(lender: @lender, funder_pool: @funder_pool)
    assert relationship
    assert relationship.active?
  end

  test "toggle_pool should toggle existing lender funder pool relationship" do
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

    assert_response :success
    
    relationship.reload
    assert_not relationship.active?
  end

  test "toggle_pool should toggle relationship back to active" do
    # Create inactive relationship
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

  test "toggle_pool should respond to json format for backward compatibility" do
    post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
         params: { funder_pool_id: @funder_pool.id }, 
         headers: { "Accept" => "application/json" }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_includes json_response["message"], @funder_pool.name
    assert json_response.key?("active")
  end

  test "toggle_pool should include flash message in turbo stream response" do
    post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
         params: { funder_pool_id: @funder_pool.id }, 
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    assert_includes response.body, "alert alert-success"
    assert_includes response.body, @funder_pool.name
  end

  test "toggle_pool should update button class in turbo stream response" do
    post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
         params: { funder_pool_id: @funder_pool.id }, 
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    assert_includes response.body, "pool-toggle-btn active"
    assert_includes response.body, "pool-toggle-#{@funder_pool.id}"
  end

  test "toggle_pool should handle errors gracefully" do
    # Simulate an error by trying to toggle a non-existent pool
    post toggle_pool_admin_lender_wholesale_funders_path(@lender), 
         params: { funder_pool_id: 999999 }, 
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :not_found
  end

  test "pool toggle buttons should use turbo stream" do
    get new_admin_lender_wholesale_funder_path(@lender)
    
    # Check that pool toggle buttons have the right attributes for Turbo
    assert_select "input[data-turbo-stream='true']"
    assert_select "input[value='POST']"
  end

  test "pool toggle form should point to correct endpoint" do
    get new_admin_lender_wholesale_funder_path(@lender)
    
    toggle_path = toggle_pool_admin_lender_wholesale_funders_path(@lender)
    assert_select "form[action='#{toggle_path}']"
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