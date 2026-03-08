require "test_helper"

class LoanActivationTest < ActionDispatch::IntegrationTest
  setup do
    @lender = Lender.create!(
      name: "Test Lender",
      contact_email: "lender@test.com",
      lender_type: :lender
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

    @application = @user.applications.create!(
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
  end

  test "authenticated user can view loan activation page" do
    sign_in @user
    get loan_activation_path(:au, @application)

    assert_response :success
    assert_select "h1", /Activate Your EPM Investment/
    assert_select "h2", /Before You Activate/
  end

  test "unauthenticated user is redirected to login" do
    get loan_activation_path(:au, @application)
    assert_redirected_to new_user_session_path
  end

  test "user cannot activate non-accepted application" do
    # Create a pending application
    pending_app = @user.applications.create!(
      status: :submitted,
      region: :au,
      property_type: :house,
      address: "456 Oak Ave, Sydney, NSW 2000",
      home_value: 500000,
      borrower_names: "John Doe",
      borrower_age: 35,
      ownership_status: :individual,
      equity_investment_amount: 200000,
      equity_percentage: 20.0,
      participation_term_years: 10,
      lender: @lender
    )

    sign_in @user
    post loan_activation_confirm_path(:au, pending_app)

    assert_redirected_to borrower_portal_path(:au, pending_app)
    assert_equal "EPM investment is not approved.", flash[:alert]
  end

  test "activate creates distribution and updates status" do
    sign_in @user
    
    # Verify application is in accepted status
    assert @application.status_accepted?
    assert_equal 0, @application.distributions.count

    # Activate the application
    post loan_activation_confirm_path(:au, @application)

    # Verify status changed to activated
    @application.reload
    assert @application.status_activated?
    assert_redirected_to borrower_portal_path(:au, @application)
    assert_equal "EPM Investment activated successfully! Your equity capital disbursement is pending.", flash[:notice]
  end

  test "activate creates initial distribution" do
    sign_in @user
    
    # Activate the application
    post loan_activation_confirm_path(:au, @application)

    # Verify distribution was created
    @application.reload
    assert_equal 1, @application.distributions.count
    
    distribution = @application.distributions.first
    assert_equal @application.equity_investment_amount, distribution.amount
    assert_equal Date.current, distribution.distribution_date
    assert distribution.pending?
    assert_equal "Initial equity capital disbursement upon activation", distribution.notes
  end

  test "application model has activated status" do
    assert_includes Application.statuses.keys, "activated"
  end
end
