require 'test_helper'

class Admin::ChangeHistoryVisualConsistencyTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications, :contracts, :application_versions, :contract_versions, :user_versions

  def setup
    @admin = users(:admin_user)
    @application = applications(:mortgage_application)
    @contract = contracts(:active_contract)
    @user = users(:jane)
    sign_in @admin
  end

  test "all change history sections use consistent admin-card styling" do
    # Test Applications
    get admin_application_path(@application)
    assert_response :success
    assert_select 'div.admin-card h3', text: 'Change History'
    
    # Test Contracts
    get admin_contract_path(@contract)
    assert_response :success
    assert_select 'div.admin-card h3', text: 'Change History'
    
    # Test Users
    get admin_user_path(@user)
    assert_response :success
    assert_select 'div.admin-card h3', text: 'Change History'
  end

  test "all change history sections have consistent structure" do
    pages_and_models = [
      [admin_application_path(@application), 'Application'],
      [admin_contract_path(@contract), 'Contract'],
      [admin_user_path(@user), 'User']
    ]

    pages_and_models.each do |page_path, model_name|
      get page_path
      assert_response :success, "#{model_name} page should load successfully"
      
      # Check for consistent change history structure
      assert_select 'div.admin-card'
      assert_select 'div.admin-card h3', text: 'Change History'
      assert_select 'p.section-subtitle', text: 'Track all modifications and views of this record'
      
      # Check for either change history list or empty state
      has_changes = !css_select('div.change-history-list').empty?
      has_empty_state = !css_select('div.empty-state').empty?
      
      assert(has_changes || has_empty_state, "#{model_name} should show either change history or empty state")
    end
  end

  test "change history entries have consistent styling when present" do
    # Create versions for testing
    @application.application_versions.create!(
      user: @admin,
      action: 'updated',
      change_details: 'Test application update'
    )
    
    @contract.contract_versions.create!(
      admin_user: @admin,
      action: 'updated',
      change_details: 'Test contract update'
    )
    
    @user.user_versions.create!(
      admin_user: @admin,
      action: 'updated',
      change_details: 'Test user update'
    )

    pages_and_models = [
      [admin_application_path(@application), 'Application'],
      [admin_contract_path(@contract), 'Contract'],
      [admin_user_path(@user), 'User']
    ]

    pages_and_models.each do |page_path, model_name|
      get page_path
      assert_response :success
      
      # Check for consistent change entry structure
      assert_select 'div.change-entry'
      assert_select 'div.change-header'
      assert_select 'div.change-info'
      assert_select 'span.change-action'
      assert_select 'time.change-time'
      assert_select 'div.change-details'
    end
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: 'password123' }
    }
  end
end