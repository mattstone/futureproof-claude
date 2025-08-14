require 'test_helper'

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  def setup
    @admin = users(:admin_user)
    @user = users(:john)
    sign_in @admin
  end

  test "should get index" do
    get admin_users_path
    assert_response :success
    assert_select 'table'
    assert_select 'td', @user.email
  end

  test "should filter users by search" do
    get admin_users_path, params: { search: @user.first_name }
    assert_response :success
    assert_select 'td', @user.email
  end

  test "should filter users by role" do
    get admin_users_path, params: { role: 'admin' }
    assert_response :success
    assert_select 'td', @admin.email
  end

  test "should filter users by status" do
    get admin_users_path, params: { status: 'active' }
    assert_response :success
  end

  test "should show user with change history" do
    # Create a user version first
    @user.user_versions.create!(
      admin_user: @admin,
      action: 'updated',
      change_details: 'Test update',
      previous_email: 'old@example.com',
      new_email: @user.email
    )
    
    get admin_user_path(@user)
    assert_response :success
    
    # Check that user details are shown
    assert_select 'div.detail-row', text: /Email:/
    assert_select 'div.detail-row', text: /#{@user.email}/
    
    # Check that change history section is present
    assert_select 'h3', text: 'Change History'
    assert_select 'div.change-entry'
    assert_select 'div.change-details', text: 'Test update'
  end

  test "should log view action when admin views user" do
    assert_difference '@user.user_versions.count', 1 do
      get admin_user_path(@user)
    end
    
    version = @user.user_versions.last
    assert_equal 'viewed', version.action
    assert_equal @admin, version.admin_user
    assert_includes version.change_details, @admin.display_name
  end

  test "should get new user form" do
    get new_admin_user_path
    assert_response :success
    assert_select 'form'
  end

  test "should create user with admin tracking" do
    user_params = {
      email: 'newuser@example.com',
      first_name: 'New',
      last_name: 'User',
      country_of_residence: 'Australia',
      admin: false,
      password: 'password123',
      password_confirmation: 'password123',
      terms_accepted: true
    }
    
    assert_difference 'User.count', 1 do
      post admin_users_path, params: { user: user_params }
    end
    
    new_user = User.find_by(email: 'newuser@example.com')
    assert_redirected_to admin_user_path(new_user)
    
    # Check that creation was logged
    creation_version = new_user.user_versions.find_by(action: 'created')
    assert creation_version
    assert_equal @admin, creation_version.admin_user
    assert_includes creation_version.change_details, 'Created user account'
  end

  test "should handle user creation validation errors" do
    user_params = {
      email: '', # Invalid email
      first_name: '',
      last_name: ''
    }
    
    assert_no_difference 'User.count' do
      post admin_users_path, params: { user: user_params }
    end
    
    assert_response :unprocessable_entity
    assert_select 'form'
  end

  test "should get edit user form" do
    get edit_admin_user_path(@user)
    assert_response :success
    assert_select 'form'
    assert_select 'input[value=?]', @user.first_name
  end

  test "should update user with change tracking" do
    new_first_name = 'UpdatedName'
    
    patch admin_user_path(@user), params: { 
      user: { 
        first_name: new_first_name,
        last_name: @user.last_name,
        email: @user.email,
        country_of_residence: @user.country_of_residence
      } 
    }
    
    assert_redirected_to admin_user_path(@user)
    @user.reload
    assert_equal new_first_name, @user.first_name
    
    # Check that update was logged
    update_version = @user.user_versions.where(action: 'updated').last
    assert update_version
    assert_equal @admin, update_version.admin_user
    assert_equal @user.first_name, update_version.new_first_name
  end

  test "should update user password" do
    new_password = 'newpassword123'
    
    patch admin_user_path(@user), params: { 
      user: { 
        first_name: @user.first_name,
        last_name: @user.last_name,
        email: @user.email,
        country_of_residence: @user.country_of_residence,
        password: new_password,
        password_confirmation: new_password
      } 
    }
    
    assert_redirected_to admin_user_path(@user)
    @user.reload
    assert @user.valid_password?(new_password)
  end

  test "should handle user update validation errors" do
    patch admin_user_path(@user), params: { 
      user: { 
        email: '', # Invalid email
        first_name: ''
      } 
    }
    
    assert_response :unprocessable_entity
    assert_select 'form'
  end

  test "should promote user to admin with tracking" do
    assert_not @user.admin?
    
    patch admin_user_path(@user), params: { 
      user: { 
        first_name: @user.first_name,
        last_name: @user.last_name,
        email: @user.email,
        country_of_residence: @user.country_of_residence,
        admin: true
      } 
    }
    
    @user.reload
    assert @user.admin?
    
    # Check that promotion was logged
    promotion_version = @user.user_versions.find_by(action: 'admin_promoted')
    assert promotion_version
    assert_equal @admin, promotion_version.admin_user
    assert_includes promotion_version.change_details, 'Promoted'
  end

  test "should demote admin to user with tracking" do
    admin_user = User.create!(
      email: 'testadmin@example.com',
      first_name: 'Test',
      last_name: 'Admin',
      country_of_residence: 'Australia',
      admin: true,
      password: 'password123',
      confirmed_at: Time.current,
      terms_accepted: true
    )
    admin_user.current_admin_user = @admin
    
    patch admin_user_path(admin_user), params: { 
      user: { 
        first_name: admin_user.first_name,
        last_name: admin_user.last_name,
        email: admin_user.email,
        country_of_residence: admin_user.country_of_residence,
        admin: false
      } 
    }
    
    admin_user.reload
    assert_not admin_user.admin?
    
    # Check that demotion was logged
    demotion_version = admin_user.user_versions.find_by(action: 'admin_demoted')
    assert demotion_version
    assert_equal @admin, demotion_version.admin_user
    assert_includes demotion_version.change_details, 'Removed admin privileges'
  end

  test "should not update password when blank" do
    original_encrypted_password = @user.encrypted_password
    
    patch admin_user_path(@user), params: { 
      user: { 
        first_name: 'Updated Name',
        password: '',
        password_confirmation: ''
      } 
    }
    
    @user.reload
    assert_equal original_encrypted_password, @user.encrypted_password
    assert_equal 'Updated Name', @user.first_name
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end