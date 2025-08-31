#!/usr/bin/env ruby

require_relative 'config/environment'
require 'benchmark'

# Test parameters for accuracy comparison
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

puts "=== RUBY ADVANCED vs PYTHON ACCURACY TEST ==="
puts "Testing with identical parameters to verify 100% accuracy match..."
puts

TEST_PARAMS.each { |k, v| puts "#{k}: #{v}" }
puts "=" * 60

begin
  # Test Ruby Advanced Service (our new Python-matching implementation)
  puts "1. Testing Ruby Advanced Service..."
  ruby_advanced_time = Benchmark.realtime do
    @ruby_advanced_calculator = MortgageCalculatorAdvancedService.new(TEST_PARAMS)
    @ruby_advanced_result = @ruby_advanced_calculator.calculate
  end
  puts "   ✅ Ruby Advanced completed in #{(ruby_advanced_time * 1000).round(2)}ms"

  # Test Python Integration Service (for comparison)
  puts "2. Testing Python Integration Service..."
  python_time = Benchmark.realtime do
    @python_calculator = PythonCalculatorService.new(TEST_PARAMS)
    @python_result = @python_calculator.calculate
  end
  puts "   ✅ Python Integration completed in #{(python_time * 1000).round(2)}ms"

  # Test Ruby Historical Service (simplified version)
  puts "3. Testing Ruby Historical Service (simplified)..."
  ruby_historical_time = Benchmark.realtime do
    @ruby_historical_calculator = MortgageCalculatorHistoricalService.new(TEST_PARAMS)
    @ruby_historical_result = @ruby_historical_calculator.calculate
  end
  puts "   ✅ Ruby Historical completed in #{(ruby_historical_time * 1000).round(2)}ms"

  puts "\n=== PERFORMANCE COMPARISON ==="
  puts "Ruby Advanced:    #{(ruby_advanced_time * 1000).round(2)}ms"
  puts "Python Integration: #{(python_time * 1000).round(2)}ms"
  puts "Ruby Historical:  #{(ruby_historical_time * 1000).round(2)}ms"
  puts
  puts "Speed ratios:"
  puts "  Ruby Advanced is #{(python_time/ruby_advanced_time).round(1)}x faster than Python"
  puts "  Ruby Advanced vs Ruby Historical: #{(ruby_advanced_time/ruby_historical_time).round(2)}x ratio"
  
  puts "\n=== ACCURACY COMPARISON ==="
  
  # Compare pathdf structure and key columns
  ruby_pathdf = @ruby_advanced_result[:pathdf]
  python_pathdf = @python_result[:pathdf] 
  historical_pathdf = @ruby_historical_result[:pathdf]
  
  puts "\nDataFrame Structure Comparison:"
  puts "Ruby Advanced columns (#{ruby_pathdf.keys.length}): #{ruby_pathdf.keys.sort}"
  puts "Python columns (#{python_pathdf.keys.length}): #{python_pathdf.keys.sort}"
  puts "Ruby Historical columns (#{historical_pathdf.keys.length}): #{historical_pathdf.keys.sort}"
  
  # Compare key metrics
  puts "\n=== KEY METRICS COMPARISON ==="
  
  if ruby_pathdf['Reinvestment'] && python_pathdf['Reinvestment']
    ruby_final_portfolio = ruby_pathdf['Reinvestment'].last
    python_final_portfolio = python_pathdf['Reinvestment'].last
    historical_final_portfolio = historical_pathdf['PortfolioValue']&.last
    
    puts "Final Portfolio Values:"
    puts "  Ruby Advanced:  $#{ruby_final_portfolio&.round(2)}"
    puts "  Python:         $#{python_final_portfolio&.round(2)}"
    puts "  Ruby Historical: $#{historical_final_portfolio&.round(2)}"
    
    if ruby_final_portfolio && python_final_portfolio
      difference = (ruby_final_portfolio - python_final_portfolio).abs
      percentage_diff = (difference / python_final_portfolio * 100).round(4)
      puts "  Difference: $#{difference.round(2)} (#{percentage_diff}%)"
      
      if percentage_diff < 0.01  # Less than 0.01% difference
        puts "  ✅ ACCURACY: EXCELLENT MATCH (<0.01% difference)"
      elsif percentage_diff < 1.0  # Less than 1% difference
        puts "  ⚠️  ACCURACY: GOOD MATCH (<1% difference)"
      else
        puts "  ❌ ACCURACY: SIGNIFICANT DIFFERENCE (>1%)"
      end
    end
  end
  
  # Compare holiday logic
  if ruby_pathdf['in_holiday'] && python_pathdf['in_holiday']
    ruby_holiday_periods = ruby_pathdf['in_holiday'].count(true)
    python_holiday_periods = python_pathdf['in_holiday'].count(true)
    
    puts "\nHoliday Periods:"
    puts "  Ruby Advanced: #{ruby_holiday_periods} periods in holiday"
    puts "  Python:        #{python_holiday_periods} periods in holiday"
    puts "  Match: #{ruby_holiday_periods == python_holiday_periods ? '✅ YES' : '❌ NO'}"
  end
  
  # Compare deferred amounts
  if ruby_pathdf['deferred'] && python_pathdf['deferred']
    ruby_final_deferred = ruby_pathdf['deferred'].last
    python_final_deferred = python_pathdf['deferred'].last
    
    puts "\nFinal Deferred Amount:"
    puts "  Ruby Advanced: $#{ruby_final_deferred&.round(2)}"
    puts "  Python:        $#{python_final_deferred&.round(2)}"
    
    if ruby_final_deferred && python_final_deferred
      deferred_match = (ruby_final_deferred - python_final_deferred).abs < 1.0
      puts "  Match: #{deferred_match ? '✅ YES' : '❌ NO'}"
    end
  end
  
  # Compare unit sales
  if ruby_pathdf['cummlative_units_sold'] && python_pathdf['cummlative_units_sold']
    ruby_units_sold = ruby_pathdf['cummlative_units_sold'].last
    python_units_sold = python_pathdf['cummlative_units_sold'].last
    
    puts "\nTotal Units Sold:"
    puts "  Ruby Advanced: #{ruby_units_sold&.round(6)} units"
    puts "  Python:        #{python_units_sold&.round(6)} units"
    
    if ruby_units_sold && python_units_sold
      units_match = (ruby_units_sold - python_units_sold).abs < 0.000001
      puts "  Match: #{units_match ? '✅ YES' : '❌ NO'}"
    end
  end

  # Price path comparison
  ruby_prices = @ruby_advanced_result[:price_paths][0][1] if @ruby_advanced_result[:price_paths]
  python_prices = @python_result[:price_paths][0][1] if @python_result[:price_paths]
  
  if ruby_prices && python_prices
    puts "\nPrice Path Comparison:"
    puts "  Ruby prices: #{ruby_prices.first.round(2)} → #{ruby_prices.last.round(2)} (#{ruby_prices.length} points)"
    puts "  Python prices: #{python_prices.first.round(2)} → #{python_prices.last.round(2)} (#{python_prices.length} points)"
    puts "  Identical: #{ruby_prices == python_prices ? '✅ YES' : '❌ NO'}"
  end

  puts "\n=== 100,000 CALCULATION PROJECTION ==="
  puts "For 100,000 calculations:"
  puts "  Ruby Advanced:     #{((ruby_advanced_time * 100000) / 60).round(1)} minutes"
  puts "  Python Integration: #{((python_time * 100000) / 3600).round(1)} hours"
  puts "  Ruby Historical:   #{((ruby_historical_time * 100000) / 60).round(1)} minutes"

  # Summary recommendation
  puts "\n=== RECOMMENDATION ==="
  if ruby_pathdf['Reinvestment'] && python_pathdf['Reinvestment']
    ruby_final = ruby_pathdf['Reinvestment'].last
    python_final = python_pathdf['Reinvestment'].last
    
    if ruby_final && python_final
      accuracy = ((ruby_final - python_final).abs / python_final * 100)
      speed_improvement = (python_time / ruby_advanced_time).round(1)
      
      if accuracy < 0.01
        puts "✅ Ruby Advanced Service achieves EXCELLENT accuracy match (<0.01% difference)"
        puts "✅ Performance improvement: #{speed_improvement}x faster than Python"
        puts "🚀 RECOMMENDATION: Use Ruby Advanced Service for production"
      elsif accuracy < 1.0
        puts "⚠️  Ruby Advanced Service achieves GOOD accuracy match (<1% difference)"
        puts "✅ Performance improvement: #{speed_improvement}x faster than Python"
        puts "📊 RECOMMENDATION: Ruby Advanced suitable for most use cases"
      else
        puts "❌ Ruby Advanced Service has significant accuracy differences"
        puts "🔧 RECOMMENDATION: Further refinement needed"
      end
    end
  end

rescue => e
  puts "❌ Error during testing: #{e.class}: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n=== TEST COMPLETE ==="