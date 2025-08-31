#!/usr/bin/env ruby

require_relative 'config/environment'
require 'benchmark'
require 'json'

# Test parameters - same for both versions
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

puts "=== PERFORMANCE BENCHMARK ==="
puts "Testing single calculation performance..."
puts

# Test 1: Single calculation comparison
puts "1. Single Calculation Performance:"

# Ruby Historical Version
ruby_time = nil
ruby_result = nil
ruby_time = Benchmark.realtime do
  calculator = MortgageCalculatorHistoricalService.new(TEST_PARAMS)
  ruby_result = calculator.calculate
end

puts "   Ruby Historical Service: #{(ruby_time * 1000).round(2)}ms"

# Python Version (single run)
python_time = nil
python_result = nil
python_time = Benchmark.realtime do
  # Run Python script and capture timing
  output = `cd python && time python3 single_real_data.py 2>&1`
  python_result = JSON.parse(output.split("\n").find { |line| line.start_with?('{') } || '{}')
rescue => e
  puts "   Python execution failed: #{e.message}"
  python_time = Float::INFINITY
end

if python_time && python_time != Float::INFINITY
  puts "   Python Historical Script: #{(python_time * 1000).round(2)}ms"
else
  puts "   Python Historical Script: FAILED"
end

puts

# Test 2: Accuracy comparison
puts "2. Results Accuracy Comparison:"
if ruby_result && python_result.is_a?(Hash) && python_result['pathdf']
  
  # Compare key metrics
  ruby_pathdf = ruby_result[:pathdf]
  python_pathdf = python_result['pathdf']
  
  if ruby_pathdf && python_pathdf
    ruby_final_portfolio = ruby_pathdf['PortfolioValue']&.last
    python_final_portfolio = python_pathdf['PortfolioValue']&.last
    
    ruby_final_net_equity = ruby_pathdf['NetEquity']&.last  
    python_final_net_equity = python_pathdf['NetEquity']&.last
    
    puts "   Final Portfolio Value:"
    puts "     Ruby:   #{ruby_final_portfolio&.round(2) || 'N/A'}"
    puts "     Python: #{python_final_portfolio&.round(2) || 'N/A'}"
    
    if ruby_final_portfolio && python_final_portfolio
      diff_pct = ((ruby_final_portfolio - python_final_portfolio).abs / python_final_portfolio * 100).round(4)
      puts "     Difference: #{diff_pct}%"
    end
    
    puts
    puts "   Final Net Equity:"
    puts "     Ruby:   #{ruby_final_net_equity&.round(2) || 'N/A'}"  
    puts "     Python: #{python_final_net_equity&.round(2) || 'N/A'}"
    
    if ruby_final_net_equity && python_final_net_equity
      diff_pct = ((ruby_final_net_equity - python_final_net_equity).abs / python_final_net_equity.abs * 100).round(4)
      puts "     Difference: #{diff_pct}%"
    end
  else
    puts "   Could not compare - missing pathdf data"
  end
else
  puts "   Could not compare - missing result data"
end

puts

# Test 3: Scaling performance for 100,000 simulations
puts "3. Scaling Performance Estimates (for 100,000 calculations):"

if ruby_time
  ruby_100k_time = ruby_time * 100_000
  puts "   Ruby Historical (estimated): #{ruby_100k_time.round(1)} seconds (#{(ruby_100k_time/60).round(1)} minutes)"
end

if python_time && python_time != Float::INFINITY
  python_100k_time = python_time * 100_000
  puts "   Python Historical (estimated): #{python_100k_time.round(1)} seconds (#{(python_100k_time/60).round(1)} minutes)"
  
  if ruby_time
    speedup = ruby_100k_time / python_100k_time
    if speedup > 1
      puts "   Python is #{speedup.round(1)}x FASTER than Ruby"
    else
      puts "   Ruby is #{(1/speedup).round(1)}x FASTER than Python"
    end
  end
end

puts

# Test 4: Memory usage comparison (rough estimate)
puts "4. Memory Usage (approximate):"

require 'objspace'

GC.start
before_memory = `ps -o rss= -p #{Process.pid}`.to_i

# Create multiple instances to test memory scaling
10.times do
  calculator = MortgageCalculatorHistoricalService.new(TEST_PARAMS)
  calculator.calculate
end

GC.start
after_memory = `ps -o rss= -p #{Process.pid}`.to_i

memory_per_calc = (after_memory - before_memory) / 10.0
puts "   Ruby memory per calculation: ~#{memory_per_calc.round(1)} KB"
puts "   Ruby estimated memory for 100k: ~#{(memory_per_calc * 100_000 / 1024).round(1)} MB"

puts

# Test 5: Optimization recommendations
puts "5. Optimization Recommendations:"
puts "   For 100,000 calculations:"

if python_time && ruby_time
  if python_time < ruby_time
    puts "   ✓ Python is faster - consider using Python for large batch processing"
    puts "   ✓ Ruby service good for web interface (individual calculations)"
  else  
    puts "   ✓ Ruby is competitive - can handle large batches efficiently"
  end
else
  puts "   ⚠ Could not determine relative performance"
end

puts "   ✓ Consider parallel processing for 100k calculations"  
puts "   ✓ Consider caching historical data in memory"
puts "   ✓ Consider batch processing in chunks of 1,000-10,000"

puts "\n=== BENCHMARK COMPLETE ==="