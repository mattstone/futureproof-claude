require 'test_helper'

class Admin::FunderPoolManagementTest < ActionDispatch::IntegrationTest
  setup do
    # Create admin user
    @admin = users(:futureproof_admin)
    
    # Create test lender
    @lender = lenders(:test_lender)
    
    # Create test wholesale funder
    @wholesale_funder = wholesale_funders(:test_wholesale_funder)
    
    # Create wholesale funder relationship
    @lender_wholesale_funder = lender_wholesale_funders(:test_relationship)
    
    # Create test funder pool
    @funder_pool = funder_pools(:test_pool)
    
    sign_in @admin
  end

  test "should load available funder pools via AJAX" do
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
      assert pool.key?('wholesale_funder_name')
      assert pool.key?('formatted_amount')
      assert pool.key?('formatted_available')
      assert pool.key?('currency')
      assert pool.key?('currency_symbol')
      
      # Test that currency_symbol is properly included
      assert_not_nil pool['currency_symbol']
      assert_includes ['A$', '$', '£'], pool['currency_symbol']
    end
  end

  test "should add funder pool via Turbo Stream" do
    assert_difference '@lender.lender_funder_pools.count', 1 do
      post add_pool_admin_lender_funder_pools_path(@lender),
           params: { funder_pool_id: @funder_pool.id },
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    end
    
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html; charset=utf-8', response.content_type
    
    # Check that the relationship was created
    relationship = @lender.lender_funder_pools.find_by(funder_pool: @funder_pool)
    assert_not_nil relationship
    assert relationship.active?
  end

  test "should remove funder pool via Turbo Stream" do
    # First create a relationship
    relationship = @lender.lender_funder_pools.create!(
      funder_pool: @funder_pool,
      active: true
    )
    
    assert_difference '@lender.lender_funder_pools.count', -1 do
      delete admin_lender_funder_pool_path(relationship),
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    end
    
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html; charset=utf-8', response.content_type
  end

  test "should toggle funder pool status via Turbo Stream" do
    # First create a relationship
    relationship = @lender.lender_funder_pools.create!(
      funder_pool: @funder_pool,
      active: true
    )
    
    initial_status = relationship.active?
    
    patch toggle_active_admin_lender_funder_pool_path(relationship),
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    
    assert_response :success
    assert_equal 'text/vnd.turbo-stream.html; charset=utf-8', response.content_type
    
    relationship.reload
    assert_not_equal initial_status, relationship.active?
  end

  test "should display inline funder pool selection interface" do
    get admin_lender_path(@lender)
    
    assert_response :success
    
    # Check that the page contains the funder pool selector
    assert_select '[data-controller="funder-pool-selector"]'
    assert_select '[data-funder-pool-selector-target="addButton"]'
    assert_select '[data-funder-pool-selector-target="selectionInterface"]'
    assert_select '[data-funder-pool-selector-target="availablePoolsContainer"]'
    
    # Check that the Add Funder Pool button is present when wholesale funders exist
    assert_select 'button', text: 'Add Funder Pool'
  end

  test "should handle empty available pools gracefully" do
    # Remove all funder pools to test empty state
    @wholesale_funder.funder_pools.destroy_all
    
    get available_pools_admin_lender_funder_pools_path(@lender),
        headers: { 'Accept' => 'application/json' }
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.key?('funder_pools')
    assert_equal [], json_response['funder_pools']
  end

  test "should prevent adding duplicate funder pool relationships" do
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
    
    # Should still respond with turbo stream but show error
    assert_response :success
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password'
      }
    }
    follow_redirect!
  end
end