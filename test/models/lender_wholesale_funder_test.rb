require "test_helper"

class LenderWholesaleFunderTest < ActiveSupport::TestCase
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
  end

  test "should be valid with valid attributes" do
    relationship = LenderWholesaleFunder.new(
      lender: @lender,
      wholesale_funder: @wholesale_funder,
      active: true
    )
    assert relationship.valid?
  end

  test "should require lender" do
    relationship = LenderWholesaleFunder.new(
      wholesale_funder: @wholesale_funder,
      active: true
    )
    assert_not relationship.valid?
    assert_includes relationship.errors[:lender], "must exist"
  end

  test "should require wholesale_funder" do
    relationship = LenderWholesaleFunder.new(
      lender: @lender,
      active: true
    )
    assert_not relationship.valid?
    assert_includes relationship.errors[:wholesale_funder], "must exist"
  end

  test "should validate uniqueness of lender and wholesale_funder combination" do
    LenderWholesaleFunder.create!(
      lender: @lender,
      wholesale_funder: @wholesale_funder,
      active: true
    )
    
    duplicate = LenderWholesaleFunder.new(
      lender: @lender,
      wholesale_funder: @wholesale_funder,
      active: false
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:lender_id], "has already been taken"
  end

  test "should be active by default" do
    relationship = LenderWholesaleFunder.new(
      lender: @lender,
      wholesale_funder: @wholesale_funder
    )
    assert relationship.active?
  end

  test "should allow inactive relationships" do
    relationship = LenderWholesaleFunder.new(
      lender: @lender,
      wholesale_funder: @wholesale_funder,
      active: false
    )
    assert relationship.valid?
  end

  test "active and inactive scopes should work correctly" do
    active_relationship = LenderWholesaleFunder.create!(
      lender: @lender,
      wholesale_funder: @wholesale_funder,
      active: true
    )
    
    other_lender = Lender.create!(
      name: "Other Lender",
      lender_type: "lender",
      country: "Australia",
      contact_email: "other@lender.com"
    )
    
    inactive_relationship = LenderWholesaleFunder.create!(
      lender: other_lender,
      wholesale_funder: @wholesale_funder,
      active: false
    )
    
    active_relationships = LenderWholesaleFunder.active
    inactive_relationships = LenderWholesaleFunder.inactive
    
    assert_includes active_relationships, active_relationship
    assert_not_includes active_relationships, inactive_relationship
    
    assert_includes inactive_relationships, inactive_relationship
    assert_not_includes inactive_relationships, active_relationship
  end

  test "status_display should return correct status" do
    relationship = LenderWholesaleFunder.new(
      lender: @lender,
      wholesale_funder: @wholesale_funder,
      active: true
    )
    assert_equal 'Active', relationship.status_display
    
    relationship.active = false
    assert_equal 'Inactive', relationship.status_display
  end

  test "status_badge_class should return correct CSS class" do
    relationship = LenderWholesaleFunder.new(
      lender: @lender,
      wholesale_funder: @wholesale_funder,
      active: true
    )
    assert_equal 'status-active', relationship.status_badge_class
    
    relationship.active = false
    assert_equal 'status-inactive', relationship.status_badge_class
  end

  test "toggle_active! should switch active status" do
    relationship = LenderWholesaleFunder.create!(
      lender: @lender,
      wholesale_funder: @wholesale_funder,
      active: true
    )
    
    relationship.toggle_active!
    assert_not relationship.active?
    
    relationship.toggle_active!
    assert relationship.active?
  end
end