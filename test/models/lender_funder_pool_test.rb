require "test_helper"

class LenderFunderPoolTest < ActiveSupport::TestCase
  setup do
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
      amount: 1000000
    )
    
    # Create the required wholesale funder relationship
    @lender_wholesale_funder = LenderWholesaleFunder.create!(
      lender: @lender,
      wholesale_funder: @wholesale_funder,
      active: true
    )
  end

  test "should be valid with valid attributes" do
    relationship = LenderFunderPool.new(
      lender: @lender,
      funder_pool: @funder_pool,
      active: true
    )
    assert relationship.valid?
  end

  test "should require lender" do
    relationship = LenderFunderPool.new(
      funder_pool: @funder_pool,
      active: true
    )
    assert_not relationship.valid?
    assert_includes relationship.errors[:lender], "must exist"
  end

  test "should require funder_pool" do
    relationship = LenderFunderPool.new(
      lender: @lender,
      active: true
    )
    assert_not relationship.valid?
    assert_includes relationship.errors[:funder_pool], "must exist"
  end

  test "should validate uniqueness of lender and funder_pool combination" do
    LenderFunderPool.create!(
      lender: @lender,
      funder_pool: @funder_pool,
      active: true
    )
    
    duplicate = LenderFunderPool.new(
      lender: @lender,
      funder_pool: @funder_pool,
      active: false
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:lender_id], "has already been taken"
  end

  test "should require lender to have wholesale funder relationship" do
    # Create another wholesale funder without relationship
    other_wholesale_funder = WholesaleFunder.create!(
      name: "Other Wholesale Funder",
      country: "Australia",
      currency: "AUD"
    )
    other_pool = FunderPool.create!(
      wholesale_funder: other_wholesale_funder,
      name: "Other Pool",
      amount: 500000
    )
    
    relationship = LenderFunderPool.new(
      lender: @lender,
      funder_pool: other_pool,
      active: true
    )
    
    assert_not relationship.valid?
    assert_includes relationship.errors[:funder_pool], "can only be selected if lender has an active relationship with the wholesale funder"
  end

  test "should not allow funder pool from inactive wholesale funder relationship" do
    # Deactivate the wholesale funder relationship
    @lender_wholesale_funder.update!(active: false)
    
    relationship = LenderFunderPool.new(
      lender: @lender,
      funder_pool: @funder_pool,
      active: true
    )
    
    assert_not relationship.valid?
    assert_includes relationship.errors[:funder_pool], "can only be selected if lender has an active relationship with the wholesale funder"
  end

  test "should be active by default" do
    relationship = LenderFunderPool.new(
      lender: @lender,
      funder_pool: @funder_pool
    )
    assert relationship.active?
  end

  test "should allow inactive relationships" do
    relationship = LenderFunderPool.new(
      lender: @lender,
      funder_pool: @funder_pool,
      active: false
    )
    assert relationship.valid?
  end

  test "active and inactive scopes should work correctly" do
    active_relationship = LenderFunderPool.create!(
      lender: @lender,
      funder_pool: @funder_pool,
      active: true
    )
    
    # Create another pool for inactive relationship
    other_pool = FunderPool.create!(
      wholesale_funder: @wholesale_funder,
      name: "Other Pool",
      amount: 500000
    )
    
    inactive_relationship = LenderFunderPool.create!(
      lender: @lender,
      funder_pool: other_pool,
      active: false
    )
    
    active_relationships = LenderFunderPool.active
    inactive_relationships = LenderFunderPool.inactive
    
    assert_includes active_relationships, active_relationship
    assert_not_includes active_relationships, inactive_relationship
    
    assert_includes inactive_relationships, inactive_relationship
    assert_not_includes inactive_relationships, active_relationship
  end

  test "status_display should return correct status" do
    relationship = LenderFunderPool.new(
      lender: @lender,
      funder_pool: @funder_pool,
      active: true
    )
    assert_equal 'Active', relationship.status_display
    
    relationship.active = false
    assert_equal 'Inactive', relationship.status_display
  end

  test "status_badge_class should return correct CSS class" do
    relationship = LenderFunderPool.new(
      lender: @lender,
      funder_pool: @funder_pool,
      active: true
    )
    assert_equal 'status-active', relationship.status_badge_class
    
    relationship.active = false
    assert_equal 'status-inactive', relationship.status_badge_class
  end

  test "toggle_active! should switch active status" do
    relationship = LenderFunderPool.create!(
      lender: @lender,
      funder_pool: @funder_pool,
      active: true
    )
    
    relationship.toggle_active!
    assert_not relationship.active?
    
    relationship.toggle_active!
    assert relationship.active?
  end

  test "wholesale_funder method should return associated wholesale funder" do
    relationship = LenderFunderPool.new(
      lender: @lender,
      funder_pool: @funder_pool,
      active: true
    )
    
    assert_equal @wholesale_funder, relationship.wholesale_funder
  end

  test "should validate wholesale funder relationship when updating existing record" do
    relationship = LenderFunderPool.create!(
      lender: @lender,
      funder_pool: @funder_pool,
      active: true
    )
    
    # Deactivate wholesale funder relationship after creating pool relationship
    @lender_wholesale_funder.update!(active: false)
    
    # Should not be able to toggle the pool relationship when wholesale funder is inactive
    assert_raises(ActiveRecord::RecordInvalid) do
      relationship.toggle_active!
    end
  end
end