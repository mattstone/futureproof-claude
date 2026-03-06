require "test_helper"

class EndToEndWorkflowTest < ActionDispatch::IntegrationTest
  # End-to-end test: Quote → Application → Approval → Distribution
  # This test verifies the complete EPM workflow
  
  setup do
    @lender = Lender.create!(
      name: "Test Lender",
      address: "123 Lender St",
      postcode: "2000",
      country: "AU",
      contact_email: "admin@lender.com",
      lender_type: "lender"
    )
  end

  test "complete workflow: customer gets quote, applies, lender approves, payment distributes" do
    # ===== PHASE 1: QUOTE GENERATION =====
    
    puts "\n[TEST] PHASE 1: Quote Generation"
    
    # Visitor can calculate a quote (no auth needed)
    get "/"
    assert_response :success
    
    # Quote should be calculable via service
    engine = CalculationEngine.new(
      home_value: 800_000,
      term: 10,
      region: "au"
    )
    
    result = engine.calculate
    quote = result[:quote]
    
    # Verify quote calculation
    assert quote[:monthly_income].present?
    assert quote[:loan_amount].present?
    assert quote[:interest_rate].present?
    assert result[:nneg_analysis].present?
    assert result[:estate_impact].present?
    
    quote_monthly_income = quote[:monthly_income]
    puts "  ✓ Quote generated: $#{quote_monthly_income.to_i}/month"
    
    # ===== PHASE 2: CUSTOMER REGISTRATION & APPLICATION =====
    
    puts "\n[TEST] PHASE 2: Registration & Application"
    
    # Customer registers
    customer_email = "e2e_test_#{Time.current.to_i}@example.com"
    customer_password = "SecurePassword123!"
    
    customer = User.create!(
      email: customer_email,
      password: customer_password,
      first_name: "John",
      last_name: "TestCustomer",
      role: :customer
    )
    
    puts "  ✓ Customer registered: #{customer_email}"
    
    # Customer submits application
    application = Application.create!(
      user: customer,
      home_value: 800_000,
      address: "123 Test Street",
      property_state: :primary_residence,
      ownership_status: :individual,
      borrower_age: 72,
      loan_term: 10,
      status: :processing,
      region: "au",
      property_type: "house"
    )
    
    # Verify application created
    assert application.persisted?
    assert_equal :processing, application.status
    assert_equal customer, application.user
    
    puts "  ✓ Application submitted (ID: #{application.id})"
    
    # ===== PHASE 3: LENDER REVIEW & APPROVAL =====
    
    puts "\n[TEST] PHASE 3: Lender Review & Approval"
    
    # Lender admin reviews application
    lender_admin = User.create!(
      email: "lender_admin_#{Time.current.to_i}@example.com",
      password: customer_password,
      role: :lender_admin,
      lender: @lender
    )
    
    # Approve application with specific terms
    approved_loan_amount = 600_000
    approved_interest_rate = 3.5
    approved_term_years = 10
    
    application.approve!(
      loan_amount: approved_loan_amount,
      interest_rate: approved_interest_rate,
      term_years: approved_term_years,
      lender: @lender
    )
    
    # Verify approval
    application.reload
    assert_equal :accepted, application.status
    assert_equal approved_loan_amount, application.approved_loan_amount
    assert_equal approved_interest_rate, application.approved_interest_rate
    assert_equal approved_term_years, application.approved_term_years
    assert_equal @lender, application.lender
    
    puts "  ✓ Application approved by lender"
    puts "    - Loan Amount: $#{approved_loan_amount.to_i}"
    puts "    - Interest Rate: #{approved_interest_rate}%"
    puts "    - Term: #{approved_term_years} years"
    
    # ===== PHASE 4: MONTHLY DISTRIBUTION =====
    
    puts "\n[TEST] PHASE 4: Payment Processing"
    
    # Process first monthly distribution
    service = PaymentProcessingService.new(application, 2026, 3)
    distribution = service.process_payment
    
    # Verify distribution
    assert distribution.persisted?
    assert_equal application, distribution.application
    assert distribution.amount > 0
    assert distribution.amount < approved_loan_amount  # Monthly payment < principal
    assert_equal :completed, distribution.status
    assert distribution.transaction_id.present?
    assert distribution.processed_at.present?
    
    # Calculate expected monthly payment
    monthly_rate = approved_interest_rate / 100 / 12
    num_payments = approved_term_years * 12
    expected_payment = (approved_loan_amount * (monthly_rate * (1 + monthly_rate) ** num_payments) / ((1 + monthly_rate) ** num_payments - 1)).round(2)
    
    assert_equal expected_payment, distribution.amount
    
    puts "  ✓ Monthly distribution processed"
    puts "    - Amount: $#{distribution.amount.to_i}"
    puts "    - Status: #{distribution.status}"
    puts "    - Transaction: #{distribution.transaction_id}"
    
    # ===== PHASE 5: VERIFY MULTIPLE MONTHS =====
    
    puts "\n[TEST] PHASE 5: Batch Distribution (Multiple Months)"
    
    # Process distributions for next 3 months
    3.times do |month|
      month_num = 3 + month + 1  # April, May, June
      service = PaymentProcessingService.new(application, 2026, month_num)
      dist = service.process_payment
      assert dist.persisted?
      assert_equal :completed, dist.status
    end
    
    # Verify application now has 4 distributions
    distributions = application.distributions.order(:distribution_date)
    assert_equal 4, distributions.count
    
    total_distributed = distributions.sum(:amount)
    puts "  ✓ 4 monthly distributions created"
    puts "    - Total distributed: $#{total_distributed.to_i}"
    
    # ===== FINAL ASSERTIONS =====
    
    puts "\n[TEST] FINAL VERIFICATION"
    
    # Verify complete workflow
    assert_equal 1, Application.where(status: :accepted).count
    assert_equal 4, Distribution.where(status: :completed).count
    
    # Lender margin tracking
    total_margin = distributions.sum(:lender_margin)
    assert total_margin > 0
    assert_equal (total_distributed * 0.01).round(2), total_margin
    
    puts "  ✓ Workflow complete:"
    puts "    - Customer registered: #{customer_email}"
    puts "    - Application approved: #{application.id}"
    puts "    - Lender: #{@lender.name}"
    puts "    - Loan Amount: $#{approved_loan_amount.to_i}"
    puts "    - Payments processed: #{distributions.count}"
    puts "    - Total distributed: $#{total_distributed.to_i}"
    puts "    - Lender margin: $#{total_margin.to_i}"
    puts ""
    puts "  ✅ END-TO-END WORKFLOW VERIFIED"
  end
  
  test "distribution batch processing for all approved applications" do
    puts "\n[TEST] Batch Distribution Processing"
    
    # Create 3 approved applications
    customers = 3.times.map do |i|
      User.create!(
        email: "batch_customer_#{i}_#{Time.current.to_i}@example.com",
        password: "Password123!",
        role: :customer
      )
    end
    
    applications = customers.map do |customer|
      app = Application.create!(
        user: customer,
        home_value: 800_000,
        address: "Test Address #{customer.id}",
        property_state: :primary_residence,
        ownership_status: :individual,
        borrower_age: 72,
        loan_term: 10,
        status: :processing,
        region: "au",
        property_type: "house"
      )
      
      # Approve
      app.approve!(
        loan_amount: 500_000,
        interest_rate: 3.5,
        term_years: 10,
        lender: @lender
      )
      
      app
    end
    
    # Process batch
    results = PaymentProcessingService.process_monthly_distributions(2026, 3)
    
    # Verify batch results
    assert results[:success] >= 3
    assert results[:distributions].length >= 3
    
    results[:distributions].each do |dist|
      assert_equal :completed, dist.status
      assert dist.transaction_id.present?
    end
    
    puts "  ✓ Batch processing complete:"
    puts "    - Applications processed: #{results[:success]}"
    puts "    - Distributions created: #{results[:distributions].length}"
    puts "    - Total value: $#{results[:distributions].sum(&:amount).to_i}"
    puts ""
    puts "  ✅ BATCH PROCESSING VERIFIED"
  end

  test "approval workflow with rejection" do
    puts "\n[TEST] Application Rejection Workflow"
    
    customer = User.create!(
      email: "reject_customer_#{Time.current.to_i}@example.com",
      password: "Password123!",
      role: :customer
    )
    
    application = Application.create!(
      user: customer,
      home_value: 300_000,  # Small property
      address: "Small Property St",
      property_state: :primary_residence,
      ownership_status: :individual,
      borrower_age: 95,  # Very old
      loan_term: 10,
      status: :processing,
      region: "au",
      property_type: "apartment"
    )
    
    # Reject with reason
    reason = "Property value too low for requested terms. Age exceeds maximum acceptable."
    application.reject!(reason: reason)
    
    # Verify rejection
    application.reload
    assert_equal :rejected, application.status
    assert_equal reason, application.rejected_reason
    
    # No distributions should be created
    assert_equal 0, application.distributions.count
    
    puts "  ✓ Application rejected successfully"
    puts "    - Reason: #{reason}"
    puts "    - Status: #{application.status}"
    puts ""
    puts "  ✅ REJECTION WORKFLOW VERIFIED"
  end
end
