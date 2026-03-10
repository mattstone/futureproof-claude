require "test_helper"

class BorrowerEpmPortalTest < ActionDispatch::IntegrationTest
  fixtures :users, :applications, :lenders

  setup do
    @borrower = users(:regular_user)
    @app = applications(:mortgage_application)
    @app.update(user: @borrower)
    
    # Create lender for application
    @lender = Lender.create!(
      name: "Test Lender",
      lender_type: "lender",
      address: "123 Test St",
      postcode: "2000",
      country: "AU",
      contact_email: "contact@test.com"
    )
    @app.update(lender: @lender)
  end

  test "borrower can access loan dashboard" do
    sign_in @borrower
    get borrower_applications_path
    
    assert_response :success
    assert_select "h1", text: "My EPM Loans"
  end

  test "borrower can view application details" do
    sign_in @borrower
    get borrower_application_path(@app)
    
    assert_response :success
    assert_select "h1", text: "EPM Loan Details"
  end

  test "borrower cannot access other user's application" do
    other_user = User.create!(
      email: "other#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      password_confirmation: "password123",
      confirmed_at: Time.current,
      first_name: "Other",
      last_name: "User",
      terms_accepted: true
    )
    
    sign_in other_user
    get borrower_application_path(@app)
    
    assert_redirected_to borrower_root_path
    assert_equal "Access denied", flash[:alert]
  end

  test "unauthenticated user cannot access borrower portal" do
    get borrower_applications_path
    
    assert_redirected_to new_user_session_path
  end

  test "loan details show EPM fields" do
    sign_in @borrower
    get borrower_application_path(@app)
    
    assert_response :success
    # Should show EPM-specific fields
    assert_select "*", text: /Equity Capital/i
    assert_select "*", text: /Loan Term/i
    assert_select "*", text: /Property Value/i
    assert_select "*", text: /Your Equity/i
  end

  test "activated loan shows capital received" do
    @app.update(status: :activated)
    
    sign_in @borrower
    get borrower_application_path(@app)
    
    assert_response :success
    # Check for capital received section
    assert_select "*", text: /Capital Received/i
    assert_select "*", text: /Received/i
  end

  test "borrower root loads applications list" do
    sign_in @borrower
    get borrower_root_path
    
    assert_response :success
    assert_select "h1", text: "My EPM Loans"
  end
end
