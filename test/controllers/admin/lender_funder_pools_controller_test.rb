require "test_helper"

class Admin::LenderFunderPoolsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create test lenders
    @futureproof_lender = Lender.create!(
      name: "Futureproof Test",
      lender_type: :futureproof,
      contact_email: "futureproof@test.com",
      country: "Australia"
    )
    
    @broker_lender = Lender.create!(
      name: "Broker Test",
      lender_type: :lender,
      contact_email: "broker@test.com",
      country: "Australia"
    )
    
    # Create test users
    @futureproof_admin = User.create!(
      email: "admin@futureproof.com",
      password: "password123",
      first_name: "Admin",
      last_name: "User",
      admin: true,
      lender: @futureproof_lender,
      confirmed_at: Time.current
    )
    
    @broker_admin = User.create!(
      email: "admin@broker.com",
      password: "password123",
      first_name: "Broker",
      last_name: "Admin",
      admin: true,
      lender: @broker_lender,
      confirmed_at: Time.current
    )
    
    # Create wholesale funder and funder pool
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
      benchmark_rate: 4.00,
      margin_rate: 2.50
    )
    
    # Create wholesale funder relationship
    @lender_wholesale_funder = LenderWholesaleFunder.create!(
      lender: @broker_lender,
      wholesale_funder: @wholesale_funder,
      active: true
    )
  end

  # Authorization Tests
  test "should redirect non-admin users" do
    non_admin = User.create!(
      email: "user@test.com",
      password: "password123",
      first_name: "Regular",
      last_name: "User",
      admin: false,
      lender: @broker_lender,
      confirmed_at: Time.current
    )
    
    sign_in non_admin
    get new_admin_lender_funder_pool_path(@broker_lender)
    assert_redirected_to root_path
    assert_match /Access denied/, flash[:alert]
  end

  test "should redirect broker admins from managing other lenders" do
    sign_in @broker_admin
    get new_admin_lender_funder_pool_path(@futureproof_lender)
    assert_redirected_to admin_dashboard_index_path
    assert_match /Access denied/, flash[:alert]
  end

  test "should allow futureproof admins to manage any lender" do
    sign_in @futureproof_admin
    get new_admin_lender_funder_pool_path(@broker_lender)
    assert_response :success
  end

  # New Tests
  test "should get new for futureproof admin" do
    sign_in @futureproof_admin
    get new_admin_lender_funder_pool_path(@broker_lender)
    assert_response :success
    assert_not_nil assigns(:lender_funder_pool)
    assert_not_nil assigns(:available_funder_pools)
    assert assigns(:lender_funder_pool).new_record?
  end

  test "should show available funder pools from active wholesale funder relationships" do
    sign_in @futureproof_admin
    get new_admin_lender_funder_pool_path(@broker_lender)
    assert_response :success
    
    available_pools = assigns(:available_funder_pools)
    assert_includes available_pools, @funder_pool
  end

  test "should not show funder pools from inactive wholesale funder relationships" do
    @lender_wholesale_funder.update!(active: false)
    
    sign_in @futureproof_admin
    get new_admin_lender_funder_pool_path(@broker_lender)
    assert_response :success
    
    available_pools = assigns(:available_funder_pools)
    assert_not_includes available_pools, @funder_pool
  end

  test "should not show already associated funder pools" do
    # Create existing association
    LenderFunderPool.create!(
      lender: @broker_lender,
      funder_pool: @funder_pool,
      active: true
    )
    
    sign_in @futureproof_admin
    get new_admin_lender_funder_pool_path(@broker_lender)
    assert_response :success
    
    available_pools = assigns(:available_funder_pools)
    assert_not_includes available_pools, @funder_pool
  end

  # Create Tests
  test "should create lender funder pool with valid params" do
    sign_in @futureproof_admin
    
    assert_difference('LenderFunderPool.count') do
      post admin_lender_funder_pools_path(@broker_lender), params: {
        lender_funder_pool: {
          funder_pool_id: @funder_pool.id,
          active: true
        }
      }
    end
    
    assert_redirected_to admin_lender_path(@broker_lender)
    assert_match /successfully added/, flash[:notice]
    
    created_relationship = LenderFunderPool.last
    assert_equal @broker_lender, created_relationship.lender
    assert_equal @funder_pool, created_relationship.funder_pool
    assert created_relationship.active?
  end

  test "should create inactive lender funder pool" do
    sign_in @futureproof_admin
    
    assert_difference('LenderFunderPool.count') do
      post admin_lender_funder_pools_path(@broker_lender), params: {
        lender_funder_pool: {
          funder_pool_id: @funder_pool.id,
          active: false
        }
      }
    end
    
    assert_redirected_to admin_lender_path(@broker_lender)
    
    created_relationship = LenderFunderPool.last
    assert_not created_relationship.active?
  end

  test "should not create duplicate lender funder pool" do
    # Create existing relationship
    LenderFunderPool.create!(
      lender: @broker_lender,
      funder_pool: @funder_pool,
      active: true
    )
    
    sign_in @futureproof_admin
    
    assert_no_difference('LenderFunderPool.count') do
      post admin_lender_funder_pools_path(@broker_lender), params: {
        lender_funder_pool: {
          funder_pool_id: @funder_pool.id,
          active: true
        }
      }
    end
    
    assert_response :unprocessable_entity
  end

  test "should not create lender funder pool without wholesale funder relationship" do
    # Remove wholesale funder relationship
    @lender_wholesale_funder.destroy
    
    sign_in @futureproof_admin
    
    assert_no_difference('LenderFunderPool.count') do
      post admin_lender_funder_pools_path(@broker_lender), params: {
        lender_funder_pool: {
          funder_pool_id: @funder_pool.id,
          active: true
        }
      }
    end
    
    assert_response :unprocessable_entity
  end

  # Destroy Tests
  test "should destroy lender funder pool" do
    relationship = LenderFunderPool.create!(
      lender: @broker_lender,
      funder_pool: @funder_pool,
      active: true
    )
    
    sign_in @futureproof_admin
    
    assert_difference('LenderFunderPool.count', -1) do
      delete admin_lender_funder_pool_path(relationship)
    end
    
    assert_redirected_to admin_lender_path(@broker_lender)
    assert_match /successfully removed/, flash[:notice]
  end

  # Toggle Active Tests
  test "should toggle active status from active to inactive" do
    relationship = LenderFunderPool.create!(
      lender: @broker_lender,
      funder_pool: @funder_pool,
      active: true
    )
    
    sign_in @futureproof_admin
    
    patch toggle_active_admin_lender_funder_pool_path(relationship)
    
    assert_redirected_to admin_lender_path(@broker_lender)
    assert_match /deactivated/, flash[:notice]
    
    relationship.reload
    assert_not relationship.active?
  end

  test "should toggle active status from inactive to active" do
    relationship = LenderFunderPool.create!(
      lender: @broker_lender,
      funder_pool: @funder_pool,
      active: false
    )
    
    sign_in @futureproof_admin
    
    patch toggle_active_admin_lender_funder_pool_path(relationship)
    
    assert_redirected_to admin_lender_path(@broker_lender)
    assert_match /activated/, flash[:notice]
    
    relationship.reload
    assert relationship.active?
  end

  # Security Tests
  test "should not allow creating funder pool relationship for invalid funder pool" do
    sign_in @futureproof_admin
    
    assert_no_difference('LenderFunderPool.count') do
      post admin_lender_funder_pools_path(@broker_lender), params: {
        lender_funder_pool: {
          funder_pool_id: 99999, # Non-existent ID
          active: true
        }
      }
    end
    
    assert_response :unprocessable_entity
  end

  test "should handle missing funder pool parameter" do
    sign_in @futureproof_admin
    
    assert_no_difference('LenderFunderPool.count') do
      post admin_lender_funder_pools_path(@broker_lender), params: {
        lender_funder_pool: {
          active: true
        }
      }
    end
    
    assert_response :unprocessable_entity
  end

  # Edge Cases
  test "should handle lender with no wholesale funder relationships" do
    lender_without_relationships = Lender.create!(
      name: "Isolated Lender",
      lender_type: :lender,
      contact_email: "isolated@test.com",
      country: "Australia"
    )
    
    sign_in @futureproof_admin
    get new_admin_lender_funder_pool_path(lender_without_relationships)
    assert_response :success
    
    available_pools = assigns(:available_funder_pools)
    assert_empty available_pools
  end

  test "should handle multiple funder pools from same wholesale funder" do
    # Create second funder pool from same wholesale funder
    second_pool = FunderPool.create!(
      wholesale_funder: @wholesale_funder,
      name: "Second Test Pool",
      amount: 500000,
      allocated: 0,
      benchmark_rate: 3.75,
      margin_rate: 2.00
    )
    
    sign_in @futureproof_admin
    get new_admin_lender_funder_pool_path(@broker_lender)
    assert_response :success
    
    available_pools = assigns(:available_funder_pools)
    assert_includes available_pools, @funder_pool
    assert_includes available_pools, second_pool
    assert_equal 2, available_pools.count
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