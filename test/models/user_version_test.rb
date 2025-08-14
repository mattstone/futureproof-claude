require 'test_helper'

class UserVersionTest < ActiveSupport::TestCase
  fixtures :users, :user_versions

  def setup
    @admin = users(:admin_user)
    @user = users(:john)
    @user_version = user_versions(:john_update)
  end

  test "should belong to user and admin_user" do
    assert_respond_to @user_version, :user
    assert_respond_to @user_version, :admin_user
    assert_equal @user, @user_version.user
    assert_equal @admin, @user_version.admin_user
  end

  test "should validate action presence and inclusion" do
    version = UserVersion.new
    assert_not version.valid?
    assert_includes version.errors[:action], "can't be blank"

    version.action = "invalid_action"
    assert_not version.valid?
    assert_includes version.errors[:action], "is not included in the list"

    valid_actions = %w[created updated viewed admin_promoted admin_demoted confirmed]
    valid_actions.each do |action|
      version.action = action
      version.user = @user
      version.admin_user = @admin
      assert version.valid?, "Action '#{action}' should be valid"
    end
  end

  test "should provide correct action descriptions" do
    version = UserVersion.new
    
    assert_equal 'created user account', version.tap { |v| v.action = 'created' }.action_description
    assert_equal 'updated user information', version.tap { |v| v.action = 'updated' }.action_description
    assert_equal 'viewed user profile', version.tap { |v| v.action = 'viewed' }.action_description
    assert_equal 'promoted user to admin', version.tap { |v| v.action = 'admin_promoted' }.action_description
    assert_equal 'removed admin privileges', version.tap { |v| v.action = 'admin_demoted' }.action_description
    assert_equal 'confirmed user account', version.tap { |v| v.action = 'confirmed' }.action_description
    assert_equal 'custom_action', version.tap { |v| v.action = 'custom_action' }.action_description
  end

  test "should format created_at correctly" do
    version = UserVersion.create!(
      user: @user,
      admin_user: @admin,
      action: 'viewed',
      created_at: DateTime.new(2024, 8, 15, 14, 30, 0)
    )
    
    assert_equal "August 15, 2024 at 02:30 PM", version.formatted_created_at
  end

  test "should detect name changes correctly" do
    version = UserVersion.new(
      previous_first_name: "John",
      new_first_name: "Johnny",
      previous_last_name: "Smith", 
      new_last_name: "Johnson"
    )
    
    assert version.has_name_changes?
    
    # Test no changes
    version = UserVersion.new(
      previous_first_name: "John",
      new_first_name: "John"
    )
    assert_not version.has_name_changes?
  end

  test "should detect email changes correctly" do
    version = UserVersion.new(
      previous_email: "old@example.com",
      new_email: "new@example.com"
    )
    
    assert version.has_email_changes?
    
    version = UserVersion.new(
      previous_email: "same@example.com",
      new_email: "same@example.com"
    )
    assert_not version.has_email_changes?
  end

  test "should detect admin changes correctly" do
    version = UserVersion.new(
      previous_admin: false,
      new_admin: true
    )
    
    assert version.has_admin_changes?
    
    version = UserVersion.new(
      previous_admin: true,
      new_admin: true
    )
    assert_not version.has_admin_changes?
  end

  test "should detect country changes correctly" do
    version = UserVersion.new(
      previous_country_of_residence: "Australia",
      new_country_of_residence: "Canada"
    )
    
    assert version.has_country_changes?
  end

  test "should detect mobile changes correctly" do
    version = UserVersion.new(
      previous_mobile_number: "0400000000",
      new_mobile_number: "0411111111"
    )
    
    assert version.has_mobile_changes?
    
    version = UserVersion.new(
      previous_mobile_country_code: "+61",
      new_mobile_country_code: "+1"
    )
    
    assert version.has_mobile_changes?
  end

  test "should detect terms changes correctly" do
    version = UserVersion.new(
      previous_terms_version: 1,
      new_terms_version: 2
    )
    
    assert version.has_terms_changes?
  end

  test "should detect confirmation changes correctly" do
    version = UserVersion.new(
      previous_confirmed_at: nil,
      new_confirmed_at: Time.current
    )
    
    assert version.has_confirmation_changes?
  end

  test "should generate detailed changes correctly" do
    version = UserVersion.new(
      previous_first_name: "John",
      new_first_name: "Johnny",
      previous_email: "old@example.com", 
      new_email: "new@example.com",
      previous_admin: false,
      new_admin: true
    )
    
    changes = version.detailed_changes
    
    assert_equal 3, changes.length
    
    first_name_change = changes.find { |c| c[:field] == 'First Name' }
    assert_equal "John", first_name_change[:from]
    assert_equal "Johnny", first_name_change[:to]
    
    email_change = changes.find { |c| c[:field] == 'Email' }
    assert_equal "old@example.com", email_change[:from]
    assert_equal "new@example.com", email_change[:to]
    
    admin_change = changes.find { |c| c[:field] == 'Role' }
    assert_equal "User", admin_change[:from]
    assert_equal "Admin", admin_change[:to]
  end

  test "should have working scopes" do
    # Create test versions
    recent_version = UserVersion.create!(
      user: @user,
      admin_user: @admin,
      action: 'updated',
      created_at: 1.hour.ago
    )
    
    old_version = UserVersion.create!(
      user: @user,
      admin_user: @admin,
      action: 'viewed', 
      created_at: 1.day.ago
    )
    
    # Test recent scope (ordered by created_at desc)
    recent_versions = UserVersion.recent.limit(2)
    assert_equal recent_version, recent_versions.first
    
    # Test by_action scope
    updated_versions = UserVersion.by_action('updated')
    assert_includes updated_versions, recent_version
    assert_not_includes updated_versions, old_version
    
    # Test changes_only scope (excludes 'viewed')
    changes_versions = UserVersion.changes_only
    assert_includes changes_versions, recent_version
    assert_not_includes changes_versions, old_version
    
    # Test views_only scope
    view_versions = UserVersion.views_only
    assert_includes view_versions, old_version
    assert_not_includes view_versions, recent_version
  end
end