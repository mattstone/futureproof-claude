#!/usr/bin/env ruby
# frozen_string_literal: true

# Optimization Analysis - Find parameters that make the product profitable
# Target: Achieve 4% XIRR for funders with <20% insurance risk

require 'csv'
require_relative 'equity_preservation_mortgage'

puts "=" * 80
puts "EQUITY PRESERVATION MORTGAGE - OPTIMIZATION ANALYSIS"
puts "=" * 80
puts "\nGoal: Find parameters that achieve:"
puts "  • Funder returns ≥ 4% (risk-free rate)"
puts "  • Insurance risk < 20%"
puts "  • Product still attractive to borrowers"
puts "=" * 80

MONTE_CARLO_PATHS = 50
TARGET_CAGR = 4.0
TARGET_INSURANCE_RISK = 20.0

results = []

# Define test scenarios
# Each scenario tests a different combination of cost reductions
scenarios = [
  {
    name: "Baseline (Current)",
    lending_margin: 0.03,
    additional_margin: 0.01,
    insurance_cost_pa: 0.02,
    annual_income_pct: 0.015,
    holiday_enter: 0.9,
    holiday_exit: 1.4
  },
  {
    name: "Reduce Total Margins to 2%",
    lending_margin: 0.015,
    additional_margin: 0.005,
    insurance_cost_pa: 0.02,
    annual_income_pct: 0.015,
    holiday_enter: 0.9,
    holiday_exit: 1.4
  },
  {
    name: "Reduce Income to 1%",
    lending_margin: 0.03,
    additional_margin: 0.01,
    insurance_cost_pa: 0.02,
    annual_income_pct: 0.01,
    holiday_enter: 0.9,
    holiday_exit: 1.4
  },
  {
    name: "Reduce Insurance to 0.5%",
    lending_margin: 0.03,
    additional_margin: 0.01,
    insurance_cost_pa: 0.005,
    annual_income_pct: 0.015,
    holiday_enter: 0.9,
    holiday_exit: 1.4
  },
  {
    name: "No Payment Holidays",
    lending_margin: 0.03,
    additional_margin: 0.01,
    insurance_cost_pa: 0.02,
    annual_income_pct: 0.015,
    holiday_enter: 10.0,  # Impossible to enter
    holiday_exit: 10.0
  },
  {
    name: "Old Holiday Rules",
    lending_margin: 0.03,
    additional_margin: 0.01,
    insurance_cost_pa: 0.02,
    annual_income_pct: 0.015,
    holiday_enter: 1.35,
    holiday_exit: 1.95
  },
  {
    name: "Combined: Low Margins + Low Income",
    lending_margin: 0.015,
    additional_margin: 0.005,
    insurance_cost_pa: 0.02,
    annual_income_pct: 0.01,
    holiday_enter: 0.9,
    holiday_exit: 1.4
  },
  {
    name: "Combined: Low Margins + Low Insurance",
    lending_margin: 0.015,
    additional_margin: 0.005,
    insurance_cost_pa: 0.005,
    annual_income_pct: 0.015,
    holiday_enter: 0.9,
    holiday_exit: 1.4
  },
  {
    name: "Combined: Low Income + Low Insurance",
    lending_margin: 0.03,
    additional_margin: 0.01,
    insurance_cost_pa: 0.005,
    annual_income_pct: 0.01,
    holiday_enter: 0.9,
    holiday_exit: 1.4
  },
  {
    name: "Aggressive: All Low + No Holidays",
    lending_margin: 0.015,
    additional_margin: 0.005,
    insurance_cost_pa: 0.005,
    annual_income_pct: 0.01,
    holiday_enter: 10.0,
    holiday_exit: 10.0
  },
  {
    name: "Ultra-Aggressive: Minimal Everything",
    lending_margin: 0.01,
    additional_margin: 0.00,
    insurance_cost_pa: 0.005,
    annual_income_pct: 0.008,  # 0.8% of home value
    holiday_enter: 10.0,
    holiday_exit: 10.0
  },
  {
    name: "Zero Margins (Charity Model)",
    lending_margin: 0.00,
    additional_margin: 0.00,
    insurance_cost_pa: 0.00,
    annual_income_pct: 0.01,
    holiday_enter: 10.0,
    holiday_exit: 10.0
  }
]

