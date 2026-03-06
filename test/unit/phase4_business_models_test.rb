require "test_helper"

class Phase4BusinessModelsTest < ActiveSupport::TestCase
  # === LENDER MODEL TESTS ===

  test "lender creation with valid attributes" do
    lender = Lender.create!(
      name: "FutureProof Financial AU",
      region: "AU",
      abn: "12345678901",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    assert lender.persisted?
    assert_equal "FutureProof Financial AU", lender.name
    assert_equal "AU", lender.region
    assert_equal "active", lender.status
  end

  test "lender has_many applications" do
    lender = Lender.create!(
      name: "Test Lender",
      region: "AU",
      abn: "12345678901",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    user = User.create!(
      email: "customer@example.com",
      password: "SecurePassword123!",
      role: "customer"
    )

    app1 = Application.create!(
      user: user,
      lender: lender,
      property_value: 800_000,
      customer_age: 72,
      government_id: "1",
      bank_account_number: "1"
    )

    app2 = Application.create!(
      user: user,
      lender: lender,
      property_value: 1_000_000,
      customer_age: 72,
      government_id: "2",
      bank_account_number: "2"
    )

    assert_equal 2, lender.applications.count
  end

  test "lender validates region" do
    lender = Lender.new(
      name: "Test Lender",
      region: "INVALID",
      abn: "12345678901",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    # Assuming region validation exists
    # This test checks if region is in allowed values
    assert_not lender.valid?
  end

  test "lender max_loan_amount must be positive" do
    lender = Lender.new(
      name: "Test Lender",
      region: "AU",
      abn: "12345678901",
      status: "active",
      max_loan_amount: -100_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    assert_not lender.valid?
  end

  # === WHOLESALE FUNDER MODEL TESTS ===

  test "wholesale funder creation with valid attributes" do
    funder = WholesaleFunder.create!(
      name: "FutureProof Capital Fund",
      region: "AU",
      aum: 50_000_000,
      status: "active"
    )

    assert funder.persisted?
    assert_equal "FutureProof Capital Fund", funder.name
    assert_equal 50_000_000, funder.aum
    assert_equal "active", funder.status
  end

  test "wholesale funder has_many funder_pools" do
    funder = WholesaleFunder.create!(
      name: "Test Funder",
      region: "AU",
      aum: 50_000_000,
      status: "active"
    )

    pool1 = FunderPool.create!(
      wholesale_funder: funder,
      name: "Pool 1",
      available_capital: 10_000_000,
      status: "active",
      region: "AU"
    )

    pool2 = FunderPool.create!(
      wholesale_funder: funder,
      name: "Pool 2",
      available_capital: 15_000_000,
      status: "active",
      region: "AU"
    )

    assert_equal 2, funder.funder_pools.count
  end

  test "wholesale funder aum must be positive" do
    funder = WholesaleFunder.new(
      name: "Test Funder",
      region: "AU",
      aum: -10_000_000,
      status: "active"
    )

    assert_not funder.valid?
  end

  # === FUNDER POOL MODEL TESTS ===

  test "funder pool creation with valid attributes" do
    funder = WholesaleFunder.create!(
      name: "Test Funder",
      region: "AU",
      aum: 50_000_000,
      status: "active"
    )

    pool = FunderPool.create!(
      wholesale_funder: funder,
      name: "AU Primary Pool",
      available_capital: 10_000_000,
      status: "active",
      region: "AU"
    )

    assert pool.persisted?
    assert_equal "AU Primary Pool", pool.name
    assert_equal 10_000_000, pool.available_capital
  end

  test "funder pool tracks capital depletion" do
    funder = WholesaleFunder.create!(
      name: "Test Funder",
      region: "AU",
      aum: 50_000_000,
      status: "active"
    )

    pool = FunderPool.create!(
      wholesale_funder: funder,
      name: "Test Pool",
      available_capital: 1_000_000,
      status: "active",
      region: "AU"
    )

    # Simulate capital allocation
    pool.update!(available_capital: 800_000)
    assert_equal 800_000, pool.available_capital

    pool.update!(available_capital: 500_000)
    assert_equal 500_000, pool.available_capital
  end

  # === REFERRAL PARTNER MODEL TESTS ===

  test "referral partner creation with valid attributes" do
    lender = Lender.create!(
      name: "Test Lender",
      region: "AU",
      abn: "12345678901",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    partner = ReferralPartner.create!(
      lender: lender,
      name: "Helen Chen Mortgages",
      region: "AU",
      licence_number: "REF123456",
      commission_rate: 0.015,
      email: "helen@mortgages.com"
    )

    assert partner.persisted?
    assert_equal "Helen Chen Mortgages", partner.name
    assert_equal 0.015, partner.commission_rate
  end

  test "referral partner licence_number must be unique per region" do
    lender1 = Lender.create!(
      name: "Lender 1",
      region: "AU",
      abn: "12345678901",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    lender2 = Lender.create!(
      name: "Lender 2",
      region: "US",
      abn: "98-7654321",
      status: "active",
      max_loan_amount: 3_000_000,
      min_customer_age: 62,
      max_customer_age: 95
    )

    ReferralPartner.create!(
      lender: lender1,
      name: "Partner 1",
      region: "AU",
      licence_number: "REF123456",
      commission_rate: 0.015,
      email: "partner1@example.com"
    )

    # Same licence in same region should fail
    partner2 = ReferralPartner.new(
      lender: lender1,
      name: "Partner 2",
      region: "AU",
      licence_number: "REF123456",
      commission_rate: 0.015,
      email: "partner2@example.com"
    )

    assert_not partner2.valid?
  end

  test "referral partner commission_rate is in valid range" do
    lender = Lender.create!(
      name: "Test Lender",
      region: "AU",
      abn: "12345678901",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    partner = ReferralPartner.new(
      lender: lender,
      name: "Test Partner",
      region: "AU",
      licence_number: "REF123456",
      commission_rate: 0.05,  # Valid: 0.5%
      email: "test@example.com"
    )

    assert partner.valid?

    partner.commission_rate = 2.0  # Invalid: > 100%
    assert_not partner.valid?
  end

  # === INVESTMENT PARTNER MODEL TESTS ===

  test "investment partner creation with valid attributes" do
    funder = WholesaleFunder.create!(
      name: "Test Funder",
      region: "AU",
      aum: 50_000_000,
      status: "active"
    )

    partner = InvestmentPartner.create!(
      wholesale_funder: funder,
      name: "Pacific Growth Investments",
      region: "AU",
      aum: 100_000_000,
      portfolio_strategy: "growth",
      fee_rate: 0.01,
      licence_number: "INV123456"
    )

    assert partner.persisted?
    assert_equal "Pacific Growth Investments", partner.name
    assert_equal "growth", partner.portfolio_strategy
  end

  test "investment partner licence_number must be globally unique" do
    funder1 = WholesaleFunder.create!(
      name: "Funder 1",
      region: "AU",
      aum: 50_000_000,
      status: "active"
    )

    funder2 = WholesaleFunder.create!(
      name: "Funder 2",
      region: "US",
      aum: 100_000_000,
      status: "active"
    )

    InvestmentPartner.create!(
      wholesale_funder: funder1,
      name: "Partner 1",
      region: "AU",
      aum: 50_000_000,
      portfolio_strategy: "growth",
      fee_rate: 0.01,
      licence_number: "INV123456"
    )

    # Same licence in different region should still fail (globally unique)
    partner2 = InvestmentPartner.new(
      wholesale_funder: funder2,
      name: "Partner 2",
      region: "US",
      aum: 50_000_000,
      portfolio_strategy: "income",
      fee_rate: 0.015,
      licence_number: "INV123456"
    )

    assert_not partner2.valid?
  end

  test "investment partner fee_rate is in valid range" do
    funder = WholesaleFunder.create!(
      name: "Test Funder",
      region: "AU",
      aum: 50_000_000,
      status: "active"
    )

    partner = InvestmentPartner.new(
      wholesale_funder: funder,
      name: "Test Partner",
      region: "AU",
      aum: 100_000_000,
      portfolio_strategy: "growth",
      fee_rate: 0.02,  # Valid: 2%
      licence_number: "INV123456"
    )

    assert partner.valid?

    partner.fee_rate = 0.5  # Invalid: > 50%
    assert_not partner.valid?
  end

  # === RELATIONSHIP TESTS ===

  test "lender has_many referral_partners" do
    lender = Lender.create!(
      name: "Test Lender",
      region: "AU",
      abn: "12345678901",
      status: "active",
      max_loan_amount: 2_000_000,
      min_customer_age: 60,
      max_customer_age: 95
    )

    partner1 = ReferralPartner.create!(
      lender: lender,
      name: "Partner 1",
      region: "AU",
      licence_number: "REF1",
      commission_rate: 0.015,
      email: "p1@example.com"
    )

    partner2 = ReferralPartner.create!(
      lender: lender,
      name: "Partner 2",
      region: "AU",
      licence_number: "REF2",
      commission_rate: 0.015,
      email: "p2@example.com"
    )

    assert_equal 2, lender.referral_partners.count
  end

  test "wholesale_funder has_many investment_partners" do
    funder = WholesaleFunder.create!(
      name: "Test Funder",
      region: "AU",
      aum: 50_000_000,
      status: "active"
    )

    partner1 = InvestmentPartner.create!(
      wholesale_funder: funder,
      name: "Partner 1",
      region: "AU",
      aum: 50_000_000,
      portfolio_strategy: "growth",
      fee_rate: 0.01,
      licence_number: "INV1"
    )

    partner2 = InvestmentPartner.create!(
      wholesale_funder: funder,
      name: "Partner 2",
      region: "AU",
      aum: 75_000_000,
      portfolio_strategy: "income",
      fee_rate: 0.015,
      licence_number: "INV2"
    )

    assert_equal 2, funder.investment_partners.count
  end
end
