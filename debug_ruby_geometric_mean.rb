#!/usr/bin/env ruby

require_relative 'config/environment'

# Test parameters for debugging geometric mean calculation
DEBUG_PARAMS = {
  house_value: 1500000,
  loan_duration: 30,
  annuity_duration: 15,
  loan_type: 'Interest only',
  loan_to_value: 0.8,
  annual_income: 30000,
  at_risk_capital_fraction: 0.0,
  annual_house_price_appreciation: 0.04,
  insurer_profit_margin: 0.5,
  wholesale_lending_margin: 0.02,
  additional_loan_margins: 0.015,
  holiday_enter_fraction: 1.35,
  holiday_exit_fraction: 1.95,
  subperform_loan_threshold_quarters: 6,
  insurance_cost_pa: 0.02,
  start_year: 2000,
  hedged: false,
  hedging_max_loss: 0.1,
  hedging_cap: 0.2,
  hedging_cost_pa: 0.01
}

puts "=== RUBY GEOMETRIC MEAN DEBUG ==="

begin
  calc = MortgageCalculatorAdvancedService.new(DEBUG_PARAMS)
  
  # Let's extract the same calculation components that Python uses
  total_loan = DEBUG_PARAMS[:house_value] * DEBUG_PARAMS[:loan_to_value]
  reinvest_fraction = 1.0 - (DEBUG_PARAMS[:annuity_duration] * DEBUG_PARAMS[:annual_income]) / total_loan
  insurance_profit_margin = 1.0 + DEBUG_PARAMS[:insurer_profit_margin]
  insurance_cost = DEBUG_PARAMS[:insurance_cost_pa] * total_loan * DEBUG_PARAMS[:loan_duration]

  puts "Basic calculations:"
  puts "  total_loan: #{total_loan}"
  puts "  reinvest_fraction: #{reinvest_fraction}"
  puts "  insurance_profit_margin: #{insurance_profit_margin}"
  puts "  insurance_cost: #{insurance_cost}"

  # Load historical data exactly as Ruby service does
  fedfunds_path = Rails.root.join('python', 'FEDFUNDS2.csv')
  fedfunds_data = []
  CSV.foreach(fedfunds_path, headers: true) do |row|
    fedfunds_data << row['FEDFUNDS'].to_f / 100.0
  end

  # Calculate start offset exactly as Ruby service does
  start_offset = (DEBUG_PARAMS[:start_year] - 1988) * 12
  required_months = DEBUG_PARAMS[:loan_duration] * 12
  max_interest_months = fedfunds_data.length

  if start_offset + required_months > max_interest_months
    start_offset = [0, max_interest_months - required_months].max
  end
  start_offset = [0, start_offset].max

  interest_series = fedfunds_data[start_offset, required_months] || [0.04] * required_months

  puts "Interest data:"
  puts "  start_offset: #{start_offset}"
  puts "  required_months: #{required_months}"
  puts "  interest_series length: #{interest_series.length}"
  puts "  first 5 rates: #{interest_series[0..4].map { |r| r.round(6) }}"

  # Ruby geometric mean calculation (current implementation)
  ruby_avg_cash_rate = interest_series.map { |r| 1 + r }.reduce(:*) ** (1.0 / interest_series.length) - 1
  puts "  ruby_avg_cash_rate: #{ruby_avg_cash_rate.round(8)}"

  # Python equivalent using different method
  product = 1.0
  interest_series.each { |rate| product *= (1 + rate) }
  python_avg_cash_rate = product ** (1.0 / interest_series.length) - 1
  puts "  python_avg_cash_rate: #{python_avg_cash_rate.round(8)}"

  puts "  Match: #{(ruby_avg_cash_rate - python_avg_cash_rate).abs < 0.00000001 ? 'YES' : 'NO'}"

  # Initial reinvestment calculation
  ruby_initial_reinvest = total_loan * reinvest_fraction - 
    insurance_profit_margin * insurance_cost / ((1 + ruby_avg_cash_rate) ** DEBUG_PARAMS[:loan_duration])

  python_initial_reinvest = total_loan * reinvest_fraction - 
    insurance_profit_margin * insurance_cost / ((1 + python_avg_cash_rate) ** DEBUG_PARAMS[:loan_duration])

  puts "\nInitial reinvestment calculation:"
  puts "  component1 (total_loan * reinvest_fraction): #{total_loan * reinvest_fraction}"
  puts "  component2_num (insurance_profit_margin * insurance_cost): #{insurance_profit_margin * insurance_cost}"
  
  ruby_denominator = ((1 + ruby_avg_cash_rate) ** DEBUG_PARAMS[:loan_duration])
  python_denominator = ((1 + python_avg_cash_rate) ** DEBUG_PARAMS[:loan_duration])
  puts "  ruby_denominator: #{ruby_denominator.round(8)}"
  puts "  python_denominator: #{python_denominator.round(8)}"

  ruby_component2 = insurance_profit_margin * insurance_cost / ruby_denominator
  python_component2 = insurance_profit_margin * insurance_cost / python_denominator
  puts "  ruby_component2: #{ruby_component2.round(8)}"
  puts "  python_component2: #{python_component2.round(8)}"

  puts "  ruby_initial_reinvest: #{ruby_initial_reinvest.round(8)}"
  puts "  python_initial_reinvest: #{python_initial_reinvest.round(8)}"
  puts "  Expected Python result: -38577"

rescue => e
  puts "❌ Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(5)
end