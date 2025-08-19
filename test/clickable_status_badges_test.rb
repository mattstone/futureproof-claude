require 'test_helper'

class ClickableStatusBadgesTest < ActionDispatch::IntegrationTest
  # Disable fixture loading to avoid foreign key constraint issues
  self.use_transactional_tests = false
  
  def setup
    # Skip fixture loading
    # Create test data manually to avoid fixture issues
    @lender = Lender.create!(
      name: "Test Toggle Lender",
      contact_email: "toggle@testlender.com",
      lender_type: :lender,
      address: "123 Toggle Street",
      country: "Australia"
    )
    
    @admin_user = User.create!(
      first_name: "Test",
      last_name: "Admin", 
      email: "toggle_admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true,
      terms_accepted: true,
      confirmed_at: 1.day.ago,
      address: "Admin Address",
      lender: @lender
    )
    
    @wholesale_funder = WholesaleFunder.create!(
      name: "Test Wholesale Funder",
      contact_email: "wholesale@test.com",
      address: "Wholesale Address"
    )
    
    @funder_pool = FunderPool.create!(
      name: "Test Funder Pool",
      amount: 1000000.0,
      allocated: 0.0,
      wholesale_funder: @wholesale_funder
    )
    
    # Create relationships
    @wholesale_relationship = @lender.lender_wholesale_funders.create!(
      wholesale_funder: @wholesale_funder,
      active: true
    )
    
    @pool_relationship = @lender.lender_funder_pools.create!(
      funder_pool: @funder_pool,
      active: true
    )
  end
  
  def teardown
    # Clean up manually created data
    User.where(email: "toggle_admin@example.com").destroy_all
    LenderWholesaleFunder.where(lender: @lender).destroy_all
    LenderFunderPool.where(lender: @lender).destroy_all
    FunderPool.where(name: "Test Funder Pool").destroy_all
    WholesaleFunder.where(name: "Test Wholesale Funder").destroy_all
    Lender.where(name: "Test Toggle Lender").destroy_all
  end
  
  test "admin lender view displays clickable status badges" do
    sign_in @admin_user
    
    get admin_lender_path(@lender)
    assert_response :success
    
    # Check that wholesale funder status badge exists and is clickable
    assert_select 'form[action=?][method=post]', toggle_active_admin_lender_wholesale_funder_path(@lender, @wholesale_relationship) do
      assert_select 'button[type=submit].clickable-status-badge', text: 'Active'
    end
    
    # Check that funder pool status badge exists and is clickable  
    assert_select 'form[action=?][method=post]', toggle_active_admin_lender_funder_pool_path(@lender, @pool_relationship) do
      assert_select 'button[type=submit].clickable-status-badge', text: 'Active'
    end
  end
  
  test "wholesale funder status badge toggle works with confirmation" do
    sign_in @admin_user
    
    # Verify initial state
    assert @wholesale_relationship.active?
    
    # Submit toggle request (simulates clicking the status badge)
    patch toggle_active_admin_lender_wholesale_funder_path(@lender, @wholesale_relationship),
          xhr: true
    
    assert_response :success
    @wholesale_relationship.reload
    
    # Status should be toggled
    assert_not @wholesale_relationship.active?
  end
  
  test "funder pool status badge toggle works with confirmation" do
    sign_in @admin_user
    
    # Verify initial state  
    assert @pool_relationship.active?
    
    # Submit toggle request (simulates clicking the status badge)
    patch toggle_active_admin_lender_funder_pool_path(@lender, @pool_relationship),
          xhr: true
    
    assert_response :success
    @pool_relationship.reload
    
    # Status should be toggled
    assert_not @pool_relationship.active?
  end
  
  test "status badges have proper CSS classes and accessibility attributes" do
    sign_in @admin_user
    
    get admin_lender_path(@lender)
    assert_response :success
    
    # Check wholesale funder status badge has proper attributes
    assert_select 'button.clickable-status-badge.status-active[role=button][tabindex="0"]' do
      assert_select '[data-confirm*="Are you sure"]'
      assert_select '[aria-label*="Toggle wholesale funder status"]'
    end
    
    # Check funder pool status badge has proper attributes  
    assert_select 'button.clickable-status-badge.status-active[role=button][tabindex="0"]' do
      assert_select '[data-confirm*="Are you sure"]' 
      assert_select '[aria-label*="Toggle funder pool status"]'
    end
  end
  
  test "inactive status badges display correctly" do
    # Set relationships to inactive
    @wholesale_relationship.update!(active: false)
    @pool_relationship.update!(active: false)
    
    sign_in @admin_user
    
    get admin_lender_path(@lender)
    assert_response :success
    
    # Check inactive wholesale funder badge
    assert_select 'button.clickable-status-badge.status-inactive', text: 'Inactive'
    
    # Check inactive funder pool badge  
    assert_select 'button.clickable-status-badge.status-inactive', text: 'Inactive'
  end
  
  test "toggle endpoints return proper HTTP status codes" do
    sign_in @admin_user
    
    # Test wholesale funder toggle
    patch toggle_active_admin_lender_wholesale_funder_path(@lender, @wholesale_relationship)
    assert_response :success
    
    # Test funder pool toggle
    patch toggle_active_admin_lender_funder_pool_path(@lender, @pool_relationship) 
    assert_response :success
  end
  
  test "non-admin users cannot access toggle functionality" do
    non_admin = User.create!(
      first_name: "Regular",
      last_name: "User",
      email: "regular@example.com", 
      password: "password123",
      password_confirmation: "password123",
      admin: false,
      terms_accepted: true,
      confirmed_at: 1.day.ago,
      address: "User Address",
      lender: @lender
    )
    
    sign_in non_admin
    
    # Should be redirected or get unauthorized response
    patch toggle_active_admin_lender_wholesale_funder_path(@lender, @wholesale_relationship)
    assert_response :redirect
    
    patch toggle_active_admin_lender_funder_pool_path(@lender, @pool_relationship)
    assert_response :redirect
    
    non_admin.destroy
  end
  
  private
  
  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: "password123"
      }
    }
    follow_redirect! if response.redirect?
  end
end