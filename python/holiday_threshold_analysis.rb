#!/usr/bin/env ruby
# frozen_string_literal: true

# Holiday Threshold Sensitivity Analysis
# Tests different enter/exit thresholds to find optimal balance

require 'csv'
require_relative 'equity_preservation_mortgage'

puts "=" * 80
puts "PAYMENT HOLIDAY THRESHOLD SENSITIVITY ANALYSIS"
puts "=" * 80
puts "\nTesting different combinations of holiday enter/exit thresholds"
puts "to find settings that make the product viable for funders.\n"
puts "=" * 80

# Test scenarios
# Format: [enter_fraction, exit_fraction, description]
scenarios = [
  [0.9, 1.4, "Current (Easy enter, Easy exit)"],
  [0.95, 1.3, "Moderate (Medium enter, Medium exit)"],
  [1.0, 1.2, "Strict (Hard enter, Easy exit)"],
  [1.1, 1.3, "Very Strict (Very hard enter, Medium exit)"],
  [1.2, 1.4, "Extremely Strict (Extremely hard enter, Easy exit)"],
  [0.8, 1.5, "Very Borrower Friendly (Very easy enter, Hard exit)"],
  [1.35, 1.95, "Old Version (Original parameters)"]
]

MONTE_CARLO_PATHS = 50  # Reduced for speed
results = []

scenarios.each_with_index do |(enter_frac, exit_frac, description), idx|
  puts "\n#{idx + 1}/#{scenarios.length}: Testing #{description}"
  puts "  Enter threshold: #{(enter_frac * 100).round(0)}% | Exit threshold: #{(exit_frac * 100).round(0)}%"

  # Configure mortgage with these thresholds
  config = MortgageConfiguration.new
  config.holiday_enter_fraction = enter_frac
  config.holiday_exit_fraction = exit_frac

  # Run Monte Carlo
  all_path_results = []

  MONTE_CARLO_PATHS.times do |i|
    price_path = MonteCarloSimulation.generate_price_path(config: config, seed: 42 + i)
    simulator = MortgageSimulator.new(config: config, price_path: price_path)
    simulator.run_simulation

    final_quarter = simulator.quarters.last
    all_path_results << {
      reinvestment: final_quarter.reinvestment_value,
      deficit: final_quarter.cumulative_deficit,
      total_income: simulator.quarters.sum(&:annuity_paid),
      quarters_on_holiday: simulator.quarters.count(&:on_holiday)
    }
  end

  # Calculate metrics
  reinvestments = all_path_results.map { |r| r[:reinvestment] }
  deficits = all_path_results.map { |r| r[:deficit] }

  total_loan = config.total_loan
  total_income = all_path_results.first[:total_income]

  insurance_needed = all_path_results.count do |r|
    r[:reinvestment] + total_income < total_loan + r[:deficit]
  end

  mean_reinvestment = reinvestments.sum / reinvestments.size
  mean_deficit = deficits.sum / deficits.size
  avg_holidays = all_path_results.map { |r| r[:quarters_on_holiday] }.sum / all_path_results.size.to_f
  insurance_pct = (insurance_needed.to_f / MONTE_CARLO_PATHS * 100)

  # Calculate funder return (simplified)
  initial_investment = config.initial_investment
  final_recovery = mean_reinvestment  # Simplified - not including profit share
  simple_return = (final_recovery / initial_investment - 1)
  cagr = ((1 + simple_return) ** (1.0 / config.loan_duration_years) - 1) * 100

  results << {
    description: description,
    enter_frac: enter_frac,
    exit_frac: exit_frac,
    mean_reinvestment: mean_reinvestment,
    mean_deficit: mean_deficit,
    avg_holidays: avg_holidays,
    pct_quarters_on_holiday: (avg_holidays / config.total_quarters * 100),
    insurance_pct: insurance_pct,
    cagr: cagr
  }

  puts "  ✓ Avg holidays: #{avg_holidays.round(1)}/80 (#{(avg_holidays/80*100).round(1)}%)"
  puts "  ✓ Insurance needed: #{insurance_pct.round(1)}%"
  puts "  ✓ Funder CAGR (approx): #{cagr.round(2)}%"
end

# Display results
puts "\n" + "=" * 80
puts "RESULTS SUMMARY"
puts "=" * 80

# Sort by insurance percentage (ascending - lower is better)
sorted_results = results.sort_by { |r| r[:insurance_pct] }

puts "\n📊 Ranked by Insurance Risk (Lower is Better):\n\n"

