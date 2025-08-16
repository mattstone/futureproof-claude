require "test_helper"

class WholesaleFunderVersionTest < ActiveSupport::TestCase
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
  end

  test "validates required fields" do
    version = WholesaleFunderVersion.new
    refute version.valid?
    assert_includes version.errors[:wholesale_funder], "must exist"
    assert_includes version.errors[:user], "must exist"
    assert_includes version.errors[:action], "can't be blank"
  end

  test "validates action inclusion" do
    version = WholesaleFunderVersion.new(
      wholesale_funder: @wholesale_funder,
      user: @user,
      action: "invalid_action"
    )
    refute version.valid?
    assert_includes version.errors[:action], "is not included in the list"
  end

  test "action_description returns correct descriptions" do
    version = WholesaleFunderVersion.new(action: "created")
    assert_equal "created wholesale funder", version.action_description
    
    version.action = "updated"
    assert_equal "updated wholesale funder", version.action_description
    
    version.action = "viewed"
    assert_equal "viewed wholesale funder", version.action_description
  end

  test "formatted_created_at returns properly formatted date" do
    version = WholesaleFunderVersion.create!(
      wholesale_funder: @wholesale_funder,
      user: @user,
      action: "created",
      change_details: "Test change"
    )
    
    expected_format = version.created_at.strftime("%B %d, %Y at %I:%M %p")
    assert_equal expected_format, version.formatted_created_at
  end

  test "has_field_changes? detects changes correctly" do
    # Version with no changes
    version = WholesaleFunderVersion.new
    refute version.has_field_changes?
    
    # Version with name change
    version.previous_name = "Old Name"
    version.new_name = "New Name"
    assert version.has_field_changes?
    
    # Version with country change
    version = WholesaleFunderVersion.new
    version.previous_country = "Australia"
    version.new_country = "Canada"
    assert version.has_field_changes?
    
    # Version with currency change
    version = WholesaleFunderVersion.new
    version.previous_currency = "AUD"
    version.new_currency = "USD"
    assert version.has_field_changes?
  end

  test "detailed_changes returns correct change structure" do
    version = WholesaleFunderVersion.create!(
      wholesale_funder: @wholesale_funder,
      user: @user,
      action: "updated",
      change_details: "Test update",
      previous_name: "Old Name",
      new_name: "New Name",
      previous_country: "Australia",
      new_country: "Canada",
      previous_currency: "AUD",
      new_currency: "USD"
    )
    
    changes = version.detailed_changes
    assert_equal 3, changes.length
    
    # Check name change
    name_change = changes.find { |c| c[:field] == 'Name' }
    assert_equal "Old Name", name_change[:from]
    assert_equal "New Name", name_change[:to]
    
    # Check country change
    country_change = changes.find { |c| c[:field] == 'Country' }
    assert_equal "Australia", country_change[:from]
    assert_equal "Canada", country_change[:to]
    
    # Check currency change
    currency_change = changes.find { |c| c[:field] == 'Currency' }
    assert_equal "AUD", currency_change[:from]
    assert_equal "USD", currency_change[:to]
  end

  test "scopes work correctly" do
    # Create different types of versions
    created_version = WholesaleFunderVersion.create!(
      wholesale_funder: @wholesale_funder,
      user: @user,
      action: "created",
      change_details: "Created"
    )
    
    updated_version = WholesaleFunderVersion.create!(
      wholesale_funder: @wholesale_funder,
      user: @user,
      action: "updated", 
      change_details: "Updated"
    )
    
    viewed_version = WholesaleFunderVersion.create!(
      wholesale_funder: @wholesale_funder,
      user: @user,
      action: "viewed",
      change_details: "Viewed"
    )
    
    # Test scopes
    assert_includes WholesaleFunderVersion.recent, created_version
    assert_includes WholesaleFunderVersion.by_action("created"), created_version
    assert_not_includes WholesaleFunderVersion.by_action("created"), updated_version
    
    changes_only = WholesaleFunderVersion.changes_only
    assert_includes changes_only, created_version
    assert_includes changes_only, updated_version
    assert_not_includes changes_only, viewed_version
    
    views_only = WholesaleFunderVersion.views_only
    assert_includes views_only, viewed_version
    assert_not_includes views_only, created_version
  end

  test "admin_user alias works" do
    version = WholesaleFunderVersion.create!(
      wholesale_funder: @wholesale_funder,
      user: @user,
      action: "created",
      change_details: "Test"
    )
    
    assert_equal @user, version.admin_user
    assert_equal version.user, version.admin_user
  end
end