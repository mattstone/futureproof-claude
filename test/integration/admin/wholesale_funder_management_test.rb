require "test_helper"

class Admin::WholesaleFunderManagementTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin_user)
    @lender = lenders(:futureproof)
    @wholesale_funder = wholesale_funders(:alpha_funding)
    
    # Create a relationship to test removal
    @relationship = LenderWholesaleFunder.create!(
      lender: @lender,
      wholesale_funder: @wholesale_funder,
      active: true
    )
    
    sign_in @admin_user
  end

  test "remove wholesale funder button generates correct URL" do
    get admin_lender_path(@lender)
    assert_response :success
    
    # Check that the remove button has the correct URL structure
    assert_select "form[action=?]", admin_lender_wholesale_funder_path(@lender, @relationship)
    assert_select "form[action*=?]", "/admin/lenders/#{@lender.id}/wholesale_funders/#{@relationship.id}"
  end

  test "remove wholesale funder via DELETE request with Turbo Stream" do
    assert_difference('@lender.lender_wholesale_funders.count', -1) do
      delete admin_lender_wholesale_funder_path(@lender, @relationship),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    
    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
    
    # Check that the response contains Turbo Stream content
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, "successfully"
  end

  test "remove wholesale funder handles missing record gracefully" do
    # Delete the relationship first
    @relationship.destroy!
    
    delete admin_lender_wholesale_funder_path(@lender, 999),
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
    assert_includes response.body, "not found"
  end

  test "toggle wholesale funder button generates correct URL" do
    get admin_lender_path(@lender)
    assert_response :success
    
    # Check that the toggle button has the correct URL structure  
    assert_select "form[action=?]", toggle_active_admin_lender_wholesale_funder_path(@lender, @relationship)
    assert_select "form[action*=?]", "/admin/lenders/#{@lender.id}/wholesale_funders/#{@relationship.id}/toggle_active"
  end

  test "toggle wholesale funder via PATCH request with Turbo Stream" do
    original_status = @relationship.active?
    
    patch toggle_active_admin_lender_wholesale_funder_path(@lender, @relationship),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
    
    # Verify the status changed
    @relationship.reload
    assert_not_equal original_status, @relationship.active?
    
    # Check Turbo Stream response
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, "successfully"
  end
end