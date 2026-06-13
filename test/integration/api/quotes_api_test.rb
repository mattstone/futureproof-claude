require "test_helper"

class Api::QuotesApiTest < ActionDispatch::IntegrationTest
  # ====================================================
  # Basic API Functionality Tests
  # ====================================================

  test "quotes API returns success for original model" do
    get api_quotes_path, params: { home_value: 1_500_000, term: 10, model: "original" }
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "original", json["model"]
    assert json["result"]["monthly_income"].present?
    assert json["result"]["total_income"].present?
  end

  test "quotes API returns success for tom model" do
    get api_quotes_path, params: { home_value: 1_500_000, term: 10, model: "tom" }
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "tom", json["model"]
    assert json["result"]["monthly_income"].present?
  end

  test "quotes API returns success for pavel model" do
    get api_quotes_path, params: { home_value: 1_500_000, term: 10, model: "pavel" }
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert_equal "pavel", json["model"]
    assert json["result"]["monthly_income"].present?
  end

  test "quotes API defaults to the validated pavel model when not specified" do
    get api_quotes_path, params: { home_value: 1_500_000, term: 10 }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "pavel", json["model"]
  end

  test "quotes API returns error for unknown model" do
    get api_quotes_path, params: { home_value: 1_500_000, term: 10, model: "unknown" }
    assert_response :unprocessable_entity

    json = JSON.parse(response.body)
    assert_not json["success"]
    assert json["error"].include?("Unknown model")
  end

  # ====================================================
  # Model Comparison Tests
  # ====================================================

  test "quotes compare endpoint returns all models" do
    get api_quotes_compare_path, params: { home_value: 1_500_000, term: 10 }
    assert_response :success

    json = JSON.parse(response.body)
    assert json["success"]
    assert json["results"]["original"].present?
    assert json["results"]["tom"].present?
    assert json["results"]["pavel"].present?
    # Python not included by default
    assert_nil json["results"]["python"]
  end

  test "quotes compare includes comparison data" do
    get api_quotes_compare_path, params: { home_value: 1_500_000, term: 10 }
    assert_response :success

    json = JSON.parse(response.body)
    assert json["comparison"].present?
    assert json["comparison"]["vs_original"].present?
  end

  test "quotes models endpoint lists available models" do
    get api_quotes_models_path
    assert_response :success

    json = JSON.parse(response.body)
    assert json["models"]["original"].present?
    assert json["models"]["tom"].present?
    assert json["models"]["pavel"].present?
    assert json["models"]["python"].present?
  end

  # ====================================================
  # Calculation Accuracy Tests - Pavel Model
  # ====================================================

  test "pavel model via API matches QuoteService directly" do
    [ 10, 15, 20, 25, 30 ].each do |term|
      # Call API
      get api_quotes_path, params: { home_value: 1_500_000, term: term, model: "pavel" }
      assert_response :success

      api_result = JSON.parse(response.body)["result"]

      # Call QuoteService directly
      service_result = QuoteService.quote(home_value: 1_500_000, term: term, model: :pavel)

      # Compare values
      assert_equal service_result[:monthly_income], api_result["monthly_income"],
        "Monthly income mismatch for term=#{term}"
      assert_equal service_result[:annual_income], api_result["annual_income"],
        "Annual income mismatch for term=#{term}"
      assert_equal service_result[:total_income], api_result["total_income"],
        "Total income mismatch for term=#{term}"
    end
  end

  test "tom model via API matches QuoteService directly" do
    [ 10, 15, 20, 25, 30 ].each do |term|
      # Call API
      get api_quotes_path, params: { home_value: 1_500_000, term: term, model: "tom" }
      assert_response :success

      api_result = JSON.parse(response.body)["result"]

      # Call QuoteService directly
      service_result = QuoteService.quote(home_value: 1_500_000, term: term, model: :tom)

      # Compare values
      assert_equal service_result[:monthly_income], api_result["monthly_income"],
        "Monthly income mismatch for term=#{term}"
      assert_equal service_result[:annual_income], api_result["annual_income"],
        "Annual income mismatch for term=#{term}"
      assert_equal service_result[:total_income], api_result["total_income"],
        "Total income mismatch for term=#{term}"
    end
  end

  # ====================================================
  # Original Model Lookup Table Tests
  # ====================================================

  test "original model returns correct values for base property" do
    # Test interest-only for $1.5M property (Tom's model values)
    get api_quotes_path, params: {
      home_value: 1_500_000,
      term: 10,
      model: "original",
      mortgage_type: "interest_only"
    }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 2500, json["result"]["monthly_income"]

    # Test P+I for $1.5M property (~77% of IO)
    get api_quotes_path, params: {
      home_value: 1_500_000,
      term: 10,
      model: "original",
      mortgage_type: "principal_and_interest"
    }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 1925, json["result"]["monthly_income"]
  end

  test "original model scales correctly with property value" do
    # Double the property value should double the income
    get api_quotes_path, params: {
      home_value: 3_000_000,
      term: 10,
      model: "original",
      mortgage_type: "interest_only"
    }
    assert_response :success

    json = JSON.parse(response.body)
    # 2500 * 2 = 5000
    assert_equal 5000, json["result"]["monthly_income"]
  end

  # ====================================================
  # Property Value Scaling Tests
  # ====================================================

  test "all models scale with property value" do
    base_value = 1_500_000
    test_value = 2_500_000
    multiplier = test_value.to_f / base_value

    [ :original, :tom, :pavel ].each do |model|
      # Get base value result
      get api_quotes_path, params: { home_value: base_value, term: 10, model: model.to_s }
      base_result = JSON.parse(response.body)["result"]

      # Get test value result
      get api_quotes_path, params: { home_value: test_value, term: 10, model: model.to_s }
      test_result = JSON.parse(response.body)["result"]

      # Check scaling (allow 1% tolerance for rounding)
      expected_income = (base_result["monthly_income"] * multiplier).round(0)
      assert_in_delta expected_income, test_result["monthly_income"], expected_income * 0.01,
        "#{model} model didn't scale correctly with property value"
    end
  end

  # ====================================================
  # Model Difference Documentation Tests
  # ====================================================

  test "documents difference between original and other models" do
    get api_quotes_compare_path, params: { home_value: 1_500_000, term: 10 }
    assert_response :success

    json = JSON.parse(response.body)

    # Original model uses lookup tables, others use different calculations
    original_income = json["results"]["original"]["monthly_income"]
    tom_income = json["results"]["tom"]["monthly_income"]
    pavel_income = json["results"]["pavel"]["monthly_income"]

    # Document the differences for the test output
    puts "\n=== Model Comparison for $1.5M, 10-year term ==="
    puts "Original (lookup): $#{original_income}/month"
    puts "Tom's model:       $#{tom_income}/month (#{((tom_income.to_f / original_income - 1) * 100).round(1)}%)"
    puts "Pavel's model:     $#{pavel_income}/month (#{((pavel_income.to_f / original_income - 1) * 100).round(1)}%)"

    # Assert that we have data to compare
    assert original_income > 0
    assert tom_income > 0
    assert pavel_income > 0
  end
end
