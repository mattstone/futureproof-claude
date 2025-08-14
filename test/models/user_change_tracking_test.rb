require 'test_helper'

class UserChangeTrackingTest < ActiveSupport::TestCase
  fixtures :users

  def setup
    @admin = users(:admin_user)
    @user = users(:john)
  end

  test "should log creation when admin creates user" do
    new_user = User.new(
      email: 'testcreate@example.com',
      first_name: 'Test',
      last_name: 'Create',
      country_of_residence: 'Australia',
      admin: false,
      password: 'password123',
      confirmed_at: Time.current,
      terms_accepted: true
    )
    new_user.current_admin_user = @admin
    
    assert_difference 'UserVersion.count', 1 do
      new_user.save!
    end
    
    creation_version = new_user.user_versions.last
    assert_equal 'created', creation_version.action
    assert_equal @admin, creation_version.admin_user
    assert_includes creation_version.change_details, 'Created user account'
    assert_equal 'Test', creation_version.new_first_name
    assert_equal 'Create', creation_version.new_last_name
    assert_equal 'testcreate@example.com', creation_version.new_email
  end

  test "should not log creation when no admin user present" do
    new_user = User.new(
      email: 'nonadmincreate@example.com',
      first_name: 'NonAdmin',
      last_name: 'Create',
      country_of_residence: 'Australia',
      admin: false,
      password: 'password123',
      confirmed_at: Time.current,
      terms_accepted: true
    )
    # No current_admin_user set
    
    assert_no_difference 'UserVersion.count' do
      new_user.save!
    end
  end

  test "should log update when admin updates user" do
    @user.current_admin_user = @admin
    
    assert_difference '@user.user_versions.count', 1 do
      @user.update!(first_name: 'UpdatedName')
    end
    
    update_version = @user.user_versions.last
    assert_equal 'updated', update_version.action
    assert_equal @admin, update_version.admin_user
    assert_includes update_version.change_details, 'First name changed'
    assert_equal @user.first_name_before_last_save, update_version.previous_first_name
    assert_equal 'UpdatedName', update_version.new_first_name
  end

  test "should not log update when no changes made" do
    @user.current_admin_user = @admin
    
    assert_no_difference '@user.user_versions.count' do
      @user.save! # No actual changes
    end
  end

  test "should not log update when no admin user present" do
    # No current_admin_user set
    
    assert_no_difference '@user.user_versions.count' do
      @user.update!(first_name: 'NoAdminUpdate')
    end
  end

  test "should log admin promotion with special action" do
    @user.current_admin_user = @admin
    
    assert_difference '@user.user_versions.count', 1 do
      @user.update!(admin: true)
    end
    
    promotion_version = @user.user_versions.last
    assert_equal 'admin_promoted', promotion_version.action
    assert_includes promotion_version.change_details, 'Promoted'
    assert_equal false, promotion_version.previous_admin
    assert_equal true, promotion_version.new_admin
  end

  test "should log admin demotion with special action" do
    # Create a new admin user to demote
    admin_user = User.create!(
      email: 'demote_test@example.com',
      first_name: 'Test',
      last_name: 'Admin',
      country_of_residence: 'Australia',
      admin: true,
      password: 'password123',
      confirmed_at: Time.current,
      terms_accepted: true
    )
    admin_user.current_admin_user = @admin
    
    assert_difference 'admin_user.user_versions.count', 1 do
      admin_user.update!(admin: false)
    end
    
    demotion_version = admin_user.user_versions.last
    assert_equal 'admin_demoted', demotion_version.action
    assert_includes demotion_version.change_details, 'Removed admin privileges'
    assert_equal true, demotion_version.previous_admin
    assert_equal false, demotion_version.new_admin
  end

  test "should log confirmation with special action" do
    unconfirmed_user = User.create!(
      email: 'unconfirmed@example.com',
      first_name: 'Unconfirmed',
      last_name: 'User',
      country_of_residence: 'Australia',
      admin: false,
      password: 'password123',
      terms_accepted: true
      # confirmed_at left nil
    )
    unconfirmed_user.current_admin_user = @admin
    
    assert_difference 'unconfirmed_user.user_versions.count', 1 do
      unconfirmed_user.update!(confirmed_at: Time.current)
    end
    
    confirmation_version = unconfirmed_user.user_versions.last
    assert_equal 'confirmed', confirmation_version.action
    assert_includes confirmation_version.change_details, 'Confirmed user account'
    assert_nil confirmation_version.previous_confirmed_at
    assert_not_nil confirmation_version.new_confirmed_at
  end

  test "should build comprehensive change summary" do
    @user.current_admin_user = @admin
    
    @user.update!(
      first_name: 'NewFirst',
      last_name: 'NewLast',
      email: 'newemail@example.com',
      country_of_residence: 'Canada',
      mobile_country_code: '+61',
      mobile_number: '411111111'
    )
    
    update_version = @user.user_versions.last
    change_details = update_version.change_details
    
    assert_includes change_details, 'First name changed'
    assert_includes change_details, 'Last name changed'
    assert_includes change_details, 'Email changed'
    assert_includes change_details, 'Country changed'
    assert_includes change_details, 'Mobile number changed'
  end

  test "should handle mobile number formatting in changes" do
    @user.current_admin_user = @admin
    @user.update!(mobile_country_code: '+61', mobile_number: '400000000')
    
    # Now update mobile number
    @user.update!(mobile_number: '411111111')
    
    update_version = @user.user_versions.last
    assert_includes update_version.change_details, '+61 400000000'
    assert_includes update_version.change_details, '+61 411111111'
  end

  test "should log view action" do
    assert_difference '@user.user_versions.count', 1 do
      @user.log_view_by(@admin)
    end
    
    view_version = @user.user_versions.last
    assert_equal 'viewed', view_version.action
    assert_equal @admin, view_version.admin_user
    assert_includes view_version.change_details, @admin.display_name
    assert_includes view_version.change_details, 'viewed user profile'
  end

  test "should not log view action for non-admin user" do
    regular_user = users(:jane)
    regular_user.update!(admin: false) # Ensure not admin
    
    assert_no_difference '@user.user_versions.count' do
      @user.log_view_by(regular_user)
    end
  end

  test "should not log view action when user is nil" do
    assert_no_difference '@user.user_versions.count' do
      @user.log_view_by(nil)
    end
  end

  test "should track terms version changes" do
    @user.current_admin_user = @admin
    
    assert_difference '@user.user_versions.count', 1 do
      @user.update!(terms_version: 2)
    end
    
    update_version = @user.user_versions.last
    assert_includes update_version.change_details, 'Terms version changed'
    assert_equal @user.terms_version_before_last_save, update_version.previous_terms_version
    assert_equal 2, update_version.new_terms_version
  end

  test "should handle multiple field updates in single version" do
    @user.current_admin_user = @admin
    
    old_first_name = @user.first_name
    old_email = @user.email
    
    @user.update!(
      first_name: 'MultiUpdate',
      email: 'multi@example.com'
    )
    
    update_version = @user.user_versions.last
    
    # Check all fields are captured
    assert_equal old_first_name, update_version.previous_first_name
    assert_equal 'MultiUpdate', update_version.new_first_name
    assert_equal old_email, update_version.previous_email
    assert_equal 'multi@example.com', update_version.new_email
  end
end