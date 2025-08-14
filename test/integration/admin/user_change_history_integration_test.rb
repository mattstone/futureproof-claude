require 'test_helper'

class Admin::UserChangeHistoryIntegrationTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_versions

  def setup
    @admin = users(:admin_user)
    @user = users(:john)
    sign_in @admin
  end

  test "admin can view user change history" do
    # Visit the user show page
    get admin_user_path(@user)
    assert_response :success

    # Should show user details
    assert_select 'h2', text: @user.display_name
    assert_select 'div.detail-row', text: /Email:/
    assert_select 'div.detail-row', text: /#{@user.email}/

    # Should show change history section
    assert_select 'h3', text: 'Change History'
    assert_select 'div.versions-list'
    
    # Should show version entries from fixtures
    assert_select 'div.version-entry'
    assert_select 'div.version-meta', text: /#{@admin.display_name}/
  end

  test "admin updates create change history entries" do
    # Update user information
    new_first_name = 'UpdatedFirstName'
    new_last_name = 'UpdatedLastName'
    
    patch admin_user_path(@user), params: {
      user: {
        first_name: new_first_name,
        last_name: new_last_name,
        email: @user.email,
        country_of_residence: @user.country_of_residence
      }
    }
    
    assert_redirected_to admin_user_path(@user)
    follow_redirect!
    assert_response :success
    
    # Should show the updated information
    assert_select 'div.detail-row', text: /#{new_first_name}/
    assert_select 'div.detail-row', text: /#{new_last_name}/
    
    # Should show new change history entry
    assert_select 'div.version-entry' do
      assert_select 'span.version-action', text: 'updated user information'
      assert_select 'div.field-change', text: /First Name:/
      assert_select 'span.change-from', text: @user.first_name
      assert_select 'span.change-to', text: new_first_name
    end
  end

  test "viewing user creates view history entry" do
    initial_version_count = @user.user_versions.count
    
    get admin_user_path(@user)
    assert_response :success
    
    @user.reload
    assert_equal initial_version_count + 1, @user.user_versions.count
    
    # Check the new version is a view action
    latest_version = @user.user_versions.recent.first
    assert_equal 'viewed', latest_version.action
    assert_equal @admin, latest_version.admin_user
  end

  test "promoting user to admin creates promotion history" do
    regular_user = User.create!(
      email: 'promote_test@example.com',
      first_name: 'Promote',
      last_name: 'Test',
      country_of_residence: 'Australia',
      admin: false,
      password: 'password123',
      confirmed_at: Time.current,
      terms_accepted: true
    )
    regular_user.current_admin_user = @admin
    
    # Promote to admin
    patch admin_user_path(regular_user), params: {
      user: {
        first_name: regular_user.first_name,
        last_name: regular_user.last_name,
        email: regular_user.email,
        country_of_residence: regular_user.country_of_residence,
        admin: true
      }
    }
    
    assert_redirected_to admin_user_path(regular_user)
    follow_redirect!
    
    # Should show admin badge
    assert_select 'span.admin-badge-admin', text: 'Admin'
    
    # Should show promotion in change history
    assert_select 'div.version-entry' do
      assert_select 'span.version-action', text: 'promoted user to admin'
      assert_select 'div.field-change', text: /Role:/
      assert_select 'span.change-from', text: 'User'
      assert_select 'span.change-to', text: 'Admin'
    end
  end

  test "change history shows detailed field changes" do
    # Create a version with multiple field changes
    @user.user_versions.create!(
      admin_user: @admin,
      action: 'updated',
      change_details: 'Multiple field update test',
      previous_first_name: 'OldFirst',
      new_first_name: 'NewFirst',
      previous_email: 'old@example.com',
      new_email: 'new@example.com',
      previous_country_of_residence: 'Australia',
      new_country_of_residence: 'Canada'
    )
    
    get admin_user_path(@user)
    assert_response :success
    
    # Should show all field changes
    assert_select 'div.version-changes' do
      assert_select 'div.field-change', text: /First Name:/
      assert_select 'div.field-change', text: /Email:/
      assert_select 'div.field-change', text: /Country of Residence:/
      
      # Check change indicators
      assert_select 'span.change-from', text: 'OldFirst'
      assert_select 'span.change-to', text: 'NewFirst'
      assert_select 'span.change-arrow', text: '→'
    end
  end

  test "different actions have appropriate styling and descriptions" do
    # Create versions for different actions
    actions_to_test = [
      { action: 'created', description: 'created user account' },
      { action: 'updated', description: 'updated user information' },
      { action: 'viewed', description: 'viewed user profile' },
      { action: 'admin_promoted', description: 'promoted user to admin' },
      { action: 'admin_demoted', description: 'removed admin privileges' },
      { action: 'confirmed', description: 'confirmed user account' }
    ]
    
    actions_to_test.each do |test_case|
      @user.user_versions.create!(
        admin_user: @admin,
        action: test_case[:action],
        change_details: "Test #{test_case[:action]} action"
      )
    end
    
    get admin_user_path(@user)
    assert_response :success
    
    actions_to_test.each do |test_case|
      assert_select 'span.version-action', text: test_case[:description]
    end
  end

  test "change history respects limit and shows recent entries first" do
    # Create many versions (more than the 20 limit in controller)
    25.times do |i|
      @user.user_versions.create!(
        admin_user: @admin,
        action: 'viewed',
        change_details: "Test view #{i}",
        created_at: i.hours.ago
      )
    end
    
    get admin_user_path(@user)
    assert_response :success
    
    # Should only show 20 entries (as per controller limit)
    version_entries = css_select('div.version-entry')
    assert_operator version_entries.length, :<=, 20
    
    # Should show most recent first - check that we have entries in descending order
    # The most recent entry should be a 'viewed' action from our current page view
    assert_select 'div.version-entry:first-child' do
      assert_select 'span.version-action', text: 'viewed user profile'
    end
  end

  test "user with only view actions shows history correctly" do
    # Create a new user with no history
    new_user = User.create!(
      email: 'justviews@example.com',
      first_name: 'Just',
      last_name: 'Views',
      country_of_residence: 'Australia',
      admin: false,
      password: 'password123',
      confirmed_at: Time.current,
      terms_accepted: true
    )
    
    # Clear any auto-created versions except the one that will be created by viewing
    new_user.user_versions.destroy_all
    
    get admin_user_path(new_user)
    assert_response :success
    
    # Should show the view history that was just created
    assert_select 'div.version-entry'
    assert_select 'span.version-action', text: 'viewed user profile'
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end