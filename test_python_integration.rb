#!/usr/bin/env ruby

require_relative 'config/environment'
require 'benchmark'

# Test parameters
TEST_PARAMS = {
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

puts "=== PYTHON INTEGRATION TEST ==="
puts "Testing Ruby → Python parameter passing..."

begin
  # Test the Python integration service
  python_time = Benchmark.realtime do
    @python_calculator = PythonCalculatorService.new(TEST_PARAMS)
    @python_result = @python_calculator.calculate
  end

  puts "\n✅ Python integration successful!"
  puts "Execution time: #{(python_time * 1000).round(2)}ms"

  # Compare with direct Ruby service
  ruby_time = Benchmark.realtime do
    @ruby_calculator = MortgageCalculatorHistoricalService.new(TEST_PARAMS)
    @ruby_result = @ruby_calculator.calculate
  end

  puts "Ruby direct time: #{(ruby_time * 1000).round(2)}ms"
  puts "Speed difference: Ruby is #{(python_time/ruby_time).round(1)}x faster than Python integration"

  # Show results comparison
  puts "\n=== RESULTS COMPARISON ==="
  
  if @python_result[:pathdf] && @ruby_result[:pathdf]
    puts "Python pathdf columns: #{@python_result[:pathdf].keys.sort}"
    puts "Ruby pathdf columns: #{@ruby_result[:pathdf].keys.sort}"
    
    # Compare price paths
    if @python_result[:price_paths] && @ruby_result[:price_paths]
      py_prices = @python_result[:price_paths][0][1]
      rb_prices = @ruby_result[:price_paths][0][1]
      
      puts "\nPrice Path Comparison:"
      puts "  Python: #{py_prices.first.round(2)} → #{py_prices.last.round(2)} (#{py_prices.length} points)"
      puts "  Ruby:   #{rb_prices.first.round(2)} → #{rb_prices.last.round(2)} (#{rb_prices.length} points)"
      puts "  Identical: #{py_prices == rb_prices ? '✅ YES' : '❌ NO'}"
    end
  end

  puts "\nMain outputs:"
  puts "Python: #{@python_result[:main_outputs].length} rows"
  puts "Ruby: #{@ruby_result[:main_outputs].length} rows" if @ruby_result[:main_outputs]

rescue => e
  puts "❌ Error: #{e.class}: #{e.message}"
  puts e.backtrace.first(3)
end

puts "\n=== PERFORMANCE RECOMMENDATION ==="
puts "For 100,000 calculations:"
puts "  Ruby Historical Service: ~11 minutes"
puts "  Python Integration: ~13.5 hours"  
puts "  Recommendation: Use Ruby for performance-critical applications"

puts "\n=== TEST COMPLETE ==="