scenarios.each_with_index do |scenario, idx|
  puts "\n#{idx + 1}/#{scenarios.length}: Testing #{scenario[:name]}"

  config = MortgageConfiguration.new
  config.lending_margin = scenario[:lending_margin]
  config.additional_margin = scenario[:additional_margin]
  config.insurance_cost_per_annum = scenario[:insurance_cost_pa]
  config.annual_income = config.house_value * scenario[:annual_income_pct]
  config.holiday_enter_fraction = scenario[:holiday_enter]
  config.holiday_exit_fraction = scenario[:holiday_exit]

  # Show parameter changes
  puts "  Lending margin: #{(scenario[:lending_margin] * 100).round(2)}%"
  puts "  Additional margin: #{(scenario[:additional_margin] * 100).round(2)}%"
  puts "  Total cost of funds: #{(config.total_cost_of_funds * 100).round(2)}%"
  puts "  Annual income: $#{config.annual_income.round(0)} (#{(scenario[:annual_income_pct] * 100).round(2)}%)"
  puts "  Insurance cost: #{(scenario[:insurance_cost_pa] * 100).round(2)}% pa"

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

  # Calculate funder return
  initial_investment = config.initial_investment
  final_recovery = mean_reinvestment
  simple_return = (final_recovery / initial_investment - 1)
  cagr = ((1 + simple_return) ** (1.0 / config.loan_duration_years) - 1) * 100

  # Calculate total cost drag
  total_cost_drag = config.total_cost_of_funds +
                   scenario[:insurance_cost_pa] +
                   (config.annual_income / config.total_loan)

  results << {
    name: scenario[:name],
    lending_margin: scenario[:lending_margin],
    additional_margin: scenario[:additional_margin],
    total_cost_of_funds: config.total_cost_of_funds,
    insurance_cost_pa: scenario[:insurance_cost_pa],
    annual_income: config.annual_income,
    annual_income_pct: scenario[:annual_income_pct],
    holiday_enter: scenario[:holiday_enter],
    holiday_exit: scenario[:holiday_exit],
    total_cost_drag: total_cost_drag,
    mean_reinvestment: mean_reinvestment,
    mean_deficit: mean_deficit,
    avg_holidays: avg_holidays,
    pct_quarters_on_holiday: (avg_holidays / config.total_quarters * 100),
    insurance_pct: insurance_pct,
    cagr: cagr,
    viable: (cagr >= TARGET_CAGR && insurance_pct <= TARGET_INSURANCE_RISK)
  }

  status = if results.last[:viable]
    "✅ VIABLE"
  elsif cagr >= TARGET_CAGR
    "⚠️  Good CAGR but high insurance"
  elsif insurance_pct <= TARGET_INSURANCE_RISK
    "⚠️  Low insurance but poor returns"
  else
    "❌ Not viable"
  end

  puts "  → CAGR: #{cagr.round(2)}% | Insurance: #{insurance_pct.round(1)}% | #{status}"
end

# Display results
puts "\n" + "=" * 80
puts "OPTIMIZATION RESULTS"
puts "=" * 80

# Sort by viability, then by CAGR
viable_results = results.select { |r| r[:viable] }
non_viable_results = results.reject { |r| r[:viable] }.sort_by { |r| -r[:cagr] }

if viable_results.any?
  puts "\n🎉 VIABLE SCENARIOS FOUND! (#{viable_results.length})\n"

  viable_results.each_with_index do |r, idx|
    puts "#{idx + 1}. #{r[:name]}"
    puts "   Total Cost of Funds: #{(r[:total_cost_of_funds] * 100).round(2)}%"
    puts "   Annual Income: $#{r[:annual_income].round(0)} (#{(r[:annual_income_pct] * 100).round(2)}%)"
    puts "   Insurance Cost: #{(r[:insurance_cost_pa] * 100).round(2)}% pa"
    puts "   Holidays: Enter #{(r[:holiday_enter] * 100).round(0)}% / Exit #{(r[:holiday_exit] * 100).round(0)}%"
    puts "   → CAGR: #{r[:cagr].round(2)}% ✅"
    puts "   → Insurance Risk: #{r[:insurance_pct].round(1)}% ✅"
    puts "   → Quarters on Holiday: #{r[:avg_holidays].round(1)}/80 (#{r[:pct_quarters_on_holiday].round(1)}%)"
    puts ""
  end
else
  puts "\n❌ NO FULLY VIABLE SCENARIOS FOUND\n"
  puts "Showing best attempts (sorted by CAGR):\n\n"

  non_viable_results.first(5).each_with_index do |r, idx|
    gap_to_target = TARGET_CAGR - r[:cagr]
    insurance_excess = r[:insurance_pct] - TARGET_INSURANCE_RISK

    puts "#{idx + 1}. #{r[:name]}"
    puts "   Total Cost of Funds: #{(r[:total_cost_of_funds] * 100).round(2)}%"
    puts "   Annual Income: $#{r[:annual_income].round(0)} (#{(r[:annual_income_pct] * 100).round(2)}%)"
    puts "   Insurance Cost: #{(r[:insurance_cost_pa] * 100).round(2)}% pa"
    puts "   Total Cost Drag: #{(r[:total_cost_drag] * 100).round(2)}%"
    puts "   → CAGR: #{r[:cagr].round(2)}% (gap: #{gap_to_target.round(2)}%)"
    puts "   → Insurance Risk: #{r[:insurance_pct].round(1)}% (excess: #{insurance_excess.round(1)}%)"
    puts "   → Quarters on Holiday: #{r[:avg_holidays].round(1)}/80"
    puts ""
  end
