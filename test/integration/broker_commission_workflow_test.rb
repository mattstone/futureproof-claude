require 'test_helper'

# Integration tests for broker commission workflow
# Tests commission calculation, status transitions, filtering, and dashboard totals
class BrokerCommissionWorkflowTest < ActionDispatch::IntegrationTest
  fixtures :lenders, :users, :brokers, :applications

  setup do
    @lender = lenders(:futureproof)
    @broker = brokers(:one)
    @user = users(:regular_user)
    # Clean up commissions from previous test runs
    BrokerCommission.delete_all
    sign_in @broker
  end

  # Helper: Create test lender
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

  # Test 1: Commission calculation from rate
  test "commission amount calculated correctly from rate" do
    lender = create_test_lender
    rate = BrokerCommissionRate.create!(
      broker: @broker, lender: lender,
      commission_percentage: 2.5, payment_trigger: 'on_approval', active: true
    )

    commission_amount = rate.calculate_commission(400000)
    assert_equal 10000.0, commission_amount
  end

  test "commission rate applied to different loan amounts" do
    lender = create_test_lender
    rate = BrokerCommissionRate.create!(
      broker: @broker, lender: lender,
      commission_percentage: 3.0, payment_trigger: 'on_approval', active: true
    )

    assert_equal 15000.0, rate.calculate_commission(500000)
    assert_equal 30000.0, rate.calculate_commission(1000000)
  end

  # Test 2: Commission creation and status
  test "commission creation with earned status" do
    app = applications(:mortgage_application)

    commission = BrokerCommission.create!(
      broker: @broker,
      application: app,
      commission_amount: 10000.0,
      commission_rate: 2.5,
      status: 'earned',
      earned_date: Time.current
    )

    assert_equal 'earned', commission.status
    assert_not_nil commission.earned_date
  end

  test "commission status transition to paid" do
    app = applications(:second_application)
    
    commission = BrokerCommission.create!(
      broker: @broker,
      application: app,
      commission_amount: 10000.0,
      commission_rate: 2.5,
      status: 'earned',
      earned_date: Time.current
    )

    commission.mark_as_paid!
    commission.reload

    assert_equal 'paid', commission.status
    assert_not_nil commission.paid_date
  end

  test "pending commission status" do
    app = applications(:submitted_application)
    
    commission = BrokerCommission.create!(
      broker: @broker,
      application: app,
      commission_amount: 10000.0,
      commission_rate: 2.5,
      status: 'pending',
      earned_date: Time.current
    )

    assert_equal 'pending', commission.status
  end

  # Test 3: Commission querying and filtering
  test "retrieve commissions by broker" do
    app1 = applications(:mortgage_application)
    app2 = applications(:second_application)

    commission1 = BrokerCommission.create!(
      broker: @broker,
      application: app1,
      commission_amount: 10000.0,
      commission_rate: 2.5,
      status: 'earned',
      earned_date: Time.current
    )

    commission2 = BrokerCommission.create!(
      broker: brokers(:two),
      application: app2,
      commission_amount: 12000.0,
      commission_rate: 3.0,
      status: 'earned',
      earned_date: Time.current
    )

    broker_commissions = BrokerCommission.for_broker(@broker)
    assert_includes broker_commissions, commission1
    assert_not_includes broker_commissions, commission2
  end

  test "retrieve earned vs pending commissions" do
    app1 = applications(:mortgage_application)
    app2 = applications(:second_application)

    earned = BrokerCommission.create!(
      broker: @broker,
      application: app1,
      commission_amount: 10000.0,
      commission_rate: 2.5,
      status: 'earned',
      earned_date: Time.current
    )

    pending = BrokerCommission.create!(
      broker: @broker,
      application: app2,
      commission_amount: 5000.0,
      commission_rate: 2.5,
      status: 'pending',
      earned_date: Time.current
    )

    earned_scope = BrokerCommission.for_broker(@broker).earned
    pending_scope = BrokerCommission.for_broker(@broker).pending

    assert_includes earned_scope, earned
    assert_not_includes earned_scope, pending
    assert_includes pending_scope, pending
    assert_not_includes pending_scope, earned
  end

  # Test 4: Dashboard total calculations
  test "sum earned commissions by broker" do
    app1 = applications(:mortgage_application)
    app2 = applications(:second_application)

    BrokerCommission.create!(
      broker: @broker,
      application: app1,
      commission_amount: 10000.0,
      commission_rate: 2.5,
      status: 'earned',
      earned_date: Time.current
    )

    BrokerCommission.create!(
      broker: @broker,
      application: app2,
      commission_amount: 15000.0,
      commission_rate: 3.0,
      status: 'earned',
      earned_date: Time.current
    )

    total = BrokerCommission.for_broker(@broker).earned.sum(:commission_amount).to_f
    assert_equal 25000.0, total
  end

  test "unpaid vs paid commission tracking" do
    app1 = applications(:submitted_application)
    app2 = applications(:processing_application)

    earned = BrokerCommission.create!(
      broker: @broker,
      application: app1,
      commission_amount: 10000.0,
      commission_rate: 2.5,
      status: 'earned',
      earned_date: Time.current
    )

    paid = BrokerCommission.create!(
      broker: @broker,
      application: app2,
      commission_amount: 20000.0,
      commission_rate: 2.5,
      status: 'earned',
      earned_date: Time.current,
      paid_date: Time.current
    )

    unpaid = BrokerCommission.for_broker(@broker).unpaid.sum(:commission_amount).to_f
    assert_equal 10000.0, unpaid  # Only earned without paid_date
  end

  test "multiple brokers have independent totals" do
    app1 = applications(:mortgage_application)
    app2 = applications(:second_application)

    BrokerCommission.create!(
      broker: @broker,
      application: app1,
      commission_amount: 10000.0,
      commission_rate: 2.5,
      status: 'earned',
      earned_date: Time.current
    )

    BrokerCommission.create!(
      broker: brokers(:two),
      application: app2,
      commission_amount: 12000.0,
      commission_rate: 3.0,
      status: 'earned',
      earned_date: Time.current
    )

    broker1_total = BrokerCommission.for_broker(@broker).earned.sum(:commission_amount).to_f
    broker2_total = BrokerCommission.for_broker(brokers(:two)).earned.sum(:commission_amount).to_f

    assert_equal 10000.0, broker1_total
    assert_equal 12000.0, broker2_total
  end

  test "period filtering for commissions" do
    app1 = applications(:submitted_application)
    app2 = applications(:processing_application)

    recent = BrokerCommission.create!(
      broker: @broker,
      application: app1,
      commission_amount: 10000.0,
      commission_rate: 2.5,
      status: 'earned',
      earned_date: 5.days.ago
    )

    old = BrokerCommission.create!(
      broker: @broker,
      application: app2,
      commission_amount: 10000.0,
      commission_rate: 2.5,
      status: 'earned',
      earned_date: 2.months.ago
    )

    period_start = 1.month.ago.beginning_of_month
    period_end = Time.current.end_of_month

    commissions = BrokerCommissionCalculator.commissions_by_period(@broker, period_start, period_end)

    assert_includes commissions, recent
    assert_not_includes commissions, old
  end

  # Test 5: Commission rate active status
  test "only active commission rates are used" do
    lender = create_test_lender
    broker = brokers(:two)

    active_rate = BrokerCommissionRate.create!(
      broker: broker, lender: lender,
      commission_percentage: 2.5, payment_trigger: 'on_approval', active: true
    )

    rates = BrokerCommissionRate.active
    assert_includes rates, active_rate
  end
end
