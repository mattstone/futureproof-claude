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

puts "=== PERFORMANCE VERIFICATION TEST ==="
puts

# Test multiple iterations to get accurate timing
num_iterations = 10
puts "Running #{num_iterations} iterations for accurate timing..."

# Ruby Performance Test
ruby_times = []
num_iterations.times do |i|
  time = Benchmark.realtime do
    calculator = MortgageCalculatorHistoricalService.new(TEST_PARAMS)
    result = calculator.calculate
  end
  ruby_times << time
  print "."
end

puts "\n"

avg_ruby_time = ruby_times.sum / ruby_times.length
min_ruby_time = ruby_times.min
max_ruby_time = ruby_times.max

puts "Ruby Historical Service Performance:"
puts "  Average: #{(avg_ruby_time * 1000).round(2)}ms"
puts "  Min: #{(min_ruby_time * 1000).round(2)}ms"
puts "  Max: #{(max_ruby_time * 1000).round(2)}ms"

# Python Performance Test
python_times = []
num_iterations.times do |i|
  time = Benchmark.realtime do
    `cd python && python3 single_real_data.py > /dev/null 2>&1`
  end
  python_times << time
  print "."
end

puts "\n"

avg_python_time = python_times.sum / python_times.length
min_python_time = python_times.min
max_python_time = python_times.max

puts "Python Historical Script Performance:"
puts "  Average: #{(avg_python_time * 1000).round(2)}ms"
puts "  Min: #{(min_python_time * 1000).round(2)}ms"
puts "  Max: #{(max_python_time * 1000).round(2)}ms"

# Performance comparison
speedup = avg_python_time / avg_ruby_time
puts "\nPerformance Comparison:"
puts "  Ruby is #{speedup.round(1)}x FASTER than Python"

# Scaling estimates for 100,000 calculations
puts "\n=== 100,000 CALCULATION PROJECTIONS ==="
ruby_100k_time = avg_ruby_time * 100_000
python_100k_time = avg_python_time * 100_000

puts "Ruby (100k calculations):"
puts "  Estimated time: #{ruby_100k_time.round(1)} seconds"
puts "  Estimated time: #{(ruby_100k_time / 60).round(1)} minutes"
puts "  Estimated time: #{(ruby_100k_time / 3600).round(1)} hours"

puts "\nPython (100k calculations):"
puts "  Estimated time: #{python_100k_time.round(1)} seconds"
puts "  Estimated time: #{(python_100k_time / 60).round(1)} minutes"
puts "  Estimated time: #{(python_100k_time / 3600).round(1)} hours"

# Performance per hour
ruby_calcs_per_hour = 3600 / avg_ruby_time
python_calcs_per_hour = 3600 / avg_python_time

puts "\nThroughput (calculations per hour):"
puts "  Ruby: #{ruby_calcs_per_hour.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} calculations/hour"
puts "  Python: #{python_calcs_per_hour.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} calculations/hour"

puts "\n=== RECOMMENDATION ==="
if speedup > 10
  puts "✓ Ruby is SIGNIFICANTLY faster - use Ruby for large batch processing"
  puts "✓ Ruby can handle 100,000 calculations in under #{(ruby_100k_time / 3600).round(1)} hour(s)"
elsif speedup > 2
  puts "✓ Ruby is moderately faster - good choice for large batches"  
else
  puts "⚠ Performance difference is minimal - choose based on other factors"
end

puts "\n=== TEST COMPLETE ==="