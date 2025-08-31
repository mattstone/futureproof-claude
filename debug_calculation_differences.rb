#!/usr/bin/env ruby

require_relative 'config/environment'

# Test parameters for detailed debugging
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

puts "=== DETAILED CALCULATION DEBUGGING ==="
puts "Finding exact differences between Ruby Advanced and Python calculations..."
puts

begin
  # Get Ruby Advanced result
  puts "1. Running Ruby Advanced calculation..."
  @ruby_calculator = MortgageCalculatorAdvancedService.new(DEBUG_PARAMS)
  @ruby_result = @ruby_calculator.calculate

  # Get Python result
  puts "2. Running Python calculation..."
  @python_calculator = PythonCalculatorService.new(DEBUG_PARAMS)
  @python_result = @python_calculator.calculate
  
  puts "3. Analyzing differences..."
  
  ruby_pathdf = @ruby_result[:pathdf]
  python_pathdf = @python_result[:pathdf]
  
  puts "\n=== INITIAL PARAMETERS COMPARISON ==="
  
  # Calculate derived values manually to check
  total_loan = DEBUG_PARAMS[:house_value] * DEBUG_PARAMS[:loan_to_value]
  reinvest_fraction = 1.0 - (DEBUG_PARAMS[:annuity_duration] * DEBUG_PARAMS[:annual_income]) / total_loan
  insurance_profit_margin = 1.0 + DEBUG_PARAMS[:insurer_profit_margin]
  insurance_cost = DEBUG_PARAMS[:insurance_cost_pa] * total_loan * DEBUG_PARAMS[:loan_duration]
  
  puts "Total loan: $#{total_loan}"
  puts "Reinvest fraction: #{reinvest_fraction.round(6)}"
  puts "Insurance profit margin: #{insurance_profit_margin}"
  puts "Insurance cost: $#{insurance_cost}"
  
  # Check first few rows for differences
  puts "\n=== FIRST 10 PERIODS COMPARISON ==="
  puts "Period | Ruby Reinvestment | Python Reinvestment | Difference | Ruby Holiday | Python Holiday"
  puts "-" * 100
  
  (0..9).each do |i|
    ruby_reinvest = ruby_pathdf['Reinvestment'][i]
    python_reinvest = python_pathdf['Reinvestment'][i]
    difference = ruby_reinvest - python_reinvest
    ruby_holiday = ruby_pathdf['Prob Holiday'][i]
    python_holiday = python_pathdf['Prob Holiday'][i]
    
    puts "#{i.to_s.rjust(6)} | #{ruby_reinvest.round(2).to_s.rjust(15)} | #{python_reinvest.round(2).to_s.rjust(17)} | #{difference.round(2).to_s.rjust(10)} | #{ruby_holiday.to_s.rjust(12)} | #{python_holiday.to_s.rjust(14)}"
  end
  
  # Check key calculated fields
  puts "\n=== KEY FIELD COMPARISON (First 10 periods) ==="
  
  fields_to_compare = [
    'Units', 'Interest', 'InterestPaid', 'InterestDeficit', 
    'UnitsSold', 'CumUnitsSold', 'HolidayQuarters', 'AnnuityIncome'
  ]
  
  fields_to_compare.each do |field|
    puts "\n#{field}:"
    puts "Period | Ruby | Python | Difference"
    (0..9).each do |i|
      ruby_val = ruby_pathdf[field][i]
      python_val = python_pathdf[field][i]
      diff = ruby_val.is_a?(Numeric) && python_val.is_a?(Numeric) ? ruby_val - python_val : "N/A"
      
      ruby_display = ruby_val.is_a?(Numeric) ? ruby_val.round(6) : ruby_val
      python_display = python_val.is_a?(Numeric) ? python_val.round(6) : python_val
      diff_display = diff.is_a?(Numeric) ? diff.round(6) : diff
      
      puts "#{i.to_s.rjust(6)} | #{ruby_display.to_s.rjust(12)} | #{python_display.to_s.rjust(12)} | #{diff_display.to_s.rjust(12)}"
    end
  end
  
  # Check final values
  puts "\n=== FINAL VALUES COMPARISON ==="
  final_index = -1
  
  [
    'Reinvestment', 'Units', 'InterestDeficit', 'CumUnitsSold', 
    'CumInterestPaid', 'HolidayQuarters', 'Prob Holiday'
  ].each do |field|
    ruby_final = ruby_pathdf[field][final_index]
    python_final = python_pathdf[field][final_index]
    difference = ruby_final.is_a?(Numeric) && python_final.is_a?(Numeric) ? ruby_final - python_final : "N/A"
    
    ruby_display = ruby_final.is_a?(Numeric) ? ruby_final.round(6) : ruby_final
    python_display = python_final.is_a?(Numeric) ? python_final.round(6) : python_final
    diff_display = difference.is_a?(Numeric) ? difference.round(6) : difference
    
    puts "#{field.ljust(20)}: Ruby=#{ruby_display}, Python=#{python_display}, Diff=#{diff_display}"
  end
  
  # Price path verification
  puts "\n=== PRICE PATH VERIFICATION ==="
  ruby_prices = @ruby_result[:price_paths][0][1]
  python_prices = @python_result[:price_paths][0][1]
  
  puts "Ruby price path length: #{ruby_prices.length}"
  puts "Python price path length: #{python_prices.length}"
  puts "First 5 Ruby prices: #{ruby_prices[0..4].map { |p| p.round(2) }}"
  puts "First 5 Python prices: #{python_prices[0..4].map { |p| p.round(2) }}"
  puts "Price paths identical: #{ruby_prices == python_prices}"
  
  # Check quarterly vs monthly issue
  puts "\n=== QUARTERLY VS MONTHLY ANALYSIS ==="
  puts "Ruby pathdf periods: #{ruby_pathdf['Period'].length}"
  puts "Python pathdf periods: #{python_pathdf['Period'].length}"
  puts "Ruby max period: #{ruby_pathdf['Period'].max}"
  puts "Python max period: #{python_pathdf['Period'].max}"
  
  # Check initial reinvestment calculation
  puts "\n=== INITIAL REINVESTMENT ANALYSIS ==="
  
  # Python's calculation logic
  sp500_file = File.join(Rails.root, 'python', 'sp500tr.csv')
  fedfunds_file = File.join(Rails.root, 'python', 'FEDFUNDS2.csv')
  
  if File.exist?(fedfunds_file)
    fedfunds_data = []
    CSV.foreach(fedfunds_file, headers: true) do |row|
      fedfunds_data << row['FEDFUNDS'].to_f / 100.0
    end
    
    # Calculate start offset
    start_offset = (DEBUG_PARAMS[:start_year] - 1988) * 12
    required_months = DEBUG_PARAMS[:loan_duration] * 12
    start_offset = [0, [start_offset, fedfunds_data.length - required_months].min].max
    
    interest_series = fedfunds_data[start_offset, required_months] || [0.04] * required_months
    
    # Geometric mean calculation
    avg_cash_rate = interest_series.map { |r| 1 + r }.reduce(:*) ** (1.0 / interest_series.length) - 1
    
    puts "Interest series length: #{interest_series.length}"
    puts "First 5 rates: #{interest_series[0..4].map { |r| r.round(6) }}"
    puts "Calculated avg_cash_rate (geometric mean): #{avg_cash_rate.round(8)}"
    
    # Python's initial reinvestment formula
    python_initial_reinvest = total_loan * reinvest_fraction - 
      insurance_profit_margin * insurance_cost / ((1 + avg_cash_rate) ** DEBUG_PARAMS[:loan_duration])
    
    puts "Expected initial reinvestment: $#{python_initial_reinvest.round(2)}"
    
    # Check first row values
    puts "\nFirst row Ruby reinvestment: $#{ruby_pathdf['Reinvestment'][0].round(2)}"
    puts "First row Python reinvestment: $#{python_pathdf['Reinvestment'][0].round(2)}"
    
    # Holiday thresholds
    holiday_enter = python_initial_reinvest * DEBUG_PARAMS[:holiday_enter_fraction]
    holiday_exit = python_initial_reinvest * DEBUG_PARAMS[:holiday_exit_fraction]
    puts "Holiday enter threshold: $#{holiday_enter.round(2)}"
    puts "Holiday exit threshold: $#{holiday_exit.round(2)}"
  end

rescue => e
  puts "❌ Error during debugging: #{e.class}: #{e.message}"
  puts e.backtrace.first(10)
end

puts "\n=== DEBUG COMPLETE ==="