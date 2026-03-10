require 'test_helper'

# Integration tests for broker commission workflow
# Tests: auto-calc on approval, status transitions, period filtering, dashboard totals
class BrokerCommissionWorkflowTest < ActionDispatch::IntegrationTest
  fixtures :lenders, :users, :brokers

  setup do
    @lender = lenders(:futureproof)
    @broker = brokers(:one)
    @user = users(:regular_user)
    @user.update!(lender: nil)
    sign_in @broker
  end

  # Helper to create a valid test lender
  def create_test_lender
    Lender.create!(
      name: "Test Lender #{SecureRandom.hex(4)}",
      lender_type: 'lender',
      address: '123 Test St',
      postcode: '2000',
      country: 'AU',
      contact_email: "contact#{SecureRandom.hex(4)}@test.com"
    )
  end

  # Test 1: Commission auto-calc on approval
  test "commission auto-created when application approved" do
    # Setup: Create rate + app
    lender = create_test_lender
    rate = BrokerCommissionRate.create!(
      broker: @broker, lender: lender,
      commission_percentage: 2.5, payment_trigger: 'on_approval', active: true
    )
    
    app = Application.create!(
      broker: @broker, lender: lender, user: @user,
      status: :created, property_value: 500000, loan_amount: 400000,
      applicant_name: 'Test', property_address: 'St', property_suburb: 'S', property_state: 'NSW', property_postcode: '2000'
    )

    # Action: Approve
    assert_difference('BrokerCommission.count', 1) do
      app.approve!(loan_amount: 400000, interest_rate: 5.5, term_years: 20, lender: lender)
    end

    # Verify
    commission = BrokerCommission.find_by(application: app)
    assert_equal 10000.0, commission.commission_amount  # 2.5% of 400k
    assert_equal 'earned', commission.status
  end

  test "commission amount calculated from rate" do
    lender = create_test_lender
    rate = BrokerCommissionRate.create!(
      broker: @broker, lender: lender,
      commission_percentage: 3.0, payment_trigger: 'on_approval', active: true
    )
    
    app = Application.create!(
      broker: @broker, lender: lender, user: @user,
      status: :created, property_value: 625000, loan_amount: 500000,
      applicant_name: 'Test', property_address: 'St', property_suburb: 'S', property_state: 'NSW', property_postcode: '2000'
    )

    app.approve!(loan_amount: 500000, interest_rate: 5.5, term_years: 20, lender: lender)

    assert_equal 15000.0, app.broker_commission.commission_amount  # 3.0% of 500k
  end

  # Test 2: Status transitions
  test "commission transitions earned to paid" do
    lender = create_test_lender
    rate = BrokerCommissionRate.create!(
      broker: @broker, lender: lender,
      commission_percentage: 2.5, payment_trigger: 'on_approval', active: true
    )
    
    app = Application.create!(
      broker: @broker, lender: lender, user: @user,
      status: :created, property_value: 500000, loan_amount: 400000,
      applicant_name: 'Test', property_address: 'St', property_suburb: 'S', property_state: 'NSW', property_postcode: '2000'
    )

    app.approve!(loan_amount: 400000, interest_rate: 5.5, term_years: 20, lender: lender)
    
    commission = app.broker_commission
    assert_equal 'earned', commission.status
    
    commission.mark_as_paid!
    commission.reload
    
    assert_equal 'paid', commission.status
    assert_not_nil commission.paid_date
  end

  test "pending trigger results in pending status" do
    lender = create_test_lender
    rate = BrokerCommissionRate.create!(
      broker: @broker, lender: lender,
      commission_percentage: 2.5, payment_trigger: 'on_funding', active: true
    )
    
    app = Application.create!(
      broker: @broker, lender: lender, user: @user,
      status: :created, property_value: 500000, loan_amount: 400000,
      applicant_name: 'Test', property_address: 'St', property_suburb: 'S', property_state: 'NSW', property_postcode: '2000'
    )

    app.approve!(loan_amount: 400000, interest_rate: 5.5, term_years: 20, lender: lender)
    
    assert_equal 'pending', app.broker_commission.status
    assert_nil app.broker_commission.earned_date
  end

  # Test 3: Period filtering
  test "period filtering retrieves correct commissions" do
    lender = create_test_lender
    rate = BrokerCommissionRate.create!(
      broker: @broker, lender: lender,
      commission_percentage: 2.5, payment_trigger: 'on_approval', active: true
    )
    
    # Recent app (this month)
    app_recent = Application.create!(
      broker: @broker, lender: lender, user: @user,
      status: :created, property_value: 500000, loan_amount: 400000,
      applicant_name: 'Recent', property_address: 'St', property_suburb: 'S', property_state: 'NSW', property_postcode: '2000',
      created_at: 5.days.ago
    )
    
    # Old app (2 months ago)
    app_old = Application.create!(
      broker: @broker, lender: lender, user: @user,
      status: :created, property_value: 500000, loan_amount: 400000,
      applicant_name: 'Old', property_address: 'St', property_suburb: 'S', property_state: 'NSW', property_postcode: '2000',
      created_at: 2.months.ago
    )

    app_recent.approve!(loan_amount: 400000, interest_rate: 5.5, term_years: 20, lender: lender)
    app_old.approve!(loan_amount: 400000, interest_rate: 5.5, term_years: 20, lender: lender)

    # Query last month
    period_start = 1.month.ago.beginning_of_month
    period_end = Time.current.end_of_month

    commissions = BrokerCommissionCalculator.commissions_by_period(@broker, period_start, period_end)

    assert_includes commissions.map(&:id), app_recent.broker_commission.id
    assert_not_includes commissions.map(&:id), app_old.broker_commission.id
  end

  # Test 4: Dashboard totals
  test "total earned commissions calculated correctly" do
    lender = create_test_lender
    rate = BrokerCommissionRate.create!(
      broker: @broker, lender: lender,
      commission_percentage: 2.5, payment_trigger: 'on_approval', active: true
    )
    
    app1 = Application.create!(
      broker: @broker, lender: lender, user: @user,
      status: :created, property_value: 500000, loan_amount: 400000,
      applicant_name: 'App1', property_address: 'St', property_suburb: 'S', property_state: 'NSW', property_postcode: '2000'
    )
    
    app2 = Application.create!(
      broker: @broker, lender: lender, user: @user,
      status: :created, property_value: 625000, loan_amount: 500000,
      applicant_name: 'App2', property_address: 'St', property_suburb: 'S', property_state: 'NSW', property_postcode: '2000'
    )

    app1.approve!(loan_amount: 400000, interest_rate: 5.5, term_years: 20, lender: lender)
    app2.approve!(loan_amount: 500000, interest_rate: 5.5, term_years: 20, lender: lender)

    total = BrokerCommissionCalculator.total_earned_commissions(@broker)
    expected = (400000 * 0.025) + (500000 * 0.025)
    
    assert_equal expected, total
  end

  test "unpaid commissions tracked separately" do
    lender = create_test_lender
    rate = BrokerCommissionRate.create!(
      broker: @broker, lender: lender,
      commission_percentage: 2.5, payment_trigger: 'on_approval', active: true
    )
    
    app1 = Application.create!(
      broker: @broker, lender: lender, user: @user,
      status: :created, property_value: 500000, loan_amount: 400000,
      applicant_name: 'App1', property_address: 'St', property_suburb: 'S', property_state: 'NSW', property_postcode: '2000'
    )
    
    app2 = Application.create!(
      broker: @broker, lender: lender, user: @user,
      status: :created, property_value: 500000, loan_amount: 400000,
      applicant_name: 'App2', property_address: 'St', property_suburb: 'S', property_state: 'NSW', property_postcode: '2000'
    )

    app1.approve!(loan_amount: 400000, interest_rate: 5.5, term_years: 20, lender: lender)
    app2.approve!(loan_amount: 400000, interest_rate: 5.5, term_years: 20, lender: lender)

    # Mark one paid
    app1.broker_commission.mark_as_paid!

    unpaid = BrokerCommissionCalculator.total_unpaid_commissions(@broker)
    
    assert_equal 10000.0, unpaid  # Only app2 unpaid
  end

  test "multiple brokers have independent totals" do
    lender = create_test_lender
    
    rate1 = BrokerCommissionRate.create!(
      broker: @broker, lender: lender,
      commission_percentage: 2.5, payment_trigger: 'on_approval', active: true
    )
    
    rate2 = BrokerCommissionRate.create!(
      broker: brokers(:two), lender: lender,
      commission_percentage: 3.0, payment_trigger: 'on_approval', active: true
    )
    
    app1 = Application.create!(
      broker: @broker, lender: lender, user: @user,
      status: :created, property_value: 500000, loan_amount: 400000,
      applicant_name: 'B1', property_address: 'St', property_suburb: 'S', property_state: 'NSW', property_postcode: '2000'
    )
    
    app2 = Application.create!(
      broker: brokers(:two), lender: lender, user: @user,
      status: :created, property_value: 500000, loan_amount: 400000,
      applicant_name: 'B2', property_address: 'St', property_suburb: 'S', property_state: 'NSW', property_postcode: '2000'
    )

    app1.approve!(loan_amount: 400000, interest_rate: 5.5, term_years: 20, lender: lender)
    app2.approve!(loan_amount: 400000, interest_rate: 5.5, term_years: 20, lender: lender)

    total1 = BrokerCommissionCalculator.total_earned_commissions(@broker)
    total2 = BrokerCommissionCalculator.total_earned_commissions(brokers(:two))
    
    assert_equal 10000.0, total1  # 2.5% of 400k
    assert_equal 12000.0, total2  # 3.0% of 400k
  end
end
