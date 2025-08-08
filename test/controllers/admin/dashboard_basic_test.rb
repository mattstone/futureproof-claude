require "test_helper"

class Admin::DashboardBasicTest < ActionDispatch::IntegrationTest
  fixtures :none
  
  def setup
    User.delete_all
    @admin = User.create!(
      email: 'admin@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Admin',
      last_name: 'Test',
      admin: true,
      country_of_residence: 'AU',
      confirmed_at: Time.current,
      terms_version: 1
    )
  end
  
  def teardown
    User.delete_all
  end

  test "admin can access dashboard" do
    post user_session_path, params: {
      user: { email: @admin.email, password: 'password123' }
    }
    follow_redirect!
    
    get admin_dashboard_index_path
    assert_response :success
    # The h1 is now in the layout, so just check the page loads successfully
    assert_match /Back Office Dashboard/, response.body
  end

  test "dashboard displays basic structure" do
    post user_session_path, params: {
      user: { email: @admin.email, password: 'password123' }
    }
    follow_redirect!
    
    get admin_dashboard_index_path
    
    # Check basic structure exists
    assert_select ".metric-card"
    assert_select ".growth-chart"
    assert_select ".dashboard-grid"
  end
end