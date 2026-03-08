require "test_helper"

class AdminDashboardV2IntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @lender = Lender.create!(
      name: "Test Lender",
      contact_email: "lender@test.com",
      lender_type: :lender
    )

    @admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Admin",
      last_name: "User",
      admin: true,
      terms_accepted: true,
      lender: @lender,
      confirmed_at: Time.current
    )

    @user = User.create!(
      email: "borrower@test.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "John",
      last_name: "Doe",
      terms_accepted: true,
      confirmed_at: Time.current
    )

    # Create test applications
    @approved_app = @user.applications.create!(
      status: :accepted,
      region: :au,
      property_type: :house,
      address: "123 Main St, Sydney, NSW 2000",
      home_value: 750000,
      borrower_names: "John Doe",
      borrower_age: 35,
      ownership_status: :individual,
      equity_investment_amount: 300000,
      equity_percentage: 25.0,
      participation_term_years: 10,
      lender: @lender
    )

    @pending_app = @user.applications.create!(
      status: :submitted,
      region: :us,
      property_type: :apartment,
      address: "456 Broadway, New York, NY 10001",
      home_value: 500000,
      borrower_names: "John Doe",
      borrower_age: 40,
      ownership_status: :individual,
      equity_investment_amount: 200000,
      equity_percentage: 20.0,
      participation_term_years: 10,
      lender: @lender
    )

    @rejected_app = @user.applications.create!(
      status: :rejected,
      region: :nz,
      property_type: :house,
      address: "789 Queen St, Auckland, NZ 1010",
      home_value: 600000,
      borrower_names: "John Doe",
      borrower_age: 45,
      ownership_status: :individual,
      equity_investment_amount: 250000,
      equity_percentage: 22.0,
      participation_term_years: 10,
      lender: @lender,
      rejected_reason: "Insufficient income"
    )

    # Create test distributions
    Distribution.create!(
      application: @approved_app,
      amount: 5000,
      status: :completed,
      distribution_date: Date.current,
      payment_method: "bank_transfer"
    )
    Distribution.create!(
      application: @approved_app,
      amount: 5000,
      status: :pending,
      distribution_date: Date.current.tomorrow,
      payment_method: "bank_transfer"
    )
    Distribution.create!(
      application: @approved_app,
      amount: 5000,
      status: :failed,
      distribution_date: Date.current.yesterday,
      payment_method: "bank_transfer"
    )
  end

  test "admin can access dashboard" do
    sign_in @admin
    get admin_root_path

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_select "p", "Real-time portfolio metrics and performance analytics"
  end

  test "dashboard shows correct portfolio KPIs" do
    sign_in @admin
    get admin_root_path

    assert_response :success
    # Should show 3 total applications
    assert_select "div", /3/
    # Should show capital deployed
    assert_select "p", /Capital Deployed/
  end

  test "dashboard shows application funnel" do
    sign_in @admin
    get admin_root_path

    assert_response :success
    assert_select "h2", /Application Funnel/
    assert_select "span", /Pending/
    assert_select "span", /Approved/
    assert_select "span", /Rejected/
  end

  test "dashboard shows distribution performance" do
    sign_in @admin
    get admin_root_path

    assert_response :success
    assert_select "h2", /Distribution Performance/
    assert_select "span", /Completed/
    assert_select "span", /Pending/
    assert_select "span", /Failed/
  end

  test "non-admin user is denied access" do
    sign_in @user
    get admin_root_path

    assert_redirected_to root_path
    assert_equal "Access denied.", flash[:alert]
  end

  test "unauthenticated user is redirected to login" do
    get admin_root_path
    assert_redirected_to new_user_session_path
  end
end
