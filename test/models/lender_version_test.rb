require "test_helper"

class LenderVersionTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User",
      confirmed_at: Time.current,
      lender: lenders(:futureproof)
    )
    
    @lender = Lender.create!(
      name: "Test Lender",
      lender_type: :lender,
      contact_email: "test@lender.com",
      country: "Australia"
    )
  end

  test "validates required fields" do
    version = LenderVersion.new
    refute version.valid?
    assert_includes version.errors[:lender], "must exist"
    assert_includes version.errors[:user], "must exist"
    assert_includes version.errors[:action], "can't be blank"
  end

  test "action_description returns correct descriptions" do
    version = LenderVersion.new(action: "created")
    assert_equal "created lender", version.action_description
    
    version.action = "updated"
    assert_equal "updated lender", version.action_description
    
    version.action = "viewed"
    assert_equal "viewed lender", version.action_description
  end

  test "has_field_changes? detects all types of changes" do
    version = LenderVersion.new
    refute version.has_field_changes?
    
    # Name change
    version.previous_name = "Old Lender"
    version.new_name = "New Lender"
    assert version.has_field_changes?
    
    # Lender type change
    version = LenderVersion.new
    version.previous_lender_type = 0  # futureproof
    version.new_lender_type = 1       # lender
    assert version.has_field_changes?
    
    # Contact email change
    version = LenderVersion.new
    version.previous_contact_email = "old@email.com"
    version.new_contact_email = "new@email.com"
    assert version.has_field_changes?
    
    # Country change
    version = LenderVersion.new
    version.previous_country = "Australia"
    version.new_country = "Canada"
    assert version.has_field_changes?
  end

  test "detailed_changes returns correctly formatted enum values" do
    version = LenderVersion.create!(
      lender: @lender,
      user: @user,
      action: "updated",
      change_details: "Updated lender details",
      previous_name: "Old Lender",
      new_name: "New Lender",
      previous_lender_type: 1,  # lender
      new_lender_type: 0,       # futureproof
      previous_contact_email: "old@email.com",
      new_contact_email: "new@email.com",
      previous_country: "Australia",
      new_country: "Canada"
    )
    
    changes = version.detailed_changes
    assert_equal 4, changes.length
    
    # Check name change
    name_change = changes.find { |c| c[:field] == 'Name' }
    assert_equal "Old Lender", name_change[:from]
    assert_equal "New Lender", name_change[:to]
    
    # Check lender type change with proper enum formatting
    type_change = changes.find { |c| c[:field] == 'Lender Type' }
    assert_equal "Lender", type_change[:from]
    assert_equal "Futureproof", type_change[:to]
    
    # Check email change
    email_change = changes.find { |c| c[:field] == 'Contact Email' }
    assert_equal "old@email.com", email_change[:from]
    assert_equal "new@email.com", email_change[:to]
    
    # Check country change
    country_change = changes.find { |c| c[:field] == 'Country' }
    assert_equal "Australia", country_change[:from]
    assert_equal "Canada", country_change[:to]
  end

  test "lender_type_label helper returns correct labels" do
    version = LenderVersion.new
    
    assert_equal "Futureproof", version.send(:lender_type_label, 0)
    assert_equal "Lender", version.send(:lender_type_label, 1)
    assert_equal "999", version.send(:lender_type_label, 999)  # Unknown value
  end

  test "scopes work correctly" do
    created_version = LenderVersion.create!(
      lender: @lender,
      user: @user,
      action: "created",
      change_details: "Created"
    )
    
    updated_version = LenderVersion.create!(
      lender: @lender,
      user: @user,
      action: "updated",
      change_details: "Updated"
    )
    
    viewed_version = LenderVersion.create!(
      lender: @lender,
      user: @user,
      action: "viewed",
      change_details: "Viewed"
    )
    
    # Test recent scope (should order by created_at desc)
    recent_versions = LenderVersion.recent
    assert_equal viewed_version, recent_versions.first
    
    # Test action-specific scopes
    assert_includes LenderVersion.by_action("created"), created_version
    assert_not_includes LenderVersion.by_action("created"), updated_version
    
    # Test changes_only scope
    changes_only = LenderVersion.changes_only
    assert_includes changes_only, created_version
    assert_includes changes_only, updated_version
    assert_not_includes changes_only, viewed_version
    
    # Test views_only scope
    views_only = LenderVersion.views_only
    assert_includes views_only, viewed_version
    assert_not_includes views_only, created_version
  end

  test "admin_user alias works" do
    version = LenderVersion.create!(
      lender: @lender,
      user: @user,
      action: "created",
      change_details: "Test"
    )
    
    assert_equal @user, version.admin_user
    assert_equal version.user, version.admin_user
  end
end