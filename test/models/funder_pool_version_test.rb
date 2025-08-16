require "test_helper"

class FunderPoolVersionTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User",
      confirmed_at: Time.current,
      lender: lenders(:futureproof)
    )
    
    @wholesale_funder = WholesaleFunder.create!(
      name: "Test Funder",
      country: "Australia",
      currency: "AUD"
    )
    
    @funder_pool = FunderPool.create!(
      wholesale_funder: @wholesale_funder,
      name: "Test Pool",
      amount: 1000000,
      allocated: 200000,
      benchmark_rate: 4.0,
      margin_rate: 2.5
    )
  end

  test "validates required fields" do
    version = FunderPoolVersion.new
    refute version.valid?
    assert_includes version.errors[:funder_pool], "must exist"
    assert_includes version.errors[:user], "must exist"
    assert_includes version.errors[:action], "can't be blank"
  end

  test "action_description returns correct descriptions" do
    version = FunderPoolVersion.new(action: "created")
    assert_equal "created funder pool", version.action_description
    
    version.action = "updated"
    assert_equal "updated funder pool", version.action_description
    
    version.action = "viewed"
    assert_equal "viewed funder pool", version.action_description
  end

  test "has_field_changes? detects all types of changes" do
    version = FunderPoolVersion.new
    refute version.has_field_changes?
    
    # Name change
    version.previous_name = "Old Pool"
    version.new_name = "New Pool"
    assert version.has_field_changes?
    
    # Amount change
    version = FunderPoolVersion.new
    version.previous_amount = 1000000
    version.new_amount = 1500000
    assert version.has_field_changes?
    
    # Allocated change
    version = FunderPoolVersion.new
    version.previous_allocated = 200000
    version.new_allocated = 300000
    assert version.has_field_changes?
    
    # Rate changes
    version = FunderPoolVersion.new
    version.previous_benchmark_rate = 4.0
    version.new_benchmark_rate = 4.5
    assert version.has_field_changes?
    
    version = FunderPoolVersion.new
    version.previous_margin_rate = 2.5
    version.new_margin_rate = 3.0
    assert version.has_field_changes?
  end

  test "detailed_changes returns correctly formatted currency amounts" do
    version = FunderPoolVersion.create!(
      funder_pool: @funder_pool,
      user: @user,
      action: "updated",
      change_details: "Updated amounts",
      previous_amount: 1000000,
      new_amount: 1500000,
      previous_allocated: 200000,
      new_allocated: 300000,
      previous_benchmark_rate: 4.0,
      new_benchmark_rate: 4.5,
      previous_margin_rate: 2.5,
      new_margin_rate: 3.0,
      previous_name: "Old Pool",
      new_name: "New Pool"
    )
    
    changes = version.detailed_changes
    assert_equal 5, changes.length
    
    # Check currency formatting
    amount_change = changes.find { |c| c[:field] == 'Amount' }
    assert_equal "$1,000,000", amount_change[:from]
    assert_equal "$1,500,000", amount_change[:to]
    
    allocated_change = changes.find { |c| c[:field] == 'Allocated' }
    assert_equal "$200,000", allocated_change[:from]
    assert_equal "$300,000", allocated_change[:to]
    
    # Check rate formatting
    benchmark_change = changes.find { |c| c[:field] == 'Benchmark Rate' }
    assert_equal "4.0%", benchmark_change[:from]
    assert_equal "4.5%", benchmark_change[:to]
    
    margin_change = changes.find { |c| c[:field] == 'Margin Rate' }
    assert_equal "2.5%", margin_change[:from]
    assert_equal "3.0%", margin_change[:to]
  end

  test "format_currency helper handles edge cases" do
    version = FunderPoolVersion.new
    
    # Test with nil values
    assert_equal "N/A", version.send(:format_currency, nil)
    assert_equal "N/A", version.send(:format_currency, "")
    
    # Test with valid amounts
    assert_equal "$1,000", version.send(:format_currency, 1000)
    assert_equal "$1,000,000", version.send(:format_currency, 1000000)
  end

  test "scopes work correctly" do
    created_version = FunderPoolVersion.create!(
      funder_pool: @funder_pool,
      user: @user,
      action: "created",
      change_details: "Created"
    )
    
    updated_version = FunderPoolVersion.create!(
      funder_pool: @funder_pool,
      user: @user,
      action: "updated",
      change_details: "Updated"
    )
    
    viewed_version = FunderPoolVersion.create!(
      funder_pool: @funder_pool,
      user: @user,
      action: "viewed",
      change_details: "Viewed"
    )
    
    # Test recent scope (should order by created_at desc)
    recent_versions = FunderPoolVersion.recent
    assert_equal viewed_version, recent_versions.first
    
    # Test action-specific scopes
    assert_includes FunderPoolVersion.by_action("created"), created_version
    assert_not_includes FunderPoolVersion.by_action("created"), updated_version
    
    # Test changes_only scope
    changes_only = FunderPoolVersion.changes_only
    assert_includes changes_only, created_version
    assert_includes changes_only, updated_version
    assert_not_includes changes_only, viewed_version
    
    # Test views_only scope
    views_only = FunderPoolVersion.views_only
    assert_includes views_only, viewed_version
    assert_not_includes views_only, created_version
  end
end