require "test_helper"

class BrokerCommissionRateTest < ActiveSupport::TestCase
  fixtures :brokers, :lenders

  setup do
    # Use fixture broker, but with a fresh lender to avoid fixture conflicts
    @broker = brokers(:one)
    @lender = Lender.create!(
      name: "Test Lender #{SecureRandom.hex(4)}",
      lender_type: "lender",
      address: "123 Test St",
      postcode: "2000",
      country: "AU",
      contact_email: "test#{SecureRandom.hex(4)}@test.com"
    )
  end

  # Validations
  test "valid rate with required fields" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )
    assert rate.valid?
  end

  test "rate requires broker" do
    rate = BrokerCommissionRate.new(
      broker: nil,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )
    assert_not rate.valid?
    assert rate.errors[:broker].present?
  end

  test "rate requires lender" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: nil,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )
    assert_not rate.valid?
    assert rate.errors[:lender].present?
  end

  test "rate requires commission_percentage" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: nil,
      payment_trigger: "on_approval",
      active: true
    )
    assert_not rate.valid?
    assert rate.errors[:commission_percentage].present?
  end

  test "commission_percentage must be positive" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: -1.5,
      payment_trigger: "on_approval",
      active: true
    )
    assert_not rate.valid?
  end

  test "commission_percentage must be greater than 0" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 0,
      payment_trigger: "on_approval",
      active: true
    )
    assert_not rate.valid?
  end

  test "commission_percentage cannot exceed 100" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 150,
      payment_trigger: "on_approval",
      active: true
    )
    assert_not rate.valid?
  end

  test "rate requires payment_trigger" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: nil,
      active: true
    )
    assert_not rate.valid?
    assert rate.errors[:payment_trigger].present?
  end

  test "payment_trigger must be valid enum" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "invalid_trigger",
      active: true
    )
    assert_not rate.valid?
  end

  test "broker-lender combination must be unique" do
    BrokerCommissionRate.create!(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )

    duplicate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 3.0,
      payment_trigger: "on_funding",
      active: true
    )
    assert_not duplicate.valid?
  end

  # Scopes
  test "active scope returns only active rates" do
    active_rate = BrokerCommissionRate.create!(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )

    lender2 = Lender.create!(
      name: "Test Lender Active Scope",
      lender_type: "lender",
      address: "456 Test St",
      postcode: "2000",
      country: "AU",
      contact_email: "active-scope@test.com"
    )

    inactive_rate = BrokerCommissionRate.create!(
      broker: @broker,
      lender: lender2,
      commission_percentage: 3.0,
      payment_trigger: "on_approval",
      active: false
    )

    assert_includes BrokerCommissionRate.active, active_rate
    assert_not_includes BrokerCommissionRate.active, inactive_rate
  end

  test "for_broker scope filters by broker" do
    rate1 = BrokerCommissionRate.create!(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )

    # Create a fresh broker and lender to avoid fixtures
    broker2 = Broker.create!(
      email: "broker2#{SecureRandom.hex(4)}@test.com",
      password: "test_password_123",
      password_confirmation: "test_password_123"
    )
    lender2 = Lender.create!(
      name: "Test Lender For Broker #{SecureRandom.hex(4)}",
      lender_type: "lender",
      address: "123 Test St",
      postcode: "2000",
      country: "AU",
      contact_email: "broker2lender#{SecureRandom.hex(4)}@test.com"
    )
    rate2 = BrokerCommissionRate.create!(
      broker: broker2,
      lender: lender2,
      commission_percentage: 3.0,
      payment_trigger: "on_approval",
      active: true
    )

    assert_includes BrokerCommissionRate.for_broker(@broker), rate1
    assert_not_includes BrokerCommissionRate.for_broker(@broker), rate2
  end

  test "for_lender scope filters by lender" do
    rate1 = BrokerCommissionRate.create!(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )

    # Create another lender
    lender2 = Lender.create!(
      name: "Test Lender 2",
      lender_type: "lender",
      address: "456 Test St",
      postcode: "2000",
      country: "AU",
      contact_email: "lender2@test.com"
    )

    rate2 = BrokerCommissionRate.create!(
      broker: @broker,
      lender: lender2,
      commission_percentage: 3.0,
      payment_trigger: "on_approval",
      active: true
    )

    assert_includes BrokerCommissionRate.for_lender(@lender), rate1
    assert_not_includes BrokerCommissionRate.for_lender(@lender), rate2
  end

  # Calculation methods
  test "calculate_commission returns correct amount from percentage" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )

    # 2.5% of $400,000 = $10,000
    commission = rate.calculate_commission(400_000)
    assert_equal 10_000, commission
  end

  test "calculate_commission with zero percentage returns zero" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 0,
      payment_trigger: "on_approval",
      active: true
    )

    commission = rate.calculate_commission(400_000)
    assert_equal 0, commission
  end

  test "calculate_commission with small loan amounts" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 1.0,
      payment_trigger: "on_approval",
      active: true
    )

    # 1% of $10,000 = $100
    commission = rate.calculate_commission(10_000)
    assert_equal 100, commission
  end

  test "calculate_commission with decimal loan amounts" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )

    # 2.5% of $250,500.50 = $6,262.51
    commission = rate.calculate_commission(250_500.50)
    assert_in_delta 6_262.51, commission, 0.01
  end

  test "calculate_commission with high percentage rate" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 10.0,
      payment_trigger: "on_approval",
      active: true
    )

    # 10% of $100,000 = $10,000
    commission = rate.calculate_commission(100_000)
    assert_equal 10_000, commission
  end

  # Associations
  test "rate belongs to broker" do
    rate = BrokerCommissionRate.create!(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )

    assert_equal @broker, rate.broker
  end

  test "rate belongs to lender" do
    rate = BrokerCommissionRate.create!(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )

    assert_equal @lender, rate.lender
  end

  # Edge cases
  test "fractional percentage rates work correctly" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 0.5,
      payment_trigger: "on_approval",
      active: true
    )

    # 0.5% of $100,000 = $500
    commission = rate.calculate_commission(100_000)
    assert_equal 500, commission
  end

  test "very large loan amounts" do
    rate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 1.5,
      payment_trigger: "on_approval",
      active: true
    )

    # 1.5% of $10,000,000 = $150,000
    commission = rate.calculate_commission(10_000_000)
    assert_equal 150_000, commission
  end

  test "broker can have one rate per lender (uniqueness constraint)" do
    # First rate should succeed
    rate1 = BrokerCommissionRate.create!(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )

    # Second rate with same broker and lender should fail
    rate2_duplicate = BrokerCommissionRate.new(
      broker: @broker,
      lender: @lender,
      commission_percentage: 3.0,
      payment_trigger: "on_approval",
      active: true
    )

    assert_not rate2_duplicate.valid?
  end

  test "broker can have different rates for different lenders" do
    # Clean up any fixture rates for @broker
    BrokerCommissionRate.for_broker(@broker).delete_all

    lender2 = Lender.create!(
      name: "Test Lender Multiple Rates",
      lender_type: "lender",
      address: "456 Test St",
      postcode: "2000",
      country: "AU",
      contact_email: "multi-rates@test.com"
    )

    rate1 = BrokerCommissionRate.create!(
      broker: @broker,
      lender: @lender,
      commission_percentage: 2.5,
      payment_trigger: "on_approval",
      active: true
    )

    rate2 = BrokerCommissionRate.create!(
      broker: @broker,
      lender: lender2,
      commission_percentage: 3.0,
      payment_trigger: "on_approval",
      active: true
    )

    broker_rates = BrokerCommissionRate.for_broker(@broker)
    assert_equal 2, broker_rates.count
    assert_includes broker_rates, rate1
    assert_includes broker_rates, rate2
  end
end
