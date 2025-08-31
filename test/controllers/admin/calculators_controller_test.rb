require "test_helper"

class Admin::CalculatorsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  
  def setup
    @admin_user = users(:admin_user)
    sign_in @admin_user
  end

  test "should get index" do
    get admin_calculators_url
    assert_response :success
    assert_select "h1", "Single mortgage model with Monte Carlo prices"
    assert_select "form"
    assert_select "input[name='calculator[house_value]']"
    assert_select "input[type='submit'][value='Calculate']"
  end

  test "should calculate with valid parameters" do
    valid_params = {
      calculator: {
        house_value: 1500000,
        loan_duration: 30,
        annuity_duration: 10,
        loan_type: "Interest only",
        principal_repayment: false,
        loan_to_value: 80,
        annual_income: 30000,
        at_risk_captital_fraction: 0,
        equity_return: 10.8,
        volatility: 15,
        total_paths: 10, # Small number for fast test
        random_seed: 42,
        cash_rate: 3.85,
        insurer_profit_margin: 50,
        hedged: false,
        wholesale_lending_margin: 2,
        additional_loan_margins: 1.25,
        holiday_enter_fraction: 0.9,
        holiday_exit_fraction: 1.458,
        subperform_loan_threshold_quarters: 12,
        max_superpay_factor: 1.261,
        superpay_start_factor: 1.50,
        enable_pool: false
      }
    }

    post calculate_admin_calculators_url, params: valid_params, headers: { 'Accept' => 'application/json' }
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("main_outputs")
    assert json_response.key?("path_data")
    assert json_response.key?("total_paths")
    assert_equal 10, json_response["total_paths"]
    
    # Check main outputs structure
    assert json_response["main_outputs"].is_a?(Array)
    assert json_response["main_outputs"].length > 0
    
    # Check path data structure
    assert json_response["path_data"].is_a?(Hash)
    assert json_response["path_data"].key?("mean")
  end

  test "should handle missing required parameters" do
    invalid_params = {
      calculator: {
        # Missing required parameters - pass empty values to trigger validation
        house_value: '',
        loan_duration: '',
        annuity_duration: '',
        annual_income: '',
        total_paths: ''
      }
    }

    post calculate_admin_calculators_url, params: invalid_params, headers: { 'Accept' => 'application/json' }
    assert_response :unprocessable_content

    json_response = JSON.parse(response.body)
    assert json_response.key?("error")
  end

  test "should handle invalid parameter values" do
    invalid_params = {
      calculator: {
        house_value: 1500000,
        loan_duration: 30,
        annuity_duration: 10,
        annual_income: 30000,
        total_paths: -1, # Invalid negative value
        loan_to_value: 150 # Invalid percentage > 100
      }
    }

    post calculate_admin_calculators_url, params: invalid_params, headers: { 'Accept' => 'application/json' }
    assert_response :unprocessable_content

    json_response = JSON.parse(response.body)
    assert json_response.key?("error")
  end

  test "should work with hedged calculations" do
    hedged_params = {
      calculator: {
        house_value: 1500000,
        loan_duration: 30,
        annuity_duration: 10,
        annual_income: 30000,
        total_paths: 5,
        hedged: true,
        hedging_cost_pa: 0.5,
        hedging_max_loss: 10,
        hedging_cap: 20,
        loan_to_value: 80,
        equity_return: 10.8,
        volatility: 15,
        cash_rate: 3.85,
        wholesale_lending_margin: 2,
        additional_loan_margins: 1.25,
        holiday_enter_fraction: 0.9,
        holiday_exit_fraction: 1.458,
        subperform_loan_threshold_quarters: 12,
        max_superpay_factor: 1.261,
        superpay_start_factor: 1.50,
        enable_pool: false
      }
    }

    post calculate_admin_calculators_url, params: hedged_params, headers: { 'Accept' => 'application/json' }
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("main_outputs")
    assert json_response.key?("path_data")
  end

  test "should work with different loan types" do
    ["Interest only", "Principal+Interest", "Hybrid"].each do |loan_type|
      params = {
        calculator: {
          house_value: 1500000,
          loan_duration: 30,
          annuity_duration: 10,
          loan_type: loan_type,
          annual_income: 30000,
          total_paths: 5,
          loan_to_value: 80,
          equity_return: 10.8,
          volatility: 15,
          cash_rate: 3.85,
          wholesale_lending_margin: 2,
          additional_loan_margins: 1.25,
          holiday_enter_fraction: 0.9,
          holiday_exit_fraction: 1.458,
          subperform_loan_threshold_quarters: 12,
          max_superpay_factor: 1.261,
          superpay_start_factor: 1.50,
          enable_pool: false
        }
      }

      post calculate_admin_calculators_url, params: params, headers: { 'Accept' => 'application/json' }
      assert_response :success, "Failed for loan type: #{loan_type}"

      json_response = JSON.parse(response.body)
      assert json_response.key?("main_outputs"), "Missing main_outputs for loan type: #{loan_type}"
      assert json_response.key?("path_data"), "Missing path_data for loan type: #{loan_type}"
    end
  end

  test "should require authentication" do
    sign_out @admin_user
    
    get admin_calculators_url
    assert_redirected_to new_user_session_path
  end

  test "should work with realistic parameter ranges" do
    # Test with various realistic parameter combinations
    test_cases = [
      {
        name: "High value property",
        params: {
          house_value: 2500000,
          loan_to_value: 70,
          annual_income: 45000,
          total_paths: 5
        }
      },
      {
        name: "Conservative scenario",
        params: {
          house_value: 1200000,
          loan_to_value: 60,
          annual_income: 25000,
          equity_return: 8.0,
          volatility: 12,
          total_paths: 5
        }
      },
      {
        name: "Aggressive scenario",
        params: {
          house_value: 1800000,
          loan_to_value: 90,
          annual_income: 40000,
          equity_return: 12.0,
          volatility: 20,
          total_paths: 5
        }
      }
    ]

    base_params = {
      calculator: {
        loan_duration: 30,
        annuity_duration: 10,
        loan_type: "Interest only",
        cash_rate: 3.85,
        wholesale_lending_margin: 2,
        additional_loan_margins: 1.25,
        holiday_enter_fraction: 0.9,
        holiday_exit_fraction: 1.458,
        subperform_loan_threshold_quarters: 12,
        max_superpay_factor: 1.261,
        superpay_start_factor: 1.50,
        enable_pool: false
      }
    }

    test_cases.each do |test_case|
      params = base_params.deep_dup
      params[:calculator].merge!(test_case[:params])

      post calculate_admin_calculators_url, params: params, headers: { 'Accept' => 'application/json' }
      assert_response :success, "Failed for test case: #{test_case[:name]}"

      json_response = JSON.parse(response.body)
      assert json_response.key?("main_outputs"), "Missing main_outputs for: #{test_case[:name]}"
      assert json_response["main_outputs"].length > 0, "Empty main_outputs for: #{test_case[:name]}"
    end
  end

  private

  def sign_out(user)
    delete destroy_user_session_url
  end
end