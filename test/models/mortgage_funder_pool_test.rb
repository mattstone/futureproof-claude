require "test_helper"

class MortgageFunderPoolTest < ActiveSupport::TestCase
  setup do
    @mortgage = mortgages(:basic_mortgage)
    @funder_pool = funder_pools(:primary_pool)
  end

  test "should be valid with valid attributes" do
    mortgage_funder_pool = MortgageFunderPool.new(
      mortgage: @mortgage,
      funder_pool: @funder_pool
    )
    assert mortgage_funder_pool.valid?
  end

  test "should require mortgage" do
    mortgage_funder_pool = MortgageFunderPool.new(funder_pool: @funder_pool)
    assert_not mortgage_funder_pool.valid?
    assert_includes mortgage_funder_pool.errors[:mortgage], "must exist"
  end

  test "should require funder_pool" do
    mortgage_funder_pool = MortgageFunderPool.new(mortgage: @mortgage)
    assert_not mortgage_funder_pool.valid?
    assert_includes mortgage_funder_pool.errors[:funder_pool], "must exist"
  end

  test "should validate uniqueness of mortgage and funder_pool combination" do
    MortgageFunderPool.create!(mortgage: @mortgage, funder_pool: @funder_pool)
    
    duplicate = MortgageFunderPool.new(mortgage: @mortgage, funder_pool: @funder_pool)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:mortgage_id], "has already been taken"
  end

  test "should be active by default" do
    mortgage_funder_pool = MortgageFunderPool.new(
      mortgage: @mortgage,
      funder_pool: @funder_pool
    )
    assert mortgage_funder_pool.active?
  end

  test "should allow inactive associations" do
    mortgage_funder_pool = MortgageFunderPool.new(
      mortgage: @mortgage,
      funder_pool: @funder_pool,
      active: false
    )
    assert mortgage_funder_pool.valid?
  end

  test "active and inactive scopes should work correctly" do
    active_association = MortgageFunderPool.create!(mortgage: @mortgage, funder_pool: @funder_pool, active: true)
    inactive_association = MortgageFunderPool.create!(mortgage: mortgages(:premium_mortgage), funder_pool: @funder_pool, active: false)
    
    active_associations = MortgageFunderPool.active
    inactive_associations = MortgageFunderPool.inactive
    
    assert_includes active_associations, active_association
    assert_not_includes active_associations, inactive_association
    
    assert_includes inactive_associations, inactive_association
    assert_not_includes inactive_associations, active_association
  end

  test "status_display should return correct status" do
    association = MortgageFunderPool.new(mortgage: @mortgage, funder_pool: @funder_pool, active: true)
    assert_equal 'Active', association.status_display
    
    association.active = false
    assert_equal 'Inactive', association.status_display
  end

  test "status_badge_class should return correct CSS class" do
    association = MortgageFunderPool.new(mortgage: @mortgage, funder_pool: @funder_pool, active: true)
    assert_equal 'status-active', association.status_badge_class
    
    association.active = false
    assert_equal 'status-inactive', association.status_badge_class
  end

  test "toggle_active! should switch active status" do
    association = MortgageFunderPool.create!(mortgage: @mortgage, funder_pool: @funder_pool, active: true)
    
    association.toggle_active!
    assert_not association.active?
    
    association.toggle_active!
    assert association.active?
  end
end