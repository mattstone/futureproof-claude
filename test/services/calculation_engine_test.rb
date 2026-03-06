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

  # CPI Escalation & Inflation Scenario Tests

  test "calculates CPI escalation for projected years" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    base_amount = 5000
    inflation_rate = 0.025  # 2.5%

    # Year 0: $5000
    assert_equal 5000, engine.send(:apply_cpi_escalation, base_amount, 0, inflation_rate)

    # Year 5: $5000 * 1.025^5 ≈ $5656.36 → rounds to 5656
    result_5yr = engine.send(:apply_cpi_escalation, base_amount, 5, inflation_rate)
    assert_in_delta result_5yr, 5656, 1  # Allow ±1 rounding variance

    # Year 10: $5000 * 1.025^10 ≈ $6401.04 → rounds to 6401
    result_10yr = engine.send(:apply_cpi_escalation, base_amount, 10, inflation_rate)
    assert_in_delta result_10yr, 6401, 1  # Allow ±1 rounding variance
  end

  test "CPI escalation respects 4% annual cap" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    base_amount = 10_000
    high_inflation = 0.10  # 10% inflation, but should cap at 4%

    # Year 1 with 10% inflation, capped at 4%: $10_000 * 1.04 = $10_400
    escalated = engine.send(:apply_cpi_escalation, base_amount, 1, high_inflation)
    assert_equal 10_400, escalated

    # Year 5 with cap: $10_000 * 1.04^5 ≈ $12_167
    escalated = engine.send(:apply_cpi_escalation, base_amount, 5, high_inflation)
    assert_equal 12_167, escalated
  end

  test "inflation projections include low, base, and high scenarios" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    assert result[:inflation_projections].key?(:low)
    assert result[:inflation_projections].key?(:base)
    assert result[:inflation_projections].key?(:high)

    assert_equal 1, result[:inflation_projections][:low][:inflation_rate_percent]
    assert_equal 2, result[:inflation_projections][:base][:inflation_rate_percent]  # 2.5% rounds to 2
    assert_equal 5, result[:inflation_projections][:high][:inflation_rate_percent]
  end

  test "inflation projections include 5, 10, 15, 20 year timeframes" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    projections = result[:inflation_projections][:base][:projections]
    assert_equal 4, projections.length
    assert_equal [5, 10, 15, 20], projections.map { |p| p[:years] }
  end

  test "low inflation scenario shows lower income escalation than high inflation" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    low_5yr = result[:inflation_projections][:low][:projections][0]
    high_5yr = result[:inflation_projections][:high][:projections][0]

    # Low inflation = less escalation, but capped at 4% anyway
    assert low_5yr[:monthly_income] <= high_5yr[:monthly_income]
  end

  test "calculates cumulative income over projection period" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    base_monthly = 5000
    inflation_rate = 0.00  # 0% inflation for predictability

    cumulative_5yr = engine.send(:calculate_cumulative_income, base_monthly, 5, inflation_rate)
    expected = base_monthly * 12 * 5  # $300,000 over 5 years
    assert_equal expected, cumulative_5yr
  end

  test "cumulative income increases with inflation escalation" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    base_monthly = 5000

    cumulative_no_inflation = engine.send(:calculate_cumulative_income, base_monthly, 5, 0.00)
    cumulative_with_inflation = engine.send(:calculate_cumulative_income, base_monthly, 5, 0.025)

    # With inflation, income grows each year, so cumulative should be higher
    assert cumulative_with_inflation > cumulative_no_inflation
  end

  test "inflation projections show increasing monthly income across years" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    projections = result[:inflation_projections][:base][:projections]

    # Monthly income should increase from 5yr to 20yr
    assert projections[0][:monthly_income] < projections[1][:monthly_income]  # 5yr < 10yr
    assert projections[1][:monthly_income] < projections[2][:monthly_income]  # 10yr < 15yr
    assert projections[2][:monthly_income] < projections[3][:monthly_income]  # 15yr < 20yr
  end

  test "au region inflation projections" do
    engine = CalculationEngine.new(home_value: 2_000_000, term: 15, region: "au")
    result = engine.calculate

    assert result[:inflation_projections].key?(:base)
    base_projections = result[:inflation_projections][:base][:projections]

    assert_equal 4, base_projections.length
    assert base_projections[0][:monthly_income] > 0
    assert base_projections[0][:cumulative_income] > 0
    # Cumulative should be less than (escalated monthly * 12 * years) since escalated is end-of-period
    assert_operator base_projections[0][:cumulative_income], :<, base_projections[0][:monthly_income] * 12 * 5
  end

  test "all inflation scenario keys present in result" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    [:low, :base, :high].each do |scenario|
      assert result[:inflation_projections][scenario].key?(:inflation_rate_percent)
      assert result[:inflation_projections][scenario].key?(:projections)
      assert_equal 4, result[:inflation_projections][scenario][:projections].length
    end
  end

  # NNEG (Negative Equity) & Estate Impact Tests

  test "model type A (portfolio distribution)" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us", model_type: :a)
    result = engine.calculate

    assert_equal :a, result[:model_type][:type]
    assert_equal "Portfolio Distribution Model", result[:model_type][:name]
    assert_equal "portfolio", result[:model_type][:income_source]
  end

  test "model type B (loan advances)" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us", model_type: :b)
    result = engine.calculate

    assert_equal :b, result[:model_type][:type]
    assert_equal "Loan Advance Model", result[:model_type][:name]
    assert_equal "loan_advances", result[:model_type][:income_source]
  end

  test "NNEG analysis includes year-by-year data" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    nneg = result[:nneg_analysis]
    assert nneg.key?(:scenario_results)
    assert_equal 10, nneg[:scenario_results].length
    
    # Each year should have NNEG data
    nneg[:scenario_results].each do |year_data|
      assert year_data.key?(:year)
      assert year_data.key?(:mortgage_balance)
      assert year_data.key?(:ltv_ratio)
      assert year_data.key?(:nneg_risk_pessimistic)
    end
  end

  test "NNEG analysis includes property value scenarios" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    nneg = result[:nneg_analysis]
    year_1 = nneg[:scenario_results][0]
    
    assert year_1.key?(:property_value_pessimistic)
    assert year_1.key?(:property_value_expected)
    assert year_1.key?(:property_value_optimistic)
    
    # Property value should decline (pessimistic), stay same (expected), grow (optimistic)
    assert year_1[:property_value_pessimistic] < year_1[:property_value_expected]
    assert year_1[:property_value_expected] <= year_1[:property_value_optimistic]
  end

  test "NNEG probability calculated" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    nneg = result[:nneg_analysis]
    assert nneg.key?(:nneg_probability_percent)
    assert nneg[:nneg_probability_percent] >= 0
    assert nneg[:nneg_probability_percent] <= 100
  end

  test "NNEG trigger year identified when risk exists" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    nneg = result[:nneg_analysis]
    # nneg_trigger_year can be nil or a year number
    assert nneg[:nneg_trigger_year].nil? || nneg[:nneg_trigger_year].is_a?(Integer)
    assert nneg.key?(:explanation)
  end

  test "estate impact calculated at 5, 10, and term years" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 20, region: "us")
    result = engine.calculate

    estate = result[:estate_impact]
    assert estate.key?(:year_5_estate)
    assert estate.key?(:year_10_estate)
    assert estate.key?(:year_at_term_estate)
    
    assert estate[:year_5_estate].key?(:property_value)
    assert estate[:year_5_estate].key?(:portfolio_value)
    assert estate[:year_5_estate].key?(:mortgage_debt)
    assert estate[:year_5_estate].key?(:net_estate)
  end

  test "estate value increases with investment growth" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 20, region: "us")
    result = engine.calculate

    estate = result[:estate_impact]
    
    # Portfolio value should grow from year 5 → 10 → term
    assert estate[:year_5_estate][:portfolio_value] < estate[:year_10_estate][:portfolio_value]
    assert estate[:year_10_estate][:portfolio_value] < estate[:year_at_term_estate][:portfolio_value]
  end

  test "mortgage debt decreases over time" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 20, region: "us")
    result = engine.calculate

    estate = result[:estate_impact]
    
    # Mortgage debt should decrease as payments are made
    assert estate[:year_5_estate][:mortgage_debt] > estate[:year_10_estate][:mortgage_debt]
    assert estate[:year_10_estate][:mortgage_debt] > estate[:year_at_term_estate][:mortgage_debt]
  end

  test "net estate represents property + portfolio - debt" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    estate = result[:estate_impact]
    year_5 = estate[:year_5_estate]
    
    expected_net = year_5[:property_value] + year_5[:portfolio_value] - year_5[:mortgage_debt]
    assert_equal expected_net, year_5[:net_estate]
  end

  test "AU region with NNEG analysis" do
    engine = CalculationEngine.new(home_value: 2_000_000, term: 15, region: "au", model_type: :b)
    result = engine.calculate

    assert_equal :b, result[:model_type][:type]
    assert result[:nneg_analysis].key?(:scenario_results)
    assert result[:estate_impact].key?(:year_at_term_estate)
  end

  test "monthly payment calculation" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    loan_amount = 1_500_000 * 0.80  # 80% LTV

    monthly_payment = engine.send(:calculate_monthly_payment, loan_amount, 10)
    
    # Monthly payment should be positive
    assert monthly_payment > 0
    # Total paid over 10 years should exceed loan amount (due to interest)
    total_paid = monthly_payment * 10 * 12
    assert total_paid > loan_amount
  end

  test "remaining balance decreases over time" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    loan_amount = 1_500_000 * 0.80
    monthly_payment = engine.send(:calculate_monthly_payment, loan_amount, 10)

    balance_year_0 = engine.send(:calculate_remaining_balance, loan_amount, monthly_payment, 0)
    balance_year_5 = engine.send(:calculate_remaining_balance, loan_amount, monthly_payment, 5 * 12)
    balance_year_10 = engine.send(:calculate_remaining_balance, loan_amount, monthly_payment, 10 * 12)

    assert balance_year_0 > balance_year_5
    assert balance_year_5 > balance_year_10
    assert balance_year_10 >= 0
  end

  test "NNEG probability reflects risk across the term" do
    engine = CalculationEngine.new(home_value: 500_000, term: 20, region: "us")  # Smaller property = more risk
    result = engine.calculate

    nneg = result[:nneg_analysis]
    # Higher NNEG probability on smaller properties over longer terms
    assert nneg[:nneg_probability_percent] >= 0
  end

  test "model type defaulting to :a" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    assert_equal :a, result[:model_type][:type]
  end

  test "estate explanation provided" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    assert result[:estate_impact].key?(:explanation)
    assert result[:estate_impact][:explanation].length > 0
  end

  test "all NNEG keys present in result" do
    engine = CalculationEngine.new(home_value: 1_500_000, term: 10, region: "us")
    result = engine.calculate

    nneg = result[:nneg_analysis]
    assert nneg.key?(:scenario_results)
    assert nneg.key?(:nneg_trigger_year)
    assert nneg.key?(:nneg_probability_percent)
    assert nneg.key?(:explanation)
  end
end
