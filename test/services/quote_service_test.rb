require "test_helper"

class QuoteServiceTest < ActiveSupport::TestCase
  # =============================================================================
  # GENERAL TESTS
  # =============================================================================

  test "available_models returns both models" do
    models = QuoteService.available_models
    assert_includes models, :tom
    assert_includes models, :pavel
  end

  test "raises error for invalid home_value" do
    assert_raises(ArgumentError) { QuoteService.quote(home_value: -100, term: 10) }
    assert_raises(ArgumentError) { QuoteService.quote(home_value: "invalid", term: 10) }
  end

  test "raises error for invalid term" do
    assert_raises(ArgumentError) { QuoteService.quote(home_value: 1_500_000, term: 12) }
    assert_raises(ArgumentError) { QuoteService.quote(home_value: 1_500_000, term: 0) }
  end

  test "raises error for invalid model" do
    assert_raises(ArgumentError) { QuoteService.quote(home_value: 1_500_000, term: 10, model: :invalid) }
  end

  test "default model is tom" do
    assert_equal :tom, QuoteService::DEFAULT_MODEL
  end

  # =============================================================================
  # TOM'S MODEL TESTS
  # =============================================================================

  test "tom model returns correct structure" do
    result = QuoteService.quote(home_value: 1_500_000, term: 10, model: :tom)

    assert_equal :tom, result[:model]
    assert_equal "Tom's Model", result[:model_name]
    assert_equal 1_500_000, result[:home_value]
    assert_equal 10, result[:term_years]
    assert_equal 0.80, result[:lvr]
    assert result[:monthly_income].positive?
    assert result[:annual_income].positive?
    assert result[:total_income].positive?
  end

  test "tom model matches React webapp lookup for base property" do
    # 10-year term on $1.5M should give $300,000 total
    result = QuoteService.quote(home_value: 1_500_000, term: 10, model: :tom)
    assert_equal 300_000, result[:total_income]
    assert_equal 30_000, result[:annual_income]
    assert_equal 2_500, result[:monthly_income]
  end

  test "tom model scales linearly with home value" do
    base = QuoteService.quote(home_value: 1_500_000, term: 10, model: :tom)
    double = QuoteService.quote(home_value: 3_000_000, term: 10, model: :tom)

    assert_equal base[:monthly_income] * 2, double[:monthly_income]
    assert_equal base[:total_income] * 2, double[:total_income]
  end

  test "tom model all terms produce valid results" do
    [10, 15, 20, 25, 30].each do |term|
      result = QuoteService.quote(home_value: 1_500_000, term: term, model: :tom)
      assert result[:monthly_income].positive?, "Term #{term} should have positive monthly income"
      assert result[:total_income].positive?, "Term #{term} should have positive total income"
    end
  end

  test "tom model info returns expected structure" do
    info = QuoteService.model_info(:tom)

    assert_equal "Tom's Model", info[:name]
    assert info[:description].present?
    assert info[:assumptions].present?
    assert info[:annuity_rates].present?
  end

  # =============================================================================
  # PAVEL'S MODEL TESTS
  # =============================================================================

  test "pavel model returns correct structure" do
    result = QuoteService.quote(home_value: 1_500_000, term: 10, model: :pavel)

    assert_equal :pavel, result[:model]
    assert_equal "Pavel's Model", result[:model_name]
    assert_equal 1_500_000, result[:home_value]
    assert_equal 10, result[:term_years]
    assert_equal 0.80, result[:lvr]
    assert result[:monthly_income].positive?
    assert result[:annual_income].positive?
    assert result[:total_income].positive?
  end

  test "pavel model uses 1.5% annuity rate for 10 year term" do
    result = QuoteService.quote(home_value: 1_500_000, term: 10, model: :pavel)

    # 1.5% of $1.5M = $22,500/year = $1,875/month
    assert_equal 0.015, result[:annuity_rate]
    assert_equal 22_500, result[:annual_income]
    assert_equal 1_875, result[:monthly_income]
    assert_equal 225_000, result[:total_income]
  end

  test "pavel model scales linearly with home value" do
    base = QuoteService.quote(home_value: 1_500_000, term: 10, model: :pavel)
    double = QuoteService.quote(home_value: 3_000_000, term: 10, model: :pavel)

    assert_equal base[:monthly_income] * 2, double[:monthly_income]
    assert_equal base[:total_income] * 2, double[:total_income]
  end

  test "pavel model all terms produce valid results" do
    [10, 15, 20, 25, 30].each do |term|
      result = QuoteService.quote(home_value: 1_500_000, term: term, model: :pavel)
      assert result[:monthly_income].positive?, "Term #{term} should have positive monthly income"
      assert result[:total_income].positive?, "Term #{term} should have positive total income"
    end
  end

  test "pavel model annuity rates decrease with longer terms" do
    rates = [10, 15, 20, 25, 30].map do |term|
      result = QuoteService.quote(home_value: 1_500_000, term: term, model: :pavel)
      result[:annuity_rate]
    end

    # Each rate should be less than or equal to the previous
    rates.each_cons(2) do |r1, r2|
      assert r1 >= r2, "Annuity rate should decrease with longer terms"
    end
  end

  test "pavel model info returns expected structure with model params" do
    info = QuoteService.model_info(:pavel)

    assert_equal "Pavel's Model", info[:name]
    assert info[:description].present?
    assert info[:assumptions].present?
    assert info[:annuity_rates].present?
    assert info[:model_params].present?
    assert info[:risk_metrics].present?

    # Check model params are documented
    assert info[:model_params][:cash_rate_initial].present?
    assert info[:model_params][:equity_return_mean].present?
  end

  # =============================================================================
  # MODEL COMPARISON TESTS
  # =============================================================================

  test "pavel model is more conservative than tom model" do
    tom = QuoteService.quote(home_value: 1_500_000, term: 10, model: :tom)
    pavel = QuoteService.quote(home_value: 1_500_000, term: 10, model: :pavel)

    # Pavel's model should give lower monthly income (more conservative)
    assert pavel[:monthly_income] < tom[:monthly_income],
           "Pavel's model should be more conservative (lower income) than Tom's"

    # Approximately 25% difference
    difference_pct = (tom[:monthly_income] - pavel[:monthly_income]).to_f / tom[:monthly_income] * 100
    assert difference_pct > 20, "Expected >20% difference, got #{difference_pct.round(1)}%"
  end

  test "both models use same LVR" do
    tom = QuoteService.quote(home_value: 1_500_000, term: 10, model: :tom)
    pavel = QuoteService.quote(home_value: 1_500_000, term: 10, model: :pavel)

    assert_equal tom[:lvr], pavel[:lvr]
    assert_equal tom[:max_loan], pavel[:max_loan]
  end

  test "switching models gives different results" do
    tom = QuoteService.quote(home_value: 2_000_000, term: 15, model: :tom)
    pavel = QuoteService.quote(home_value: 2_000_000, term: 15, model: :pavel)

    refute_equal tom[:monthly_income], pavel[:monthly_income]
    refute_equal tom[:total_income], pavel[:total_income]
    assert_equal tom[:home_value], pavel[:home_value]
    assert_equal tom[:term_years], pavel[:term_years]
  end
end
