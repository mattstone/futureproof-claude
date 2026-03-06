require "test_helper"

class InvestmentPartnerTest < ActiveSupport::TestCase
  setup do
    @funder = wholesale_funders(:one)
    @partner = InvestmentPartner.new(
      name: "Test Capital",
      region: "au",
      licence_number: "IP-TEST-999",
      aum: 25000000.00,
      portfolio_strategy: "balanced_etf",
      fee_rate: 1.25,
      status: "active",
      wholesale_funder: @funder
    )
  end

  test "valid investment partner" do
    assert @partner.valid?, @partner.errors.full_messages.join(", ")
  end

  test "requires name" do
    @partner.name = nil
    assert_not @partner.valid?
  end

  test "requires region" do
    @partner.region = nil
    assert_not @partner.valid?
  end

  test "validates region inclusion" do
    @partner.region = "invalid"
    assert_not @partner.valid?
  end

  test "requires licence_number" do
    @partner.licence_number = nil
    assert_not @partner.valid?
  end

  test "licence_number globally unique" do
    @partner.save!
    duplicate = @partner.dup
    duplicate.region = "us"
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:licence_number], "has already been taken"
  end

  test "validates fee_rate range" do
    @partner.fee_rate = -1
    assert_not @partner.valid?

    @partner.fee_rate = 101
    assert_not @partner.valid?

    @partner.fee_rate = 2.0
    assert @partner.valid?
  end

  test "validates aum non-negative" do
    @partner.aum = -1
    assert_not @partner.valid?
  end

  test "belongs to wholesale_funder" do
    assert_respond_to @partner, :wholesale_funder
  end

  test "active scope" do
    active = investment_partners(:futureproof_capital_au)
    assert_includes InvestmentPartner.active, active
  end

  test "by_region scope" do
    au = investment_partners(:futureproof_capital_au)
    us = investment_partners(:futureproof_capital_us)
    assert_includes InvestmentPartner.by_region("au"), au
    assert_not_includes InvestmentPartner.by_region("au"), us
  end
end
