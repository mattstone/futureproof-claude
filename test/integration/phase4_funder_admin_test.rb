require "test_helper"

class Phase4FunderAdminTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @funder = WholesaleFunder.create!(
      name: "FutureProof Capital Fund",
      region: "AU",
      aum: 50_000_000,
      status: "active"
    )

    @funder_admin = User.create!(
      email: "funder@capital.com",
      password: "FunderPassword123!",
      role: "funder_admin",
      wholesale_funder: @funder
    )

    @platform_admin = User.create!(
      email: "platform@admin.com",
      password: "PlatformPassword123!",
      role: "platform_admin"
    )

    @lender = Lender.create!(
      name: "FutureProof Financial AU",
      region: "AU",
      abn: "12345678901",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    @pool = FunderPool.create!(
      wholesale_funder: @funder,
      name: "AU Primary Pool",
      available_capital: 10_000_000,
      status: "active",
      region: "AU"
    )
  end

  # Test 1: Funder can view portfolio and allocation
  test "funder admin views fund portfolio and pool allocation" do
    sign_in @funder_admin

    get "/funder/dashboard"
    assert_response :success

    # Should see fund metrics
    assert_select "h1", /portfolio|fund/i
    assert_select "span", /50,000,000|50M/
  end

  # Test 2: Funder can view pool details
  test "funder admin views pool details and capital allocation" do
    sign_in @funder_admin

    get "/funder/pools/#{@pool.id}"
    assert_response :success

    # Should see pool details
    assert_select "h1", /AU Primary Pool/
    assert_select "span", /10,000,000|10M/
    assert_select "span", /active/i
  end

  # Test 3: Platform admin can create email workflow
  test "platform admin creates email notification workflow" do
    sign_in @platform_admin

    # Access workflow creation page
    get "/admin/email_workflows/new"
    assert_response :success
    assert_select "h1", /email workflow|workflow/i

    # Create workflow
    post "/admin/email_workflows", params: {
      email_workflow: {
        name: "Application Approved Notification",
        description: "Sent when lender approves an application",
        trigger_event: "application_approved",
        recipient_type: "customer",
        template_type: "approval_notification",
        subject_line: "Your Application Has Been Approved",
        active: true
      }
    }

    assert_response :redirect
    workflow = EmailWorkflow.last

    assert_equal "Application Approved Notification", workflow.name
    assert_equal "application_approved", workflow.trigger_event
    assert_equal "customer", workflow.recipient_type
  end

  # Test 4: Email workflow triggers on application approval
  test "email is sent when application is approved (workflow trigger)" do
    lender_admin = User.create!(
      email: "admin@lender.com",
      password: "AdminPassword123!",
      role: "lender_admin",
      lender: @lender
    )

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

    # Create email workflow
    EmailWorkflow.create!(
      name: "Application Approved Notification",
      trigger_event: "application_approved",
      recipient_type: "customer",
      template_type: "approval_notification",
      subject_line: "Congratulations! Your Application is Approved",
      active: true
    )

    sign_in lender_admin

    # Clear deliveries
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

  # Test 5: Platform admin can view all applications across all lenders
  test "platform admin views all applications across platform" do
    lender1 = @lender
    lender2 = Lender.create!(
      name: "Pacific Coast Lending",
      region: "AU",
      abn: "98765432109",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    customer1 = User.create!(email: "c1@example.com", password: "SecurePassword123!", role: "customer")
    customer2 = User.create!(email: "c2@example.com", password: "SecurePassword123!", role: "customer")

    app1 = Application.create!(
      user: customer1,
      lender: lender1,
      property_value: 800_000,
      status: "approved",
      approved_loan_amount: 800_000,
      customer_age: 72,
      government_id: "1",
      bank_account_number: "1"
    )

    app2 = Application.create!(
      user: customer2,
      lender: lender2,
      property_value: 1_000_000,
      status: "pending_review",
      customer_age: 68,
      government_id: "2",
      bank_account_number: "2"
    )

    sign_in @platform_admin

    get "/admin/applications"
    assert_response :success

    # Should see applications from both lenders
    assert_select "h1", /applications/i
    assert_select "tr" do |rows|
      assert rows.text.include?("FutureProof Financial AU") || rows.text.include?("Pacific Coast")
    end
  end

  # Test 6: Platform admin can generate reports
  test "platform admin generates platform-wide reports" do
    # Create some applications
    customer = User.create!(email: "customer@example.com", password: "SecurePassword123!", role: "customer")
    Application.create!(
      user: customer,
      lender: @lender,
      property_value: 800_000,
      status: "approved",
      approved_loan_amount: 800_000,
      customer_age: 72,
      government_id: "1",
      bank_account_number: "1"
    )

    sign_in @platform_admin

    get "/admin/reports"
    assert_response :success

    # Report options should be available
    assert_select "h1", /reports/i
    assert_select "button|link", /application|portfolio|performance/i
  end

  # Test 7: Funder can export pool data
  test "funder admin exports pool performance data" do
    # Create some applications tied to the pool
    lender_admin = User.create!(
      email: "admin@lender.com",
      password: "AdminPassword123!",
      role: "lender_admin",
      lender: @lender
    )

    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: customer,
      lender: @lender,
      funder_pool: @pool,
      property_value: 800_000,
      status: "approved",
      approved_loan_amount: 800_000,
      customer_age: 72,
      government_id: "1",
      bank_account_number: "1"
    )

    sign_in @funder_admin

    get "/funder/pools/#{@pool.id}/export"
    assert_response :success

    # Should have CSV/download content
    assert_equal "text/csv; charset=utf-8", response.content_type
  end

  # Test 8: Investment partner dashboard shows fund performance
  test "investment partner views fund performance metrics" do
    investment_partner = User.create!(
      email: "investor@funds.com",
      password: "InvestorPassword123!",
      role: "investment_partner",
      investment_partner: InvestmentPartner.create!(
        name: "Pacific Growth Investments",
        region: "AU",
        aum: 100_000_000,
        portfolio_strategy: "growth",
        fee_rate: 0.01,
        licence_number: "AB123456"
      )
    )

    sign_in investment_partner

    get "/investor/dashboard"
    assert_response :success

    # Should see fund performance
    assert_select "h1", /portfolio|performance|investment/i
  end

  # Test 9: Broker can submit applications on behalf of customers
  test "broker submits application for customer" do
    broker = User.create!(
      email: "broker@mortgages.com",
      password: "BrokerPassword123!",
      role: "broker"
    )

    sign_in broker

    # Submit application
    post "/applications", params: {
      application: {
        customer_email: "newcustomer@example.com",
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
        broker_id: broker.id
      }
    }

    assert_response :redirect
    application = Application.last

    assert_equal "newcustomer@example.com", application.user.email
    assert_equal broker.id, application.broker_id
  end

  # Test 10: Compliance officer can audit all operations
  test "compliance officer audits all user actions and data changes" do
    compliance_officer = User.create!(
      email: "compliance@futureproof.com",
      password: "CompliancePassword123!",
      role: "compliance_officer"
    )

    customer = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    application = Application.create!(
      user: customer,
      lender: @lender,
      property_value: 800_000,
      status: "pending_review",
      customer_age: 72,
      government_id: "123456789",
      bank_account_number: "123456789012345"
    )

    sign_in compliance_officer

    # Access audit trail
    get "/compliance/audit_log"
    assert_response :success

    assert_select "h1", /audit|compliance/i
  end
end
