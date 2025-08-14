require 'test_helper'

class Admin::ApplicationSharedChangeHistoryTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications, :application_versions

  def setup
    @admin = users(:admin_user)
    @application = applications(:mortgage_application)
    sign_in @admin
  end

  test "application show page uses shared change history partial" do
    get admin_application_path(@application)
    assert_response :success
    
    # Check that the shared change history structure is present
    assert_select 'div.admin-card h3', text: 'Change History'
    assert_select 'div.change-history-list'
    assert_select 'div.change-entry'
  end

  test "application change history displays correctly with shared partial" do
    get admin_application_path(@application)
    assert_response :success
    
    # Check that version information is displayed correctly
    assert_select 'div.change-entry' do
      assert_select 'strong', text: @admin.display_name
      assert_select 'span.change-action'
      assert_select 'time.change-time'
    end
  end

  test "application change history shows admin_user information" do
    # Create a version to test the admin_user alias
    version = @application.application_versions.create!(
      user: @admin,
      action: 'viewed',
      change_details: 'Test viewing application'
    )
    
    get admin_application_path(@application)
    assert_response :success
    
    # The page should display admin user information via admin_user alias
    assert_match @admin.display_name, response.body
    assert_match 'viewed application', response.body
  end

  test "application change history shows collapsible field changes" do
    # Create a version with field changes to test collapsible details
    @application.application_versions.create!(
      user: @admin,
      action: 'updated',
      change_details: 'Updated application information',
      previous_home_value: 500000,
      new_home_value: 600000,
      previous_address: 'Old Address',
      new_address: 'New Address'
    )
    
    get admin_application_path(@application)
    assert_response :success
    
    # Check that collapsible details structure is present
    assert_select 'details.change-diff'
    assert_select 'summary', text: 'View Changes'
    assert_select 'div.field-changes'
    assert_select 'div.change-comparison'
    assert_select 'div.change-from', text: /Old Address/
    assert_select 'div.change-to', text: /New Address/
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end