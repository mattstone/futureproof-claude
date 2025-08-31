#!/usr/bin/env ruby

# Ruby Calculator Test - Run same parameters as Python
# This runs directly via Rails console to test the Ruby calculator service

require_relative 'config/environment'

# Use the exact same parameters as Python default values
params = {
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

puts "Running Ruby MortgageCalculatorService with Python default parameters..."
puts "Parameters: #{params.inspect}"
puts

# Create service and calculate
calculator = MortgageCalculatorService.new(params)

begin
  result = calculator.calculate
  puts "Calculation successful!"
  puts "Result keys: #{result.keys.inspect}"
  
  # Output key results for comparison
  puts "=== RUBY CALCULATOR RESULTS ==="
  
  # Handle the actual Ruby structure
  if result[:path_data] && result[:path_data][:mean]
    mean_path = result[:path_data][:mean]
    puts "Using mean path from Monte Carlo simulation"
    puts "Number of periods: #{mean_path.length}"
    
    # Extract data from the mean path (each element is an array with different metrics)
    puts "Initial portfolio value: #{mean_path.first[7].round(2)}"  # Based on structure analysis
    puts "Final portfolio value: #{mean_path.last[7].round(2)}"
    puts "Final loan balance: #{mean_path.last[4].round(2)}"
    puts "Final net equity: #{mean_path.last[8].round(2)}"
    
    # First 10 periods for comparison
    puts "\nFirst 10 portfolio values from Ruby Monte Carlo:"
    puts mean_path[0..9].map { |period| period[7].round(2) }
    
  elsif result[:paths]
    puts "Number of simulated paths: #{result[:paths].length}"
    puts "Portfolio value at end (path 1): #{result[:paths][0][:portfolio_values].last.round(2)}"
    puts "Total loan balance at end: #{result[:paths][0][:loan_balances].last.round(2)}"
    puts "Net equity at end: #{result[:paths][0][:net_equity].last.round(2)}"
    puts "Final equity price (path 1): #{result[:paths][0][:equity_prices].last.round(2)}"
    
  else
    puts "ERROR: Unexpected result structure!"
    puts "Available keys: #{result.keys.inspect}"
    puts "path_data keys: #{result[:path_data]&.keys&.inspect}"
    puts "main_outputs sample: #{result[:main_outputs]&.first(3)&.inspect}"
    exit 1
  end
rescue => e
  puts "ERROR in calculation: #{e.class}: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end

puts "\n=== END RUBY RESULTS ==="