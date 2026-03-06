require "test_helper"

class Phase4QuoteToApprovalTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    # Create lender
    @lender = Lender.create!(
      name: "FutureProof Financial AU",
      region: "AU",
      abn: "12345678901",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    # Create wholesale funder and pool
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

  # Test 1: Visitor calculates quote
  test "visitor can calculate a quote" do
    get "/au"
    assert_response :success

    # Navigate to calculator
    get "/au/calculator"
    assert_response :success
    assert_select "form", /quote/i

    # Submit quote calculation
    post "/api/v1/quotes", params: {
      property_value: 800_000,
      age: 72,
      region: "AU",
      desired_income: 2_000,
      loan_term_years: 10
    }, headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :success
    response_body = JSON.parse(response.body)

    # Verify quote structure
    assert response_body["quote_id"].present?
    assert response_body["monthly_income"].present?
    assert response_body["loan_amount"].present?
    assert response_body["interest_rate"].present?
    assert response_body["nneg_probability"].present?
    assert response_body["estate_impact"]["projected_estate_value"].present?
  end

  # Test 2: Visitor creates account and submits application
  test "visitor can register and submit application from quote" do
    # Calculate quote first
    post "/api/v1/quotes", params: {
      property_value: 800_000,
      age: 72,
      region: "AU",
      desired_income: 2_000,
      loan_term_years: 10
    }, headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :success
    quote_id = JSON.parse(response.body)["quote_id"]

    # Register new user
    post "/users", params: {
      user: {
        email: "newcustomer@example.com",
        password: "SecurePassword123!",
        password_confirmation: "SecurePassword123!",
        first_name: "John",
        last_name: "Smith"
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_select "h1", /welcome/i

    # Login
    post "/users/sign_in", params: {
      user: {
        email: "newcustomer@example.com",
        password: "SecurePassword123!"
      }
    }

    assert_response :redirect
    follow_redirect!

    # Submit application with quote reference
    post "/applications", params: {
      application: {
        quote_id: quote_id,
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
        bank_account_number: "123456789012345"
      }
    }

    assert_response :redirect
    application = Application.last
    assert_equal "newcustomer@example.com", application.user.email
    assert_equal "pending_review", application.status
  end

  # Test 3: Admin/lender reviews application and approves
  test "lender can review and approve application" do
    # Create customer with application
    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      first_name: "John",
      last_name: "Smith",
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

    # Login as lender admin
    lender_admin = User.create!(
      email: "admin@lender.com",
      password: "AdminPassword123!",
      role: "lender_admin",
      lender: @lender
    )

    sign_in lender_admin

    # View application
    get "/lender/applications/#{application.id}"
    assert_response :success
    assert_select "span", /pending_review/i

    # Approve application
    patch "/lender/applications/#{application.id}", params: {
      application: {
        status: "approved",
        approved_loan_amount: 800_000,
        approved_interest_rate: 3.5,
        approved_term_years: 10,
        lender_notes: "Application approved. Customer meets all criteria."
      }
    }

    assert_response :redirect
    application.reload

    assert_equal "approved", application.status
    assert_equal 800_000, application.approved_loan_amount
    assert_equal 3.5, application.approved_interest_rate
  end

  # Test 4: Contract is generated for approved application
  test "contract is generated when application is approved" do
    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      first_name: "John",
      last_name: "Smith",
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

    lender_admin = User.create!(
      email: "admin@lender.com",
      password: "AdminPassword123!",
      role: "lender_admin",
      lender: @lender
    )

    sign_in lender_admin

    # Approve application
    patch "/lender/applications/#{application.id}", params: {
      application: {
        status: "approved",
        approved_loan_amount: 800_000,
        approved_interest_rate: 3.5,
        approved_term_years: 10
      }
    }

    application.reload

    # Verify contract was generated
    assert_equal "approved", application.status
    assert application.mortgage_contract.present?, "Contract should be generated for approved application"

    contract = application.mortgage_contract
    assert_equal "AU", contract.region
    assert contract.contract_html.present?
    assert contract.contract_html.include?("NNEG")
  end

  # Test 5: Customer sees active EPM on dashboard
  test "customer dashboard shows active EPM after approval" do
    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      first_name: "John",
      last_name: "Smith",
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
      status: "approved",
      approved_loan_amount: 800_000,
      approved_interest_rate: 3.5,
      approved_term_years: 10
    )

    # Create mortgage contract
    MortgageContract.create!(
      application: application,
      region: "AU",
      contract_html: "<h1>Mortgage Contract AU</h1><p>NNEG Clause</p>",
      status: "active",
      monthly_income: 2_000,
      nneg_probability: 0.15
    )

    sign_in customer

    # View customer dashboard
    get "/customer/dashboard"
    assert_response :success

    # Should see active EPM
    assert_select "div", /active.*epm/i
    assert_select "span", /2,000/ # Monthly income display
    assert_select "span", /Sydney/ # Property location
  end

  # Test 6: Full flow from quote to active EPM (happy path)
  test "complete flow: quote → registration → application → approval → active contract" do
    # Step 1: Calculate quote
    post "/api/v1/quotes", params: {
      property_value: 800_000,
      age: 72,
      region: "AU",
      desired_income: 2_000,
      loan_term_years: 10
    }, headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :success
    quote = JSON.parse(response.body)
    quote_id = quote["quote_id"]

    # Step 2: Register customer
    post "/users", params: {
      user: {
        email: "endtoend@example.com",
        password: "SecurePassword123!",
        password_confirmation: "SecurePassword123!",
        first_name: "John",
        last_name: "Smith"
      }
    }

    # Step 3: Login and apply
    post "/users/sign_in", params: {
      user: {
        email: "endtoend@example.com",
        password: "SecurePassword123!"
      }
    }

    customer = User.find_by(email: "endtoend@example.com")

    post "/applications", params: {
      application: {
        quote_id: quote_id,
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
        bank_account_number: "123456789012345"
      }
    }

    application = customer.applications.last
    assert_equal "pending_review", application.status

    # Step 4: Admin approves
    lender_admin = User.create!(
      email: "admin@lender.com",
      password: "AdminPassword123!",
      role: "lender_admin",
      lender: @lender
    )

    sign_in lender_admin

    application.update!(lender: @lender)

    patch "/lender/applications/#{application.id}", params: {
      application: {
        status: "approved",
        approved_loan_amount: 800_000,
        approved_interest_rate: 3.5,
        approved_term_years: 10
      }
    }

    application.reload
    assert_equal "approved", application.status
    assert application.mortgage_contract.present?

    # Step 5: Customer sees active EPM
    sign_in customer
    get "/customer/dashboard"
    assert_response :success
    assert_select "div", /active.*epm/i
  end
end
