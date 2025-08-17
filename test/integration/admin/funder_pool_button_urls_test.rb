require 'test_helper'

class Admin::FunderPoolButtonUrlsTest < ActionDispatch::IntegrationTest
  def setup
    # Create test data directly 
    @admin_user = User.create!(
      email: 'admin_test@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      verified: true,
      user_type: 'futureproof_admin'
    )
    
    @lender = Lender.create!(
      name: 'Test Lender for URL Test',
      lender_type: 'lender',
      country: 'Australia',
      contact_email: 'test@lender.com'
    )
    
    @wholesale_funder = WholesaleFunder.create!(
      name: 'Test Wholesale Funder for URLs',
      country: 'Australia',
      currency: 'AUD'
    )
    
    @lender.lender_wholesale_funders.create!(
      wholesale_funder: @wholesale_funder,
      active: true
    )
    
    @funder_pool = @wholesale_funder.funder_pools.create!(
      name: 'Test Pool for URL Generation',
      amount: 10000000,
      allocated: 0,
      benchmark_rate: 4.0,
      margin_rate: 2.0
    )
    
    @pool_relationship = @lender.lender_funder_pools.create!(
      funder_pool: @funder_pool,
      active: true
    )
    
    sign_in_admin
  end
  
  def teardown
    # Clean up test data
    User.where(email: 'admin_test@test.com').destroy_all
    Lender.where(name: 'Test Lender for URL Test').destroy_all
    WholesaleFunder.where(name: 'Test Wholesale Funder for URLs').destroy_all
    FunderPool.where(name: 'Test Pool for URL Generation').destroy_all
  end

  test "buttons in lender show page generate correct URLs with proper lender_id" do
    get admin_lender_path(@lender)
    assert_response :success
    
    # Check that toggle button has correct URL format
    expected_toggle_url = "/admin/lenders/#{@lender.id}/funder_pools/#{@pool_relationship.id}/toggle_active"
    assert_select "form[action='#{expected_toggle_url}']", 1, 
                 "Toggle button should have correct URL with lender_id=#{@lender.id} and pool_relationship_id=#{@pool_relationship.id}"
    
    # Check that remove button has correct URL format  
    expected_remove_url = "/admin/lenders/#{@lender.id}/funder_pools/#{@pool_relationship.id}"
    assert_select "form[action='#{expected_remove_url}'][data-turbo='true']", 1,
                 "Remove button should have correct URL with lender_id=#{@lender.id} and pool_relationship_id=#{@pool_relationship.id}"
    
    # Ensure the URLs don't contain wrong IDs (this would catch the bug we just fixed)
    assert_not_includes response.body, "/admin/lenders/11/funder_pools/", 
                       "URLs should not contain wrong lender ID (11)"
    assert_not_includes response.body, "/admin/lenders/0/funder_pools/", 
                       "URLs should not contain invalid lender ID (0)"
  end

  test "remove button actually works with correct lender scoping" do
    # Verify the relationship exists
    assert @lender.lender_funder_pools.exists?(@pool_relationship.id), 
           "Pool relationship should exist before removal"
    
    # Perform the delete request
    assert_difference('@lender.lender_funder_pools.count', -1, 
                     "Should remove one pool relationship") do
      delete admin_lender_funder_pool_path(@lender, @pool_relationship),
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    end
    
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html; charset=utf-8', response.content_type
    
    # Verify the relationship no longer exists
    assert_not @lender.lender_funder_pools.exists?(@pool_relationship.id), 
               "Pool relationship should be deleted"
  end

  test "toggle button actually works with correct lender scoping" do
    initial_status = @pool_relationship.active?
    
    patch toggle_active_admin_lender_funder_pool_path(@lender, @pool_relationship),
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html; charset=utf-8', response.content_type
    
    @pool_relationship.reload
    assert_not_equal initial_status, @pool_relationship.active?, 
                    "Pool relationship status should be toggled"
  end

  test "remove button with wrong lender ID should fail gracefully" do
    # Create another lender to test cross-lender security
    other_lender = Lender.create!(
      name: 'Other Lender for Security Test',
      lender_type: 'lender', 
      country: 'Australia',
      contact_email: 'other@test.com'
    )
    
    # Try to delete our pool relationship using the other lender's ID
    assert_no_difference('@lender.lender_funder_pools.count', 
                        "Should not remove relationship when using wrong lender ID") do
      assert_raises(ActiveRecord::RecordNotFound) do
        delete admin_lender_funder_pool_path(other_lender, @pool_relationship),
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      end
    end
    
    # Verify the relationship still exists
    assert @lender.lender_funder_pools.exists?(@pool_relationship.id), 
           "Pool relationship should still exist after failed cross-lender deletion attempt"
    
    # Clean up
    other_lender.destroy!
  end

  test "available pools endpoint returns data for correct lender" do
    get available_pools_admin_lender_funder_pools_path(@lender),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('funder_pools'), "Response should contain funder_pools key"
    
    funder_pools = json_response['funder_pools']
    assert_kind_of Array, funder_pools, "funder_pools should be an array"
    
    # The pool should not be available since it's already selected
    pool_ids = funder_pools.map { |p| p['id'] }
    assert_not_includes pool_ids, @funder_pool.id, 
                       "Already selected pool should not appear in available pools"
  end

  private

  def sign_in_admin
    post user_session_path, params: {
      user: {
        email: @admin_user.email,
        password: 'password123'
      }
    }
    follow_redirect!
  end
end