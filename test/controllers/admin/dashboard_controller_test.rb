require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  # Disable fixtures to avoid conflicts
  fixtures :none
  
  def setup
    # Clean up any existing data
    User.delete_all
    Application.delete_all
    UserVersion.delete_all
    ApplicationVersion.delete_all
    
    # Create test users
    @admin_user = User.create!(
      email: 'admin@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Admin',
      last_name: 'User',
      admin: true,
      country_of_residence: 'AU',
      confirmed_at: Time.current,
      terms_version: 1
    )
    
    @regular_user = User.create!(
      email: 'user@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Regular',
      last_name: 'User',
      admin: false,
      country_of_residence: 'AU',
      confirmed_at: Time.current,
      terms_version: 1
    )
    
    @pending_user = User.create!(
      email: 'pending@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Pending',
      last_name: 'User',
      admin: false,
      country_of_residence: 'AU',
      confirmed_at: nil,
      terms_version: 1
    )
    
    # Create test applications
    @application = Application.create!(
      user: @regular_user,
      address: '123 Test Street, Sydney NSW 2000',
      home_value: 1_000_000,
      ownership_status: :individual,
      property_state: :primary_residence,
      status: :created,
      growth_rate: 2.0,
      borrower_age: 60
    )
    
    @submitted_application = Application.create!(
      user: @regular_user,
      address: '456 Test Avenue, Melbourne VIC 3000',
      home_value: 1_500_000,
      ownership_status: :joint,
      property_state: :investment,
      status: :submitted,
      growth_rate: 2.5,
      borrower_age: 45
    )
    
    @accepted_application = Application.create!(
      user: @regular_user,
      address: '789 Test Road, Brisbane QLD 4000',
      home_value: 800_000,
      ownership_status: :individual,
      property_state: :primary_residence,
      status: :accepted,
      growth_rate: 2.0,
      borrower_age: 55
    )
  end
  
  def teardown
    User.delete_all
    Application.delete_all
    UserVersion.delete_all
    ApplicationVersion.delete_all
  end

  test "should redirect non-admin users to root" do
    sign_in @regular_user
    get admin_dashboard_index_path
    assert_redirected_to root_path
    assert_match /Access denied/, flash[:alert]
  end

  test "should allow admin users to access dashboard" do
    sign_in @admin_user
    get admin_dashboard_index_path
    assert_response :success
    assert_select "h1", "Back Office Dashboard"
  end


  test "should calculate user statistics correctly" do
    sign_in @admin_user
    get admin_dashboard_index_path
    
    # Should have 3 total users (admin, regular, pending)
    assert_equal 3, assigns(:total_users)
    # Should have 2 active users (admin + regular, not pending)
    assert_equal 2, assigns(:active_users)
    # Should have 1 pending user
    assert_equal 1, assigns(:pending_users)
    # Should have 1 admin user
    assert_equal 1, assigns(:admin_users)
  end

  test "should calculate application statistics correctly" do
    sign_in @admin_user
    get admin_dashboard_index_path
    
    # Should have 3 total applications
    assert_equal 3, assigns(:total_applications)
    # Should have 2 submitted applications (submitted + accepted)
    assert_equal 2, assigns(:submitted_applications)
    # Should have 1 draft application (created)
    assert_equal 1, assigns(:draft_applications)
    # Should have 1 accepted application
    assert_equal 1, assigns(:accepted_applications)
    # Should have 0 rejected applications
    assert_equal 0, assigns(:rejected_applications)
  end

  test "should display status distribution" do
    sign_in @admin_user
    get admin_dashboard_index_path
    
    status_distribution = assigns(:status_distribution)
    assert status_distribution.is_a?(Hash)
    
    # Check that status labels are humanized
    assert status_distribution.key?('Created')
    assert status_distribution.key?('Submitted') 
    assert status_distribution.key?('Accepted')
    
    # Check counts
    assert_equal 1, status_distribution['Created']
    assert_equal 1, status_distribution['Submitted']
    assert_equal 1, status_distribution['Accepted']
  end

  test "should display recent applications with proper data" do
    sign_in @admin_user
    get admin_dashboard_index_path
    
    recent_applications = assigns(:recent_applications)
    assert recent_applications.size <= 5
    assert recent_applications.size >= 3 # We created 3 applications
    
    # Should be ordered by updated_at desc
    if recent_applications.size > 1
      assert recent_applications.first.updated_at >= recent_applications.second.updated_at
    end
  end

  test "should display recent users with proper data" do
    sign_in @admin_user
    get admin_dashboard_index_path
    
    recent_users = assigns(:recent_users)
    assert recent_users.size <= 5
    assert recent_users.size >= 3 # We created 3 users
    
    # Should be ordered by created_at desc  
    if recent_users.size > 1
      assert recent_users.first.created_at >= recent_users.second.created_at
    end
  end

  test "should display growth data" do
    sign_in @admin_user
    get admin_dashboard_index_path
    
    application_growth = assigns(:application_growth_data)
    conversion_growth = assigns(:conversion_growth_data)
    
    # Both should be hashes with month names as keys
    assert application_growth.is_a?(Hash)
    assert conversion_growth.is_a?(Hash)
    
    # Should have 6 months of data
    assert_equal 6, application_growth.size
    assert_equal 6, conversion_growth.size
    
    # Keys should be month names (e.g. "Jan 2024")
    application_growth.keys.each do |month|
      assert month.match?(/\w{3} \d{4}/)
    end
  end

  test "should render all dashboard sections in view" do
    sign_in @admin_user
    get admin_dashboard_index_path
    
    assert_response :success
    
    # Check for key metrics cards
    assert_select ".metric-card", 4
    assert_select ".metric-card", text: /Total Users/
    assert_select ".metric-card", text: /Active Users/
    assert_select ".metric-card", text: /Total Applications/
    assert_select ".metric-card", text: /Accepted Applications/
    
    # Check for growth charts
    assert_select ".growth-chart", 2
    assert_select "h3", text: /Application Growth/
    assert_select "h3", text: /Conversion Rate/
    
    # Check for recent sections
    assert_select "h3", text: /Recent Applications/
    assert_select "h3", text: /Recent Users/
    
    # Check for status distribution
    assert_select "h3", text: /Application Status Distribution/
    assert_select "h3", text: /User Activity Summary/
    
    # Check for recent activity feed
    assert_select "h3", text: /Recent Activity/
  end

  test "should handle conversion rate calculation edge cases" do
    # Test with no applications
    User.delete_all
    Application.delete_all
    
    admin = User.create!(
      email: 'admin@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Admin',
      last_name: 'User',
      admin: true,
      country_of_residence: 'AU',
      confirmed_at: Time.current,
      terms_version: 1
    )
    
    sign_in admin
    get admin_dashboard_index_path
    
    assert_response :success
    conversion_data = assigns(:conversion_growth_data)
    
    # All conversion rates should be 0 when no users/applications exist
    conversion_data.values.each do |rate|
      assert_equal 0, rate
    end
  end

  test "should create user versions when admin views applications" do
    # Create some user versions to test activity feed
    @application.log_view_by(@admin_user)
    
    sign_in @admin_user
    get admin_dashboard_index_path
    
    recent_user_activity = assigns(:recent_user_activity)
    recent_app_activity = assigns(:recent_app_activity)
    
    assert_not_nil recent_user_activity
    assert_not_nil recent_app_activity
    
    # Should include the view we just created
    assert recent_app_activity.any?
  end

  test "should handle dashboard access with minimal data" do
    # Clear all data except admin user
    Application.delete_all
    User.where.not(id: @admin_user.id).delete_all
    
    sign_in @admin_user
    get admin_dashboard_index_path
    
    assert_response :success
    
    # Should display zero counts gracefully
    assert_equal 1, assigns(:total_users) # Just admin
    assert_equal 0, assigns(:total_applications)
    assert_equal 0, assigns(:submitted_applications)
    assert_equal 0, assigns(:accepted_applications)
    
    # Should not crash on empty collections
    assert_equal 0, assigns(:recent_applications).size
    assert_equal 1, assigns(:recent_users).size # Just admin
  end

  test "should display correct page title and heading" do
    sign_in @admin_user
    get admin_dashboard_index_path
    
    assert_response :success
    # Page title is set via content_for and will appear in layout
    assert_equal "Back Office Dashboard", assigns(:page_title) || response.body.match(/<title[^>]*>.*?Back Office Dashboard.*?<\/title>/im)
  end

  test "should link to other admin sections" do
    sign_in @admin_user
    get admin_dashboard_index_path
    
    # Should have links to other admin sections
    assert_select "a[href='#{admin_applications_path}']", text: /View All/
    assert_select "a[href='#{admin_users_path}']", text: /View All/
    
    # Should have links to specific applications/users
    assert_select "a[href*='#{admin_application_path(@application)}']"
    assert_select "a[href*='#{admin_user_path(@regular_user)}']"
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: 'password123'
      }
    }
  end
end