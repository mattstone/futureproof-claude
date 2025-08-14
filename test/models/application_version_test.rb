require 'test_helper'

class ApplicationVersionTest < ActiveSupport::TestCase
  fixtures :users, :applications, :application_versions

  def setup
    @application = applications(:mortgage_application)
    @admin = users(:admin_user)
    @version = application_versions(:mortgage_application_creation)
  end

  test "should belong to application and user" do
    assert_respond_to @version, :application
    assert_respond_to @version, :user
    assert_equal @application, @version.application
    assert_equal @admin, @version.user
  end

  test "should have admin_user alias for user" do
    assert_respond_to @version, :admin_user
    assert_equal @version.user, @version.admin_user
    assert_equal @admin, @version.admin_user
  end

  test "should provide correct action descriptions" do
    assert_equal 'created application', ApplicationVersion.new(action: 'created').action_description
    assert_equal 'updated application', ApplicationVersion.new(action: 'updated').action_description
    assert_equal 'viewed application', ApplicationVersion.new(action: 'viewed').action_description
    assert_equal 'changed application status', ApplicationVersion.new(action: 'status_changed').action_description
  end

  test "should format created_at correctly" do
    time = Time.zone.parse('2024-01-15 10:30:00')
    version = ApplicationVersion.new(created_at: time)
    assert_equal 'January 15, 2024 at 10:30 AM', version.formatted_created_at
  end

  test "should validate action presence and inclusion" do
    version = ApplicationVersion.new
    assert_not version.valid?
    assert_includes version.errors[:action], "can't be blank"

    version.action = 'invalid_action'
    assert_not version.valid?
    assert_includes version.errors[:action], "is not included in the list"

    version.action = 'created'
    # Note: This test only checks action validation, not overall validity
    version.validate
    assert_not version.errors[:action].any?
  end

  test "should have working scopes" do
    assert_respond_to ApplicationVersion, :recent
    assert_respond_to ApplicationVersion, :by_action
    assert_respond_to ApplicationVersion, :changes_only
    assert_respond_to ApplicationVersion, :views_only
  end

  test "should detect status changes correctly" do
    version_with_status_change = ApplicationVersion.new(
      previous_status: 4, # submitted
      new_status: 5       # processing
    )
    assert version_with_status_change.has_status_changes?

    version_without_status_change = ApplicationVersion.new(
      previous_status: 4,
      new_status: 4
    )
    assert_not version_without_status_change.has_status_changes?
  end

  test "should detect field changes correctly" do
    version_with_changes = ApplicationVersion.new(
      previous_home_value: 500000,
      new_home_value: 600000
    )
    assert version_with_changes.has_field_changes?
    assert version_with_changes.has_home_value_changes?

    version_without_changes = ApplicationVersion.new
    assert_not version_without_changes.has_field_changes?
  end

  test "should generate detailed changes correctly" do
    version = ApplicationVersion.new(
      previous_status: 4,         # submitted
      new_status: 5,              # processing
      previous_home_value: 500000,
      new_home_value: 600000
    )

    changes = version.detailed_changes
    assert_equal 2, changes.length

    status_change = changes.find { |c| c[:field] == 'Status' }
    assert_equal 'Submitted', status_change[:from]
    assert_equal 'Processing', status_change[:to]

    home_value_change = changes.find { |c| c[:field] == 'Home Value' }
    assert_equal '$500,000', home_value_change[:from]
    assert_equal '$600,000', home_value_change[:to]
  end
end