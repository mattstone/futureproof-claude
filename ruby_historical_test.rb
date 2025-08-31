#!/usr/bin/env ruby

require_relative 'config/environment'

# Test parameters - same as Python defaults
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

puts "=== RUBY HISTORICAL CALCULATOR TEST ==="
puts "Running Ruby Historical MortgageCalculatorService..."

begin
  calculator = MortgageCalculatorHistoricalService.new(params)
  result = calculator.calculate

  puts "\n✓ Calculation successful!"
  puts "Available result keys: #{result.keys}"

  if result[:pathdf]
    pathdf = result[:pathdf]
    periods = pathdf['Period'].length
    
    puts "\n=== RESULTS ==="
    puts "Total periods: #{periods}"
    puts "Final period: #{pathdf['Period'].last}"
    puts "Final year: #{pathdf['Year'].last}"
    
    puts "\nEquity Prices:"
    puts "  Initial: #{pathdf['EquityPrice'].first.round(2)}"
    puts "  Final: #{pathdf['EquityPrice'].last.round(2)}"
    
    puts "\nPortfolio Values:"
    puts "  Initial: #{pathdf['PortfolioValue'].first.round(2)}"
    puts "  Final: #{pathdf['PortfolioValue'].last.round(2)}"
    
    puts "\nLoan Balance:"
    puts "  Initial: #{pathdf['LoanBalance'].first.round(2)}"
    puts "  Final: #{pathdf['LoanBalance'].last.round(2)}"
    
    puts "\nNet Equity:"
    puts "  Initial: #{pathdf['NetEquity'].first.round(2)}"
    puts "  Final: #{pathdf['NetEquity'].last.round(2)}"
    
    puts "\nTotal Annuity Income: #{pathdf['CumAnnuityIncome'].last.round(2)}"
    puts "Total Interest Paid: #{pathdf['CumInterestPaid'].last.round(2)}"
    
    # Show first 10 equity prices for comparison with Python
    puts "\nFirst 10 equity prices:"
    pathdf['EquityPrice'][0..9].each_with_index do |price, i|
      puts "  Month #{i}: #{price.round(2)}"
    end
  else
    puts "⚠ No pathdf in result"
  end

  if result[:price_paths]
    puts "\nPrice paths available: #{result[:price_paths].length}"
    first_path = result[:price_paths].first[1] # [0, price_array]
    puts "First path length: #{first_path.length}"
    puts "First path starts at: #{first_path.first.round(2)}"
    puts "First path ends at: #{first_path.last.round(2)}"
  end

  if result[:accounts_table]
    puts "\nAccounts Table:"
    result[:accounts_table].each do |row|
      puts "  #{row[0]}: #{row[1]}"
    end
  end

rescue => e
  puts "✗ Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n=== TEST COMPLETE ==="