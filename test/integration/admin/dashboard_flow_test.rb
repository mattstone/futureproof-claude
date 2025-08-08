require "test_helper"

class Admin::DashboardFlowTest < ActionDispatch::IntegrationTest
  # Disable fixtures to avoid conflicts
  fixtures :none
  
  def setup
    # Clean up any existing data
    User.delete_all
    Application.delete_all
    UserVersion.delete_all
    ApplicationVersion.delete_all
    
    # Create test data with specific dates for growth testing
    @admin_user = User.create!(
      email: 'admin@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Admin',
      last_name: 'User',
      admin: true,
      country_of_residence: 'AU',
      confirmed_at: 2.months.ago,
      terms_version: 1,
      created_at: 2.months.ago
    )
    
    # Create users from different months for growth testing
    @user_last_month = User.create!(
      email: 'user1@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'User',
      last_name: 'One',
      admin: false,
      country_of_residence: 'AU',
      confirmed_at: 1.month.ago,
      terms_version: 1,
      created_at: 1.month.ago
    )
    
    @user_this_month = User.create!(
      email: 'user2@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'User',
      last_name: 'Two',
      admin: false,
      country_of_residence: 'AU',
      confirmed_at: 1.week.ago,
      terms_version: 1,
      created_at: 1.week.ago
    )
    
    # Create applications for conversion testing
    @application_last_month = Application.create!(
      user: @user_last_month,
      address: '123 Last Month St, Sydney NSW 2000',
      home_value: 1_000_000,
      ownership_status: :individual,
      property_state: :primary_residence,
      status: :submitted,
      growth_rate: 2.0,
      borrower_age: 60,
      created_at: 3.weeks.ago
    )
    
    @application_this_month = Application.create!(
      user: @user_this_month,
      address: '456 This Month Ave, Melbourne VIC 3000',
      home_value: 1_500_000,
      ownership_status: :joint,
      property_state: :investment,
      status: :accepted,
      growth_rate: 2.5,
      borrower_age: 45,
      created_at: 3.days.ago
    )
  end
  
  def teardown
    User.delete_all
    Application.delete_all
    UserVersion.delete_all
    ApplicationVersion.delete_all
  end

  test "admin can access dashboard and see all sections" do
    # Sign in as admin
    post user_session_path, params: {
      user: {
        email: @admin_user.email,
        password: 'password123'
      }
    }
    follow_redirect!
    
    # Navigate to dashboard
    get admin_dashboard_index_path
    assert_response :success
    
    # Verify dashboard structure
    assert_select "h1", "Back Office Dashboard"
    
    # Check all metric cards are present
    assert_select ".metric-card", 4
    assert_select ".metric-card h3", /\d+/ # Should have numeric values
    
    # Check growth charts are present
    assert_select ".growth-chart", 2
    assert_select ".growth-bar" # Should have growth bars
    
    # Check recent sections are present and populated
    assert_select ".recent-list"
    assert_select ".recent-item"
    
    # Check status distribution is present
    assert_select ".status-chart"
    assert_select ".status-bar"
    
    # Check activity feed is present
    assert_select ".activity-feed"
  end

  test "dashboard shows correct metrics and percentages" do
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
    follow_redirect!
    
    get admin_dashboard_index_path
    
    # Should show 3 total users
    assert_select ".metric-card", text: /3.*Total Users/m
    
    # Should show 2 accepted applications
    assert_select ".metric-card", text: /2.*Accepted Applications/m
    
    # Should show acceptance rate (2/2 = 100%)
    assert_select ".metric-percentage", text: /100\.0% acceptance rate/
  end

  test "dashboard links navigate correctly" do
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
    follow_redirect!
    
    get admin_dashboard_index_path
    
    # Test "View All" links
    assert_select "a[href='#{admin_applications_path}']", text: /View All/
    assert_select "a[href='#{admin_users_path}']", text: /View All/
    
    # Follow applications link
    get admin_applications_path
    assert_response :success
    
    # Go back to dashboard and follow users link
    get admin_dashboard_index_path
    get admin_users_path
    assert_response :success
  end

  test "dashboard handles real-time data updates" do
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
    follow_redirect!
    
    # Initial state
    get admin_dashboard_index_path
    assert_select ".metric-card", text: /3.*Total Users/m
    
    # Create a new user
    new_user = User.create!(
      email: 'newuser@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'New',
      last_name: 'User',
      admin: false,
      country_of_residence: 'AU',
      confirmed_at: Time.current,
      terms_version: 1
    )
    
    # Refresh dashboard - should show updated count
    get admin_dashboard_index_path
    assert_select ".metric-card", text: /4.*Total Users/m
  end

  test "dashboard shows growth trends correctly" do
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
    follow_redirect!
    
    get admin_dashboard_index_path
    
    # Should have 6 months of growth data
    assert_select ".growth-bar", count: 12 # 6 bars for each chart
    
    # Should have month labels
    assert_select ".growth-label span", text: /\w{3} \d{4}/
    
    # Should have growth values
    assert_select ".growth-label strong"
  end

  test "dashboard activity feed shows recent actions" do
    # Create some activity by having admin view an application
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
    follow_redirect!
    
    # Simulate admin viewing application (creates activity)
    @application_this_month.log_view_by(@admin_user)
    
    get admin_dashboard_index_path
    
    # Should show activity feed
    assert_select ".activity-feed"
    assert_select ".activity-item"
    
    # Should show admin name and action
    assert_select ".activity-header", text: /Admin User.*viewed application/
  end

  test "dashboard responsive design elements" do
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
    follow_redirect!
    
    get admin_dashboard_index_path
    
    # Check for responsive CSS classes and structure
    assert_select ".dashboard-grid" # Grid layout
    assert_select ".metrics-grid"   # Metrics grid
    assert_select ".full-width"     # Full width sections
    
    # Check that mobile-responsive elements are present
    assert_select ".metric-card" do
      assert_select ".metric-content"
      assert_select ".metric-icon"
    end
  end

  test "dashboard conversion rate calculation" do
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
    follow_redirect!
    
    get admin_dashboard_index_path
    
    # Should calculate conversion rates for each month
    assert_select ".conversion-chart .growth-bar"
    
    # Should show percentage values
    assert_select ".conversion-chart .growth-label strong", text: /%/
  end

  test "dashboard handles empty states gracefully" do
    # Clear all applications
    Application.delete_all
    
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
    follow_redirect!
    
    get admin_dashboard_index_path
    assert_response :success
    
    # Should show zero counts
    assert_select ".metric-card", text: /0.*Total Applications/m
    
    # Should show "no data" messages
    assert_select ".no-data", text: /No recent applications/
  end

  test "dashboard status badges display correctly" do
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
    follow_redirect!
    
    get admin_dashboard_index_path
    
    # Should show status badges for applications
    assert_select ".status-badge"
    
    # Should show different status types
    assert_select ".status-badge", text: /Submitted/
    assert_select ".status-badge", text: /Accepted/
  end
end