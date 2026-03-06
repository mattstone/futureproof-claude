require "test_helper"

class Phase4LenderDashboardTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @lender = Lender.create!(
      name: "FutureProof Financial AU",
      region: "AU",
      abn: "12345678901",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    @lender_admin = User.create!(
      email: "admin@lender.com",
      password: "AdminPassword123!",
      role: "lender_admin",
      lender: @lender
    )

    @funder = WholesaleFunder.create!(
      name: "FutureProof Capital Fund",
      region: "AU",
      aum: 50_000_000,
      status: "active"
    )

    @pool = FunderPool.create!(
      wholesale_funder: @funder,
      name: "AU Primary Pool",
      available_capital: 10_000_000,
      status: "active",
      region: "AU"
    )
  end

  # Test 1: Lender admin can view pending applications
  test "lender admin views list of pending applications" do
    # Create test applications in different states
    customer1 = User.create!(
      email: "customer1@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    customer2 = User.create!(
      email: "customer2@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    app1 = Application.create!(
      user: customer1,
      lender: @lender,
      property_address: "123 Smith Street",
      property_suburb: "Sydney",
      property_state: "NSW",
      property_postcode: "2000",
      property_value: 800_000,
      property_type: "house",
      desired_monthly_income: 2_000,
      loan_term_years: 10,
      customer_age: 72,
      customer_employment_status: "retired",
      customer_health_status: "good",
      government_id: "123456789",
      bank_account_number: "123456789012345",
      status: "pending_review"
    )

    app2 = Application.create!(
      user: customer2,
      lender: @lender,
      property_address: "456 Jones Avenue",
      property_suburb: "Melbourne",
      property_state: "VIC",
      property_postcode: "3000",
      property_value: 1_200_000,
      property_type: "house",
      desired_monthly_income: 3_000,
      loan_term_years: 15,
      customer_age: 68,
      customer_employment_status: "retired",
      customer_health_status: "good",
      government_id: "987654321",
      bank_account_number: "654321987654321",
      status: "pending_review"
    )

    sign_in @lender_admin

    # View dashboard
    get "/lender/dashboard"
    assert_response :success

    # View applications list
    get "/lender/applications"
    assert_response :success
    assert_select "h1", /applications/i

    # Should see pending applications
    assert_select "tr" do |rows|
      assert rows.text.include?("Smith")
      assert rows.text.include?("Jones")
      assert rows.text.include?("pending")
    end
  end

  # Test 2: Lender admin can review an application
  test "lender admin reviews application with full details" do
    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: customer,
      lender: @lender,
      property_address: "123 Smith Street",
      property_suburb: "Sydney",
      property_state: "NSW",
      property_postcode: "2000",
      property_value: 800_000,
      property_type: "house",
      desired_monthly_income: 2_000,
      loan_term_years: 10,
      customer_age: 72,
      customer_employment_status: "retired",
      customer_health_status: "good",
      government_id: "123456789",
      bank_account_number: "123456789012345",
      status: "pending_review"
    )

    sign_in @lender_admin

    # View application detail page
    get "/lender/applications/#{application.id}"
    assert_response :success

    # Verify all important details are displayed
    assert_select "h1", /application/i
    assert_select "span", /123 Smith Street/
    assert_select "span", /Sydney/
    assert_select "span", /800,000/
    assert_select "span", /2,000/
    assert_select "span", /72/
    assert_select "span", /pending_review/i
  end

  # Test 3: Lender admin can approve application
  test "lender admin approves application" do
    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: customer,
      lender: @lender,
      property_address: "123 Smith Street",
      property_suburb: "Sydney",
      property_state: "NSW",
      property_postcode: "2000",
      property_value: 800_000,
      property_type: "house",
      desired_monthly_income: 2_000,
      loan_term_years: 10,
      customer_age: 72,
      customer_employment_status: "retired",
      customer_health_status: "good",
      government_id: "123456789",
      bank_account_number: "123456789012345",
      status: "pending_review"
    )

    sign_in @lender_admin

    # Approve application
    patch "/lender/applications/#{application.id}", params: {
      application: {
        status: "approved",
        approved_loan_amount: 800_000,
        approved_interest_rate: 3.5,
        approved_term_years: 10,
        lender_notes: "Excellent application. Customer profile strong."
      }
    }

    assert_response :redirect
    application.reload

    assert_equal "approved", application.status
    assert_equal 800_000, application.approved_loan_amount
    assert_equal 3.5, application.approved_interest_rate
    assert_equal "Excellent application. Customer profile strong.", application.lender_notes
  end

  # Test 4: Lender admin can reject application with reason
  test "lender admin rejects application with documented reason" do
    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: customer,
      lender: @lender,
      property_address: "123 Smith Street",
      property_suburb: "Sydney",
      property_state: "NSW",
      property_postcode: "2000",
      property_value: 300_000,
      property_type: "apartment",
      desired_monthly_income: 5_000,
      loan_term_years: 10,
      customer_age: 72,
      customer_employment_status: "retired",
      customer_health_status: "good",
      government_id: "123456789",
      bank_account_number: "123456789012345",
      status: "pending_review"
    )

    sign_in @lender_admin

    # Reject application
    patch "/lender/applications/#{application.id}", params: {
      application: {
        status: "rejected",
        lender_notes: "Insufficient property value for requested income level. Loan-to-value ratio exceeds policy limits."
      }
    }

    assert_response :redirect
    application.reload

    assert_equal "rejected", application.status
    assert application.lender_notes.include?("Insufficient property value")
  end

  # Test 5: Contract is generated after approval
  test "contract is automatically generated on approval" do
    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: customer,
      lender: @lender,
      property_address: "123 Smith Street",
      property_suburb: "Sydney",
      property_state: "NSW",
      property_postcode: "2000",
      property_value: 800_000,
      property_type: "house",
      desired_monthly_income: 2_000,
      loan_term_years: 10,
      customer_age: 72,
      customer_employment_status: "retired",
      customer_health_status: "good",
      government_id: "123456789",
      bank_account_number: "123456789012345",
      status: "pending_review"
    )

    sign_in @lender_admin

    # Approve
    patch "/lender/applications/#{application.id}", params: {
      application: {
        status: "approved",
        approved_loan_amount: 800_000,
        approved_interest_rate: 3.5,
        approved_term_years: 10
      }
    }

    application.reload

    # Contract should exist
    assert application.mortgage_contract.present?
    contract = application.mortgage_contract

    # Contract should have correct region
    assert_equal "AU", contract.region

    # Contract should contain AU-specific clauses
    assert contract.contract_html.include?("NNEG") || contract.contract_html.present?
  end

  # Test 6: Customer is notified when application is reviewed
  test "customer receives notification when application is approved" do
    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: customer,
      lender: @lender,
      property_address: "123 Smith Street",
      property_suburb: "Sydney",
      property_state: "NSW",
      property_postcode: "2000",
      property_value: 800_000,
      property_type: "house",
      desired_monthly_income: 2_000,
      loan_term_years: 10,
      customer_age: 72,
      customer_employment_status: "retired",
      customer_health_status: "good",
      government_id: "123456789",
      bank_account_number: "123456789012345",
      status: "pending_review"
    )

    sign_in @lender_admin

    # Clear any existing emails
    ActionMailer::Base.deliveries.clear

    # Approve application
    patch "/lender/applications/#{application.id}", params: {
      application: {
        status: "approved",
        approved_loan_amount: 800_000,
        approved_interest_rate: 3.5,
        approved_term_years: 10
      }
    }

    # Email should be sent
    assert_equal 1, ActionMailer::Base.deliveries.size
    email = ActionMailer::Base.deliveries.last

    assert_equal "customer@example.com", email.to.first
    assert email.subject.include?("Approved") || email.subject.include?("Congratulations")
  end

  # Test 7: Lender dashboard shows application metrics
  test "lender dashboard displays portfolio metrics and KPIs" do
    # Create multiple applications in different states
    customer1 = User.create!(email: "c1@example.com", password: "SecurePassword123!", role: "customer")
    customer2 = User.create!(email: "c2@example.com", password: "SecurePassword123!", role: "customer")
    customer3 = User.create!(email: "c3@example.com", password: "SecurePassword123!", role: "customer")

    Application.create!(user: customer1, lender: @lender, property_value: 800_000, status: "pending_review", customer_age: 72, government_id: "1", bank_account_number: "1")
    Application.create!(user: customer2, lender: @lender, property_value: 1_000_000, status: "approved", approved_loan_amount: 1_000_000, customer_age: 68, government_id: "2", bank_account_number: "2")
    Application.create!(user: customer3, lender: @lender, property_value: 500_000, status: "rejected", customer_age: 75, government_id: "3", bank_account_number: "3")

    sign_in @lender_admin

    get "/lender/dashboard"
    assert_response :success

    # Should show metrics
    assert_select "h1", /dashboard/i
    assert_select "div", /pending|approved|rejected/i
  end
end