end

# Analysis
puts "=" * 80
puts "KEY INSIGHTS"
puts "=" * 80

# Find scenario with best CAGR and best insurance separately
best_cagr = results.max_by { |r| r[:cagr] }
best_insurance = results.min_by { |r| r[:insurance_pct] }

puts "\n📈 BEST CAGR: #{best_cagr[:cagr].round(2)}%"
puts "   Scenario: #{best_cagr[:name]}"
puts "   But insurance risk: #{best_cagr[:insurance_pct].round(1)}%"

puts "\n🛡️ LOWEST INSURANCE RISK: #{best_insurance[:insurance_pct].round(1)}%"
puts "   Scenario: #{best_insurance[:name]}"
puts "   But CAGR only: #{best_insurance[:cagr].round(2)}%"

# Cost analysis
puts "\n💰 COST STRUCTURE ANALYSIS:"
puts "   S&P 500 returns: 9.75% (with dividends)"
puts "   Risk-free rate: 4.0%"
puts "   Available spread: 5.75%"
puts ""

baseline = results.first
puts "   Baseline costs:"
puts "   • Lending margins: #{(baseline[:total_cost_of_funds] * 100).round(2)}%"
puts "   • Insurance: #{(baseline[:insurance_cost_pa] * 100).round(2)}%"
puts "   • Borrower income: #{(baseline[:annual_income_pct] * 100).round(2)}%"
puts "   • Total drag: #{(baseline[:total_cost_drag] * 100).round(2)}%"
puts ""
puts "   Problem: Total costs (#{(baseline[:total_cost_drag] * 100).round(2)}%) > Available spread (5.75%)"

# What would be needed
required_drag = 0.0575  # 5.75% available
puts "\n🎯 TO ACHIEVE VIABILITY:"
puts "   Maximum total cost drag: 5.75%"
puts "   Current baseline: #{(baseline[:total_cost_drag] * 100).round(2)}%"
puts "   Need to reduce by: #{((baseline[:total_cost_drag] - required_drag) * 100).round(2)}%"

puts "\n💡 RECOMMENDATIONS:"
if viable_results.any?
  puts "   ✅ Viable configurations found!"
  puts "   ✅ Implement: #{viable_results.first[:name]}"
else
  best = non_viable_results.first
  puts "   ❌ No viable configuration with current assumptions"
  puts "   ⚠️  Even best scenario falls short:"
  puts "      • CAGR: #{best[:cagr].round(2)}% (need 4.0%)"
  puts "      • Insurance: #{best[:insurance_pct].round(1)}% (need <20%)"
  puts ""
  puts "   Consider:"
  puts "   • Reduce borrower income below $#{best[:annual_income].round(0)}"
  puts "   • Eliminate all lending margins"
  puts "   • Subsidize insurance costs"
  puts "   • Alternative product structure entirely"
end

# Export to CSV
CSV.open("optimization_results.csv", "w") do |csv|
  csv << [ "Scenario", "Lending Margin %", "Additional Margin %", "Total CoF %",
          "Insurance Cost %", "Annual Income $", "Income %", "Total Cost Drag %",
          "Holidays Enter %", "Holidays Exit %", "Avg Holidays", "% Time Holiday",
          "Insurance Risk %", "CAGR %", "Viable?" ]

  results.sort_by { |r| -r[:cagr] }.each do |r|
    csv << [
      r[:name],
      (r[:lending_margin] * 100).round(2),
      (r[:additional_margin] * 100).round(2),
      (r[:total_cost_of_funds] * 100).round(2),
      (r[:insurance_cost_pa] * 100).round(2),
      r[:annual_income].round(0),
      (r[:annual_income_pct] * 100).round(2),
      (r[:total_cost_drag] * 100).round(2),
      (r[:holiday_enter] * 100).round(0),
      (r[:holiday_exit] * 100).round(0),
      r[:avg_holidays].round(1),
      r[:pct_quarters_on_holiday].round(1),
      r[:insurance_pct].round(1),
      r[:cagr].round(2),
      r[:viable] ? "YES" : "NO"
    ]
  end
end

puts "\n✅ Results exported to: optimization_results.csv"
puts "=" * 80
