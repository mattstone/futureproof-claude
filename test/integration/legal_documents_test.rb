require "test_helper"

class LegalDocumentsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "borrower@test.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "John",
      last_name: "Doe",
      terms_accepted: true,
      confirmed_at: Time.current
    )

    @lender = Lender.create!(
      name: "Test Lender",
      contact_email: "lender@test.com",
      lender_type: :lender
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

  test "authenticated user can view their own key facts sheet" do
    sign_in @user
    get key_facts_sheet_path(application_id: @application.id, region: "au")

    assert_response :success
    assert_select "h1", "Key Facts Sheet"
    assert_select "p", "Equity Partner Mortgage — Summary of Terms"
    assert_select "table tr td", /Equity Investment Amount/
    assert_select "table tr td", /Equity Percentage/
    assert_select "table tr td", /Participation Term/
  end

  test "unauthenticated user is redirected to login" do
    get key_facts_sheet_path(application_id: @application.id, region: "au")
    assert_redirected_to new_user_session_path
  end

  test "user cannot view another user's key facts sheet" do
    other_user = User.create!(
      email: "other@test.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Jane",
      last_name: "Smith",
      terms_accepted: true,
      confirmed_at: Time.current
    )

    sign_in other_user
    get key_facts_sheet_path(application_id: @application.id, region: "au")

    assert_redirected_to dashboard_path
    assert_equal "Application not found or access denied.", flash[:alert]
  end
end
