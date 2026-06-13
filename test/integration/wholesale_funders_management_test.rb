require "test_helper"

class WholesaleFundersManagementTest < ActionDispatch::IntegrationTest
  setup do
    @lender = Lender.create!(
      name: "Test Lender AU",
      contact_email: "lender@test.com",
      country: "Australia",
      lender_type: :lender
    )

    # Find or use the existing Futureproof lender for the admin
    @futureproof_lender = Lender.find_by(lender_type: :futureproof) ||
      Lender.find_by(name: "Futureproof Financial Pty Ltd")

    @admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Admin",
      last_name: "User",
      admin: true,
      terms_accepted: true,
      confirmed_at: Time.current,
      lender: @futureproof_lender
    )

    @funder = WholesaleFunder.create!(
      name: "Capital Partners",
      country: "Australia",
      currency: "AUD",
      total_allocated_amount: 10_000_000
    )

    # Link lender to funder
    LenderWholesaleFunder.create!(
      lender: @lender,
      wholesale_funder: @funder,
      active: true
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
  end



  test "committed amount auto-calculates from active applications" do
    # Create application with this lender
    app = @user.applications.create!(
      status: :accepted,
      region: :au,
      property_type: :house,
      address: "123 Main St, Sydney",
      home_value: 500_000,
      borrower_names: "John Doe",
      borrower_age: 35,
      ownership_status: :individual,
      equity_investment_amount: 250_000,
      equity_percentage: 25.0,
      participation_term_years: 10,
      lender: @lender
    )

    @funder.reload
    assert_equal 250_000, @funder.committed_amount
  end

  test "available amount calculates correctly" do
    app = @user.applications.create!(
      status: :accepted,
      region: :au,
      property_type: :house,
      address: "123 Main St, Sydney",
      home_value: 500_000,
      borrower_names: "John Doe",
      borrower_age: 35,
      ownership_status: :individual,
      equity_investment_amount: 4_000_000,
      equity_percentage: 25.0,
      participation_term_years: 10,
      lender: @lender
    )

    @funder.reload
    assert_equal 10_000_000 - 4_000_000, @funder.available_amount
  end

  test "utilization percentage calculates correctly" do
    app = @user.applications.create!(
      status: :accepted,
      region: :au,
      property_type: :house,
      address: "123 Main St, Sydney",
      home_value: 500_000,
      borrower_names: "John Doe",
      borrower_age: 35,
      ownership_status: :individual,
      equity_investment_amount: 5_000_000,
      equity_percentage: 25.0,
      participation_term_years: 10,
      lender: @lender
    )

    @funder.reload
    assert_equal 50.0, @funder.utilization_percentage
  end

  test "runway calculation based on 12 months of distributions" do
    # Create application
    app = @user.applications.create!(
      status: :accepted,
      region: :au,
      property_type: :house,
      address: "123 Main St, Sydney",
      home_value: 500_000,
      borrower_names: "John Doe",
      borrower_age: 35,
      ownership_status: :individual,
      equity_investment_amount: 2_000_000,
      equity_percentage: 25.0,
      participation_term_years: 10,
      lender: @lender
    )

    # Create distributions over last 12 months
    # Average deployment = $1,000,000 / 12 months = ~$83,333/month
    12.times do |i|
      Distribution.create!(
        application: app,
        amount: 100_000,
        distribution_date: (i.months.ago).to_date,
        status: :completed,
        payment_method: "bank_transfer"
      )
    end

    @funder.reload
    # Available: 10M - 2M = 8M
    # Monthly avg: 1.2M / 12 = 0.1M
    # Runway: 8M / 0.1M = 80 months
    assert @funder.runway_months > 70, "Runway should be approximately 80 months"
  end

  test "wholesale funder can be updated directly" do
    @funder.update!(total_allocated_amount: 15_000_000)
    @funder.reload
    assert_equal 15_000_000, @funder.total_allocated_amount
  end

  test "unauthenticated user cannot access wholesale funders" do
    get admin_wholesale_funders_path
    assert_redirected_to new_user_session_path
  end

  test "non-admin user is denied access" do
    sign_in @user
    get admin_wholesale_funders_path
    assert_redirected_to root_path
  end

  test "only accepted applications count as committed" do
    # Pending application should NOT count
    pending_app = @user.applications.create!(
      status: :submitted,
      region: :au,
      property_type: :house,
      address: "456 Oak St, Sydney",
      home_value: 600_000,
      borrower_names: "John Doe",
      borrower_age: 35,
      ownership_status: :individual,
      equity_investment_amount: 3_000_000,
      equity_percentage: 25.0,
      participation_term_years: 10,
      lender: @lender
    )

    # Accepted application SHOULD count
    accepted_app = @user.applications.create!(
      status: :accepted,
      region: :au,
      property_type: :house,
      address: "789 Pine St, Sydney",
      home_value: 700_000,
      borrower_names: "John Doe",
      borrower_age: 35,
      ownership_status: :individual,
      equity_investment_amount: 2_000_000,
      equity_percentage: 25.0,
      participation_term_years: 10,
      lender: @lender
    )

    @funder.reload
    # Should only include accepted app (2M), not pending app (3M)
    assert_equal 2_000_000, @funder.committed_amount
  end
end