sorted_results.each_with_index do |r, idx|
  marker = idx == 0 ? "🏆" : "  "
  puts "#{marker} #{idx + 1}. #{r[:description]}"
  puts "     Enter: #{(r[:enter_frac] * 100).round(0)}% | Exit: #{(r[:exit_frac] * 100).round(0)}%"
  puts "     Quarters on Holiday: #{r[:avg_holidays].round(1)}/80 (#{r[:pct_quarters_on_holiday].round(1)}%)"
  puts "     Insurance Required: #{r[:insurance_pct].round(1)}% of scenarios"
  puts "     Mean Deficit: $#{r[:mean_deficit].round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  puts "     Funder CAGR: #{r[:cagr].round(2)}%"
  puts ""
end

# Key insights
puts "=" * 80
puts "KEY INSIGHTS"
puts "=" * 80

best = sorted_results.first
worst = sorted_results.last

puts "\n🏆 BEST SCENARIO: #{best[:description]}"
puts "   Enter: #{(best[:enter_frac] * 100).round(0)}% | Exit: #{(best[:exit_frac] * 100).round(0)}%"
puts "   Insurance: #{best[:insurance_pct].round(1)}% | Holidays: #{best[:pct_quarters_on_holiday].round(1)}%"
puts "   CAGR: #{best[:cagr].round(2)}%"

puts "\n❌ WORST SCENARIO: #{worst[:description]}"
puts "   Enter: #{(worst[:enter_frac] * 100).round(0)}% | Exit: #{(worst[:exit_frac] * 100).round(0)}%"
puts "   Insurance: #{worst[:insurance_pct].round(1)}% | Holidays: #{worst[:pct_quarters_on_holiday].round(1)}%"
puts "   CAGR: #{worst[:cagr].round(2)}%"

puts "\n💡 RECOMMENDATIONS:"

if best[:insurance_pct] < 50
  puts "   ✅ The best scenario (#{best[:description]}) shows viable results!"
  puts "   ✅ Insurance needed in only #{best[:insurance_pct].round(1)}% of cases"
  puts "   ✅ Funder CAGR of #{best[:cagr].round(2)}% may be acceptable"
elsif best[:insurance_pct] < 70
  puts "   ⚠️  Even the best scenario requires insurance in #{best[:insurance_pct].round(1)}% of cases"
  puts "   ⚠️  Marginal viability - would need very cheap insurance"
else
  puts "   ❌ Even with optimal thresholds, insurance is required in #{best[:insurance_pct].round(1)}% of cases"
  puts "   ❌ Product remains fundamentally unprofitable"
  puts "   ❌ Consider alternative product structures"
end

puts "\n📈 THRESHOLD PATTERNS:"
correlation = results.map { |r| [r[:enter_frac], r[:insurance_pct]] }
high_enter = correlation.select { |e, _| e >= 1.1 }.map { |_, i| i }.sum / [correlation.select { |e, _| e >= 1.1 }.count, 1].max
low_enter = correlation.select { |e, _| e < 1.0 }.map { |_, i| i }.sum / [correlation.select { |e, _| e < 1.0 }.count, 1].max

puts "   • Higher enter threshold (harder to enter holiday) = #{high_enter.round(1)}% avg insurance"
puts "   • Lower enter threshold (easier to enter holiday) = #{low_enter.round(1)}% avg insurance"
puts "   • Difference: #{(low_enter - high_enter).round(1)} percentage points"

if high_enter < low_enter
  improvement = ((low_enter - high_enter) / low_enter * 100).round(1)
  puts "\n   💡 Making it HARDER to enter holiday reduces insurance risk by #{improvement}%"
  puts "   💡 Best enter threshold: #{best[:enter_frac]} (#{(best[:enter_frac] * 100).round(0)}%)"
else
  puts "\n   ⚠️  Surprisingly, enter threshold doesn't significantly affect insurance risk"
end

puts "\n" + "=" * 80

# Export to CSV
CSV.open("holiday_threshold_results.csv", "w") do |csv|
  csv << ["Description", "Enter %", "Exit %", "Avg Quarters on Holiday", "% Time on Holiday",
          "Insurance Required %", "Mean Deficit", "Funder CAGR %"]

  sorted_results.each do |r|
    csv << [
      r[:description],
      (r[:enter_frac] * 100).round(1),
      (r[:exit_frac] * 100).round(1),
      r[:avg_holidays].round(1),
      r[:pct_quarters_on_holiday].round(1),
      r[:insurance_pct].round(1),
      r[:mean_deficit].round(0),
      r[:cagr].round(2)
    ]
  end
end

puts "\n✅ Results exported to: holiday_threshold_results.csv"
puts "=" * 80
