require "test_helper"

class CalculationEngineTest < ActiveSupport::TestCase
  test "calculates quote for US region" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    assert_equal "US", result[:region][:code]
    assert_equal "USD", result[:region][:currency]
    assert result[:quote][:monthly_income] > 0
    assert_equal 100, result[:equity_preservation][:equity_preserved_percentage]
    assert result[:scenarios][:pessimistic][:monthly_income] < result[:scenarios][:expected][:monthly_income]
    assert result[:scenarios][:expected][:monthly_income] < result[:scenarios][:optimistic][:monthly_income]
  end

  test "calculates quote for AU region" do
    engine = CalculationEngine.new(home_value: 2_000_000, term: 15, region: "au")
    result = engine.calculate

    assert_equal "AU", result[:region][:code]
    assert_equal "AUD", result[:region][:currency]
    assert_equal "A$", result[:region][:currency_symbol]
    assert_includes result[:compliance][:data_protection], "Privacy Act 1988"
    assert_includes result[:compliance][:consumer_protection], "National Consumer Credit"
  end

  test "calculates quote for UK region" do
    engine = CalculationEngine.new(home_value: 500_000, term: 20, region: "uk")
    result = engine.calculate

    assert_equal "UK", result[:region][:code]
    assert_equal "GBP", result[:region][:currency]
    assert_equal "£", result[:region][:currency_symbol]
    assert_includes result[:compliance][:data_protection], "UK GDPR"
    assert_includes result[:compliance][:consumer_protection], "FCA Consumer Duty"
  end

  test "calculates quote for NZ region" do
    engine = CalculationEngine.new(home_value: 800_000, term: 25, region: "nz")
    result = engine.calculate

    assert_equal "NZ", result[:region][:code]
    assert_equal "NZD", result[:region][:currency]
    assert_includes result[:compliance][:data_protection], "Privacy Act 2020"
  end

  test "rejects home value below region minimum" do
    assert_raises(ArgumentError) do
      CalculationEngine.new(home_value: 100_000, term: 10, region: "us")
    end
  end

  test "rejects home value above region maximum" do
    assert_raises(ArgumentError) do
      CalculationEngine.new(home_value: 50_000_000, term: 10, region: "us")
    end
  end

  test "rejects invalid term" do
    assert_raises(ArgumentError) do
      CalculationEngine.new(home_value: 1_000_000, term: 7, region: "us")
    end
  end

  test "defaults to US region" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10)
    result = engine.calculate
    assert_equal "US", result[:region][:code]
  end

  test "insurance details are calculated" do
    engine = CalculationEngine.new(home_value: 2_000_000, term: 10, region: "au")
    result = engine.calculate

    assert result[:insurance][:covered]
    assert_equal 32_000, result[:insurance][:lmi_amount] # 2M * 0.80 * 0.02
  end

  test "summary includes key facts" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    assert result[:summary][:headline].include?("/month")
    assert result[:summary][:key_facts].length >= 5
  end

  test "for_region returns region configuration" do
    info = CalculationEngine.for_region("au")
    assert_equal "au", info[:region]
    assert_equal "Australia", info[:name]
    assert_equal "AUD", info[:currency]
    assert_equal 500_000, info[:min_home_value]
  end

  test "supports both tom and pavel models" do
    tom = CalculationEngine.new(home_value: 1_500_000, term: 10, model: :tom).calculate
    pavel = CalculationEngine.new(home_value: 1_500_000, term: 10, model: :pavel).calculate

    assert_equal :tom, tom[:quote][:model]
    assert_equal :pavel, pavel[:quote][:model]
    # Tom's model is more aggressive (higher income)
    assert tom[:quote][:monthly_income] > pavel[:quote][:monthly_income]
  end
end
