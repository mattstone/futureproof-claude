require "test_helper"

class Admin::LenderFunderPoolWorkflowTest < ActionDispatch::IntegrationTest
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
    
    # Create admin user
    @admin_user = User.create!(
      email: "admin@futureproof.com",
      password: "password123",
      first_name: "Admin",
      last_name: "User",
      admin: true,
      lender: @futureproof_lender,
      confirmed_at: Time.current
    )
    
    # Create wholesale funders and funder pools
    @wholesale_funder_aud = WholesaleFunder.create!(
      name: "Australian Wholesale Funder",
      country: "Australia",
      currency: "AUD"
    )
    
    @wholesale_funder_usd = WholesaleFunder.create!(
      name: "US Wholesale Funder",
      country: "United States",
      currency: "USD"
    )
    
    @funder_pool_aud = FunderPool.create!(
      wholesale_funder: @wholesale_funder_aud,
      name: "AUD Pool",
      amount: 1000000,
      allocated: 200000,
      benchmark_rate: 4.00,
      margin_rate: 2.50
    )
    
    @funder_pool_usd = FunderPool.create!(
      wholesale_funder: @wholesale_funder_usd,
      name: "USD Pool",
      amount: 2000000,
      allocated: 500000,
      benchmark_rate: 3.50,
      margin_rate: 3.00
    )
    
    # Create wholesale funder relationships
    @lender_wf_aud = LenderWholesaleFunder.create!(
      lender: @broker_lender,
      wholesale_funder: @wholesale_funder_aud,
      active: true
    )
    
    @lender_wf_usd = LenderWholesaleFunder.create!(
      lender: @broker_lender,
      wholesale_funder: @wholesale_funder_usd,
      active: true
    )
  end

  test "complete lender funder pool management workflow" do
    sign_in @admin_user
    
    # Step 1: Navigate to lender show page
    get admin_lender_path(@broker_lender)
    assert_response :success
    assert_select "h3", text: @broker_lender.name
    
    # Should show wholesale funder relationships
    assert_select ".relationship-card", count: 2
    assert_includes response.body, @wholesale_funder_aud.name
    assert_includes response.body, @wholesale_funder_usd.name
    
    # Should show "Add Funder Pool" button since there are active wholesale funders
    assert_select "a[href='#{new_admin_lender_funder_pool_path(@broker_lender)}']", text: "Add Funder Pool"
    
    # Should show empty state for funder pools
    assert_select ".empty-state", text: /No funder pools selected yet/
    
    # Step 2: Navigate to add funder pool page
    get new_admin_lender_funder_pool_path(@broker_lender)
    assert_response :success
    assert_select "h3", text: "Add Funder Pool Access"
    
    # Should show available funder pools from both wholesale funders
    assert_select "select[name='lender_funder_pool[funder_pool_id]']"
    assert_includes response.body, @funder_pool_aud.name
    assert_includes response.body, @funder_pool_usd.name
    
    # Should show preview of available pools
    assert_select ".wholesale-funder-group", count: 2
    assert_includes response.body, @wholesale_funder_aud.name
    assert_includes response.body, @wholesale_funder_usd.name
    
    # Step 3: Add first funder pool (AUD)
    post admin_lender_funder_pools_path(@broker_lender), params: {
      lender_funder_pool: {
        funder_pool_id: @funder_pool_aud.id,
        active: true
      }
    }
    assert_redirected_to admin_lender_path(@broker_lender)
    follow_redirect!
    assert_match /successfully added/, flash[:notice]
    
    # Should now show the added funder pool
    assert_select ".pool-card", count: 1
    assert_includes response.body, @funder_pool_aud.name
    assert_includes response.body, @wholesale_funder_aud.name
    assert_select ".status-active"
    
    # Step 4: Add second funder pool (USD) 
    get new_admin_lender_funder_pool_path(@broker_lender)
    assert_response :success
    
    # Should not show the already added AUD pool
    assert_not_includes response.body, @funder_pool_aud.name
    assert_includes response.body, @funder_pool_usd.name
    
    post admin_lender_funder_pools_path(@broker_lender), params: {
      lender_funder_pool: {
        funder_pool_id: @funder_pool_usd.id,
        active: false  # Add as inactive
      }
    }
    assert_redirected_to admin_lender_path(@broker_lender)
    follow_redirect!
    
    # Should now show both funder pools
    assert_select ".pool-card", count: 2
    assert_select ".status-active", count: 1
    assert_select ".status-inactive", count: 1
    
    # Step 5: Toggle USD pool to active
    usd_relationship = LenderFunderPool.find_by(lender: @broker_lender, funder_pool: @funder_pool_usd)
    patch toggle_active_admin_lender_funder_pool_path(usd_relationship)
    assert_redirected_to admin_lender_path(@broker_lender)
    follow_redirect!
    assert_match /activated/, flash[:notice]
    
    # Should now show both pools as active
    assert_select ".status-active", count: 2
    assert_select ".status-inactive", count: 0
    
    # Step 6: Toggle AUD pool to inactive
    aud_relationship = LenderFunderPool.find_by(lender: @broker_lender, funder_pool: @funder_pool_aud)
    patch toggle_active_admin_lender_funder_pool_path(aud_relationship)
    assert_redirected_to admin_lender_path(@broker_lender)
    follow_redirect!
    assert_match /deactivated/, flash[:notice]
    
    # Should show 1 active, 1 inactive
    assert_select ".status-active", count: 1
    assert_select ".status-inactive", count: 1
    
    # Step 7: Remove AUD pool
    delete admin_lender_funder_pool_path(aud_relationship)
    assert_redirected_to admin_lender_path(@broker_lender)
    follow_redirect!
    assert_match /successfully removed/, flash[:notice]
    
    # Should now show only USD pool
    assert_select ".pool-card", count: 1
    assert_includes response.body, @funder_pool_usd.name
    assert_not_includes response.body, @funder_pool_aud.name
    
    # Step 8: Try to add pool again - should be available again
    get new_admin_lender_funder_pool_path(@broker_lender)
    assert_response :success
    assert_includes response.body, @funder_pool_aud.name
    assert_not_includes response.body, @funder_pool_usd.name # Already added
  end

  test "workflow with no wholesale funder relationships" do
    lender_without_relationships = Lender.create!(
      name: "Isolated Lender",
      lender_type: :lender,
      contact_email: "isolated@test.com",
      country: "Australia"
    )
    
    sign_in @admin_user
    
    # Step 1: Visit lender show page
    get admin_lender_path(lender_without_relationships)
    assert_response :success
    
    # Should not show "Add Funder Pool" button
    assert_select "a", text: "Add Funder Pool", count: 0
    
    # Should show empty state for wholesale funders
    assert_select ".empty-state", text: /No wholesale funder relationships/
    
    # Should show message about needing wholesale funder relationships first
    assert_select ".empty-state", text: /Add wholesale funder relationships first/
  end

  test "workflow when wholesale funder relationship becomes inactive" do
    sign_in @admin_user
    
    # Step 1: Add funder pool while relationship is active
    post admin_lender_funder_pools_path(@broker_lender), params: {
      lender_funder_pool: {
        funder_pool_id: @funder_pool_aud.id,
        active: true
      }
    }
    assert_redirected_to admin_lender_path(@broker_lender)
    
    # Step 2: Deactivate wholesale funder relationship
    @lender_wf_aud.update!(active: false)
    
    # Step 3: Visit lender page - existing pool should still be shown
    get admin_lender_path(@broker_lender)
    assert_response :success
    assert_select ".pool-card", count: 1
    assert_includes response.body, @funder_pool_aud.name
    
    # Step 4: Try to add new pools - AUD pool should not be available
    get new_admin_lender_funder_pool_path(@broker_lender)
    assert_response :success
    assert_not_includes response.body, @funder_pool_aud.name
    assert_includes response.body, @funder_pool_usd.name # USD relationship still active
  end

  test "funder pool display includes correct financial information" do
    sign_in @admin_user
    
    # Add funder pool
    post admin_lender_funder_pools_path(@broker_lender), params: {
      lender_funder_pool: {
        funder_pool_id: @funder_pool_aud.id,
        active: true
      }
    }
    follow_redirect!
    
    # Should display financial information
    assert_includes response.body, "$1,000,000"    # Total amount
    assert_includes response.body, "$800,000"      # Available (1M - 200K allocated)
    assert_includes response.body, @wholesale_funder_aud.name
  end

  test "access control - broker admin can only manage their own lender" do
    broker_admin = User.create!(
      email: "broker.admin@test.com",
      password: "password123",
      first_name: "Broker",
      last_name: "Admin",
      admin: true,
      lender: @broker_lender,
      confirmed_at: Time.current
    )
    
    sign_in broker_admin
    
    # Should be able to manage their own lender
    get admin_lender_path(@broker_lender)
    assert_response :success
    
    get new_admin_lender_funder_pool_path(@broker_lender)
    assert_response :success
    
    # Should NOT be able to manage other lenders
    get admin_lender_path(@futureproof_lender)
    assert_redirected_to admin_dashboard_index_path
    
    get new_admin_lender_funder_pool_path(@futureproof_lender)
    assert_redirected_to admin_dashboard_index_path
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