require "test_helper"

class BrokerCommissionTest < ActiveSupport::TestCase
  fixtures :brokers, :applications, :lenders, :users

  setup do
    @broker = brokers(:one)
    @application = applications(:mortgage_application)
  end

  # Validations
  test "valid commission with required fields" do
    commission = BrokerCommission.new(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "earned",
      earned_date: Time.current
    )
    assert commission.valid?
  end

  test "commission requires commission_amount" do
    commission = BrokerCommission.new(
      broker: @broker,
      application: @application,
      commission_amount: nil,
      commission_rate: 1.5,
      status: "earned",
      earned_date: Time.current
    )
    assert_not commission.valid?
    assert commission.errors[:commission_amount].present?
  end

  test "commission_amount must be positive" do
    commission = BrokerCommission.new(
      broker: @broker,
      application: @application,
      commission_amount: -100,
      commission_rate: 1.5,
      status: "earned",
      earned_date: Time.current
    )
    assert_not commission.valid?
  end

  test "commission_amount cannot be zero" do
    commission = BrokerCommission.new(
      broker: @broker,
      application: @application,
      commission_amount: 0,
      commission_rate: 1.5,
      status: "earned",
      earned_date: Time.current
    )
    assert_not commission.valid?
  end

  test "commission requires commission_rate" do
    commission = BrokerCommission.new(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: nil,
      status: "earned",
      earned_date: Time.current
    )
    assert_not commission.valid?
    assert commission.errors[:commission_rate].present?
  end

  test "commission_rate must be between 0 and 100" do
    commission = BrokerCommission.new(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 150,
      status: "earned",
      earned_date: Time.current
    )
    assert_not commission.valid?
  end

  test "commission requires status" do
    commission = BrokerCommission.new(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: nil,
      earned_date: Time.current
    )
    assert_not commission.valid?
    assert commission.errors[:status].present?
  end

  test "status must be valid enum" do
    commission = BrokerCommission.new(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "invalid_status",
      earned_date: Time.current
    )
    assert_not commission.valid?
  end

  test "one application can only have one commission per broker" do
    BrokerCommission.create!(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "earned",
      earned_date: Time.current
    )

    duplicate = BrokerCommission.new(
      broker: @broker,
      application: @application,
      commission_amount: 3000,
      commission_rate: 1.0,
      status: "pending",
      earned_date: Time.current
    )
    assert_not duplicate.valid?
  end

  # Scopes
  test "earned scope returns only earned commissions" do
    earned = BrokerCommission.create!(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "earned",
      earned_date: Time.current
    )

    app2 = applications(:submitted_application)
    pending = BrokerCommission.create!(
      broker: @broker,
      application: app2,
      commission_amount: 3000,
      commission_rate: 1.0,
      status: "pending",
      earned_date: Time.current
    )

    assert_includes BrokerCommission.earned, earned
    assert_not_includes BrokerCommission.earned, pending
  end

  test "unpaid scope excludes commissions with paid_date" do
    unpaid = BrokerCommission.create!(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "earned",
      earned_date: Time.current
    )

    app2 = applications(:submitted_application)
    paid = BrokerCommission.create!(
      broker: @broker,
      application: app2,
      commission_amount: 3000,
      commission_rate: 1.0,
      status: "earned",
      earned_date: Time.current,
      paid_date: Time.current
    )

    unpaid_commissions = BrokerCommission.unpaid
    assert_includes unpaid_commissions, unpaid
    assert_not_includes unpaid_commissions, paid
  end

  test "for_broker scope returns only broker's commissions" do
    broker2 = brokers(:two)
    commission1 = BrokerCommission.create!(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "earned",
      earned_date: Time.current
    )

    app2 = applications(:submitted_application)
    commission2 = BrokerCommission.create!(
      broker: broker2,
      application: app2,
      commission_amount: 3000,
      commission_rate: 1.0,
      status: "earned",
      earned_date: Time.current
    )

    assert_includes BrokerCommission.for_broker(@broker), commission1
    assert_not_includes BrokerCommission.for_broker(@broker), commission2
  end

  test "for_period scope filters by earned_date range" do
    start_date = 30.days.ago
    end_date = Time.current

    old = BrokerCommission.create!(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "earned",
      earned_date: 60.days.ago
    )

    recent = BrokerCommission.create!(
      broker: @broker,
      application: applications(:submitted_application),
      commission_amount: 3000,
      commission_rate: 1.0,
      status: "earned",
      earned_date: 10.days.ago
    )

    period_commissions = BrokerCommission.for_period(start_date, end_date)
    assert_not_includes period_commissions, old
    assert_includes period_commissions, recent
  end

  # State transitions
  test "mark_as_paid! updates status and sets paid_date" do
    commission = BrokerCommission.create!(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "earned",
      earned_date: Time.current
    )

    commission.mark_as_paid!

    assert_equal "paid", commission.status
    assert commission.paid_date.present?
  end

  test "mark_as_earned! updates status to earned" do
    commission = BrokerCommission.create!(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "pending",
      earned_date: Time.current
    )

    commission.mark_as_earned!

    assert_equal "earned", commission.status
  end

  # Predicates
  test "unpaid? returns true for earned status without paid_date" do
    commission = BrokerCommission.create!(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "earned",
      earned_date: Time.current
    )

    assert commission.unpaid?
  end

  test "unpaid? returns false for paid status" do
    commission = BrokerCommission.create!(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "paid",
      earned_date: Time.current,
      paid_date: Time.current
    )

    assert_not commission.unpaid?
  end

  test "paid? returns true only for paid status" do
    commission = BrokerCommission.create!(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "paid",
      earned_date: Time.current,
      paid_date: Time.current
    )

    assert commission.paid?
  end

  # Associations
  test "commission belongs to broker" do
    commission = BrokerCommission.create!(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "earned",
      earned_date: Time.current
    )

    assert_equal @broker, commission.broker
  end

  test "commission belongs to application" do
    commission = BrokerCommission.create!(
      broker: @broker,
      application: @application,
      commission_amount: 5000,
      commission_rate: 1.5,
      status: "earned",
      earned_date: Time.current
    )

    assert_equal @application, commission.application
  end
end
