require 'test_helper'

class Admin::FunderPoolAddRemoveTest < ActionDispatch::IntegrationTest
  def setup
    # Create test data directly in database
    @admin_user = User.create!(
      email: 'admin@test.com',
      password: 'password',
      password_confirmation: 'password',
      verified: true,
      user_type: 'futureproof_admin'
    )
    
    @lender = Lender.create!(
      name: 'Test Lender for Pools',
      lender_type: 'lender',
      country: 'Australia',
      contact_email: 'test@lender.com'
    )
    
    @wholesale_funder = WholesaleFunder.create!(
      name: 'Test Wholesale Funder',
      country: 'Australia',
      currency: 'AUD'
    )
    
    # Create wholesale funder relationship
    @lender_wholesale_funder = @lender.lender_wholesale_funders.create!(
      wholesale_funder: @wholesale_funder,
      active: true
    )
    
    @funder_pool = @wholesale_funder.funder_pools.create!(
      name: 'Test Pool for Add/Remove',
      amount: 10000000,
      allocated: 0,
      benchmark_rate: 4.0,
      margin_rate: 2.0
    )
    
    sign_in_admin
  end
  
  def teardown
    # Clean up test data
    User.where(email: 'admin@test.com').destroy_all
    Lender.where(name: 'Test Lender for Pools').destroy_all
    WholesaleFunder.where(name: 'Test Wholesale Funder').destroy_all
    FunderPool.where(name: 'Test Pool for Add/Remove').destroy_all
  end

  test "should load available pools without routing errors" do
    get available_pools_admin_lender_funder_pools_path(@lender), 
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('funder_pools')
    
    funder_pools = json_response['funder_pools']
    assert_kind_of Array, funder_pools
    
    if funder_pools.any?
      pool = funder_pools.first
      assert pool.key?('id')
      assert pool.key?('name')
      assert pool.key?('formatted_amount')
      assert pool.key?('formatted_available')
      
      # Verify no currency or wholesale funder info (removed as duplicate)
      assert_not pool.key?('currency')
      assert_not pool.key?('currency_symbol')
      assert_not pool.key?('wholesale_funder_name')
    end
  end

  test "should successfully add funder pool via Turbo Stream" do
    # Verify pool is available for selection
    assert_not @lender.funder_pools.include?(@funder_pool), "Pool should not be already selected"
    
    assert_difference '@lender.lender_funder_pools.count', 1 do
      post add_pool_admin_lender_funder_pools_path(@lender),
           params: { funder_pool_id: @funder_pool.id },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    end
    
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html; charset=utf-8', response.content_type
    
    # Verify the relationship was created
    relationship = @lender.lender_funder_pools.find_by(funder_pool: @funder_pool)
    assert_not_nil relationship, "Funder pool relationship should be created"
    assert relationship.active?, "Relationship should be active by default"
    
    # Verify response contains success elements
    assert_includes response.body, 'turbo-stream', "Response should contain turbo-stream elements"
    assert_includes response.body, 'existing-pools', "Response should update existing-pools"
  end

  test "should successfully remove funder pool via Turbo Stream" do
    # First create a relationship
    relationship = @lender.lender_funder_pools.create!(
      funder_pool: @funder_pool,
      active: true
    )
    
    assert_difference '@lender.lender_funder_pools.count', -1 do
      delete admin_lender_funder_pool_path(@lender, relationship),
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    end
    
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html; charset=utf-8', response.content_type
    
    # Verify the relationship was deleted
    assert_nil LenderFunderPool.find_by(id: relationship.id), "Relationship should be deleted"
    
    # Verify response contains success elements
    assert_includes response.body, 'turbo-stream', "Response should contain turbo-stream elements"
    assert_includes response.body, 'existing-pools', "Response should update existing-pools"
  end

  test "should successfully toggle funder pool status via Turbo Stream" do
    # First create a relationship
    relationship = @lender.lender_funder_pools.create!(
      funder_pool: @funder_pool,
      active: true
    )
    
    initial_status = relationship.active?
    
    patch toggle_active_admin_lender_funder_pool_path(@lender, relationship),
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html; charset=utf-8', response.content_type
    
    # Verify the status was toggled
    relationship.reload
    assert_not_equal initial_status, relationship.active?, "Status should be toggled"
    
    # Verify response contains success elements
    assert_includes response.body, 'turbo-stream', "Response should contain turbo-stream elements"
    assert_includes response.body, 'existing-pools', "Response should update existing-pools"
  end

  test "should handle duplicate pool addition gracefully" do
    # First create a relationship
    @lender.lender_funder_pools.create!(
      funder_pool: @funder_pool,
      active: true
    )
    
    # Try to add the same pool again
    assert_no_difference '@lender.lender_funder_pools.count' do
      post add_pool_admin_lender_funder_pools_path(@lender),
           params: { funder_pool_id: @funder_pool.id },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    end
    
    # Should still respond with turbo stream (not crash)
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html; charset=utf-8', response.content_type
  end

  test "should generate correct route paths in Turbo Stream templates" do
    # Create a relationship to test template generation
    relationship = @lender.lender_funder_pools.create!(
      funder_pool: @funder_pool,
      active: true
    )
    
    # Test add_pool template (success path)
    post add_pool_admin_lender_funder_pools_path(@lender),
         params: { funder_pool_id: @funder_pool.id },
         headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    
    # Verify the template contains correctly formatted route paths
    # Should include lender_id in the paths
    assert_includes response.body, "/admin/lenders/#{@lender.id}/funder_pools/", 
                   "Routes should include lender_id"
    
    # Should not contain invalid route patterns that caused the original error
    assert_not_includes response.body, 'missing required keys', 
                       "Should not have routing errors"
  end

  test "should display pools with correct formatting after add/remove operations" do
    # Add a pool
    post add_pool_admin_lender_funder_pools_path(@lender),
         params: { funder_pool_id: @funder_pool.id },
         headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    
    # Verify the response contains properly formatted pool information
    assert_includes response.body, @funder_pool.name, "Pool name should be displayed"
    assert_includes response.body, @funder_pool.formatted_amount, "Formatted amount should be displayed"
    assert_includes response.body, @funder_pool.formatted_available, "Formatted available should be displayed"
    
    # Verify wholesale funder info is shown (not duplicate removed)
    assert_includes response.body, @wholesale_funder.name, "Wholesale funder name should be displayed"
    
    # Check for proper button elements
    assert_includes response.body, 'Toggle', "Toggle button should be present"
    assert_includes response.body, 'Remove', "Remove button should be present"
  end

  private

  def sign_in_admin
    post user_session_path, params: {
      user: {
        email: @admin_user.email,
        password: 'password'
      }
    }
    follow_redirect!
  end
end