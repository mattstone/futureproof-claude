#!/usr/bin/env ruby
# frozen_string_literal: true

# Equity Preservation Mortgage Model - Ruby Version
# Optimized for READABILITY over performance
#
# This model simulates a financial product where:
# 1. Borrower extracts equity from their home
# 2. Equity is invested in S&P 500
# 3. Borrower receives annuity income
# 4. Investment returns are used to pay interest and rebuild equity
# 5. Insurance covers shortfalls if market underperforms

require 'csv'
require 'json'

# =============================================================================
# CONFIGURATION - All assumptions clearly stated
# =============================================================================

class MortgageConfiguration
  attr_accessor :house_value, :loan_to_value, :loan_duration_years, :annuity_duration_years,
                :annual_income, :lending_margin, :additional_margin, :cash_rate,
                :insurance_cost_per_annum, :insurer_profit_margin, :equity_return, :volatility,
                :holiday_enter_fraction, :holiday_exit_fraction

  def initialize
    # House and Loan Parameters
    @house_value = 2_000_000              # Home value in dollars
    @loan_to_value = 0.80                 # 80% LTV - how much equity to extract
    @loan_duration_years = 20             # Years until loan must be repaid
    @annuity_duration_years = 20          # Years borrower receives income

    # Income to Borrower
    @annual_income = 30_000               # Annual income paid to borrower (1.5% of home value)

    # Interest Rate Components (total = cash_rate + margins)
    @cash_rate = 0.04                     # 4% risk-free rate
    @lending_margin = 0.01                # 1% wholesale lending margin (OPTIMIZED)
    @additional_margin = 0.00             # 0% additional FP margin (OPTIMIZED)

    # Insurance
    @insurance_cost_per_annum = 0.005     # 0.5% of loan amount per year (OPTIMIZED)
    @insurer_profit_margin = 0.5          # 50% profit margin on insurance

    # Investment Parameters (S&P 500)
    @equity_return = 0.1                  # 10% expected annual return
    @volatility = 0.12                    # 12% annual volatility

    # Payment Holiday Thresholds (DISABLED for optimal results)
    @holiday_enter_fraction = 10.0        # Impossible to enter holiday
    @holiday_exit_fraction = 10.0         # Impossible to exit holiday
  end

  # Calculated values
  def total_loan
    @house_value * @loan_to_value
  end

  def reinvest_fraction
    # What fraction of loan is invested (rest goes to annuity payments)
    1.0 - (@annuity_duration_years * @annual_income / total_loan)
  end

  def insurance_profit_margin_multiplier
    1.0 + @insurer_profit_margin
  end

  def initial_investment
    # CRITICAL: Initial investment must account for insurance cost (paid upfront, discounted to present value)
    insurance_pv = (@insurance_cost_per_annum * total_loan * @loan_duration_years) *
                   insurance_profit_margin_multiplier / ((1 + @cash_rate) ** @loan_duration_years)

    total_loan * reinvest_fraction - insurance_pv
  end

  def total_cost_of_funds
    @cash_rate + @lending_margin + @additional_margin
  end

  def quarterly_income
    @annual_income / 4.0
  end

  def total_quarters
    @loan_duration_years * 4
  end

  def to_s
    <<~TEXT
      ============================================================
      EQUITY PRESERVATION MORTGAGE - CONFIGURATION
      ============================================================

      HOUSE & LOAN:
        House Value:              $#{format_currency(house_value)}
        Loan-to-Value:            #{format_percent(loan_to_value)}
        Total Loan:               $#{format_currency(total_loan)}
        Loan Duration:            #{loan_duration_years} years (#{total_quarters} quarters)

      BORROWER INCOME:
        Annual Income:            $#{format_currency(annual_income)}
        Quarterly Income:         $#{format_currency(quarterly_income)}
        Annuity Duration:         #{annuity_duration_years} years
        Total Income Paid:        $#{format_currency(annual_income * annuity_duration_years)}

      INVESTMENT:
        Initial Investment:       $#{format_currency(initial_investment)}
        Reinvest Fraction:        #{format_percent(reinvest_fraction)}
        Expected Return:          #{format_percent(equity_return)} per year
        Volatility:               #{format_percent(volatility)} per year

      INTEREST RATES:
        Cash Rate:                #{format_percent(cash_rate)}
        Lending Margin:           #{format_percent(lending_margin)}
        Additional Margin:        #{format_percent(additional_margin)}
        Total Cost of Funds:      #{format_percent(total_cost_of_funds)}

      INSURANCE:
        Cost per Annum:           #{format_percent(insurance_cost_per_annum)} of loan
        Annual Cost:              $#{format_currency(total_loan * insurance_cost_per_annum)}
        Total Insurance Cost:     $#{format_currency(total_loan * insurance_cost_per_annum * loan_duration_years)}

      PAYMENT HOLIDAYS:
        Enter Holiday At:         #{format_percent(holiday_enter_fraction)} of loan
        Exit Holiday At:          #{format_percent(holiday_exit_fraction)} of loan

      ============================================================
    TEXT
  end

  private

  def format_currency(value)
    value.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def format_percent(value)
    "#{(value * 100).round(2)}%"
  end
end

# =============================================================================
# QUARTER - Represents one quarter of the loan
# =============================================================================

class Quarter
  attr_reader :period, :sp500_price, :sp500_units, :reinvestment_value,
              :interest_accrued, :interest_paid, :interest_deficit,
              :annuity_paid, :on_holiday, :funder_earned

  attr_accessor :cumulative_deficit

  def initialize(period:, sp500_price:, sp500_units:, reinvestment_value:,
                 interest_accrued:, interest_paid:, interest_deficit:,
                 annuity_paid:, on_holiday:, funder_earned:)
    @period = period
    @sp500_price = sp500_price
    @sp500_units = sp500_units
    @reinvestment_value = reinvestment_value
    @interest_accrued = interest_accrued
    @interest_paid = interest_paid
    @interest_deficit = interest_deficit
    @annuity_paid = annuity_paid
    @on_holiday = on_holiday
    @funder_earned = funder_earned
    @cumulative_deficit = 0
  end

  def to_h
    {
      period: @period,
      sp500_price: @sp500_price.round(2),
      sp500_units: @sp500_units.round(4),
      reinvestment_value: @reinvestment_value.round(2),
      interest_accrued: @interest_accrued.round(2),
      interest_paid: @interest_paid.round(2),
      interest_deficit: @interest_deficit.round(2),
      cumulative_deficit: @cumulative_deficit.round(2),
      annuity_paid: @annuity_paid.round(2),
      on_holiday: @on_holiday,
      funder_earned: @funder_earned.round(2)
    }
  end
end

# =============================================================================
# MONTE CARLO SIMULATION - Generate random S&P 500 price paths
# =============================================================================

class MonteCarloSimulation
  # Generate a single random S&P 500 price path using Geometric Brownian Motion
  #
  # Formula: S(t+1) = S(t) * exp((μ - σ²/2) * dt + σ * sqrt(dt) * Z)
  # Where:
  #   S(t) = price at time t
  #   μ = expected return (drift)
  #   σ = volatility
  #   dt = time step
  #   Z = random normal variable
  def self.generate_price_path(config:, seed: nil)
    Random.srand(seed) if seed

    starting_price = 100.0
    dt = 1.0 / 4.0  # Quarterly time step

    prices = [ starting_price ]

    (config.total_quarters - 1).times do
      current_price = prices.last

      # Random normal variable (Box-Muller transform)
      z = random_normal

      # Geometric Brownian Motion formula
      drift = (config.equity_return - 0.5 * config.volatility ** 2) * dt
      diffusion = config.volatility * Math.sqrt(dt) * z

      next_price = current_price * Math.exp(drift + diffusion)
      prices << next_price
    end

    prices
  end

  # Generate multiple price paths for Monte Carlo analysis
  def self.generate_multiple_paths(config:, num_paths:, seed: nil)
    Random.srand(seed) if seed

    paths = []
    num_paths.times do |i|
      paths << generate_price_path(config: config, seed: seed ? seed + i : nil)
    end
    paths
  end

  private

  # Box-Muller transform to generate normal random variable
  def self.random_normal
    u1 = rand
    u2 = rand
    Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
  end
end

# =============================================================================
# MORTGAGE SIMULATOR - Main simulation logic
# =============================================================================

class MortgageSimulator
  attr_reader :config, :price_path, :quarters

  def initialize(config:, price_path:)
    @config = config
    @price_path = price_path
    @quarters = []
  end

  def run_simulation
    # Initial state
    sp500_units = config.initial_investment / price_path.first
    on_holiday = false
    cumulative_deficit = 0.0

    puts "\nStarting simulation..."
    puts "Initial investment: $#{config.initial_investment.round(0)}"
    puts "Initial S&P500 price: $#{price_path.first.round(2)}"
    puts "Initial S&P500 units: #{sp500_units.round(4)}"
    puts ""

    # Simulate each quarter
    config.total_quarters.times do |period|
      quarter = simulate_quarter(
        period: period,
        sp500_price: price_path[period],
        sp500_units: sp500_units,
        on_holiday: on_holiday,
        cumulative_deficit: cumulative_deficit
      )

      quarters << quarter
      cumulative_deficit = quarter.cumulative_deficit

      # CRITICAL: Update units for next quarter (after sales)
      sp500_units = quarter.sp500_units

      # Check if we should enter/exit payment holiday
      on_holiday = update_holiday_status(quarter.reinvestment_value, on_holiday)

      # Progress update every year
      if (period + 1) % 4 == 0
        year = (period + 1) / 4
        puts "Year #{year}: Reinvestment = $#{quarter.reinvestment_value.round(0)}, " \
             "Units = #{quarter.sp500_units.round(2)}, Holiday = #{on_holiday}, Deficit = $#{quarter.cumulative_deficit.round(0)}"
      end
    end

    puts "\nSimulation complete!"
    self
  end

  private

  def simulate_quarter(period:, sp500_price:, sp500_units:, on_holiday:, cumulative_deficit:)
    # 1. Calculate current reinvestment value
    reinvestment_value = sp500_units * sp500_price

    # 2. Calculate quarterly interest accrued on loan
    quarterly_interest_rate = config.total_cost_of_funds / 4.0
    interest_accrued = config.total_loan * quarterly_interest_rate

    # 3. Determine if we pay annuity this quarter
    quarter_in_year = period % 4
    pays_annuity = period < (config.annuity_duration_years * 4)
    annuity_paid = pays_annuity ? config.quarterly_income : 0.0

    # 4. Calculate interest paid and units sold
    # CRITICAL: When not on holiday, we must SELL S&P 500 units to pay interest
    interest_paid = 0.0
    units_sold_this_quarter = 0.0
    new_sp500_units = sp500_units

    if on_holiday
      # On holiday: don't pay interest, don't sell units
      interest_paid = 0.0
      units_sold_this_quarter = 0.0
    else
      # Not on holiday: sell units to pay interest
      interest_paid = interest_accrued
      units_sold_this_quarter = interest_accrued / sp500_price
      new_sp500_units = sp500_units - units_sold_this_quarter
    end

    # 5. Calculate interest deficit (interest not paid)
    interest_deficit = interest_accrued - interest_paid
    cumulative_deficit += interest_deficit

    # 6. Calculate what funder earned this quarter
    funder_earned = interest_paid

    Quarter.new(
      period: period,
      sp500_price: sp500_price,
      sp500_units: new_sp500_units,  # UPDATED: Use new units after sale
      reinvestment_value: new_sp500_units * sp500_price,  # UPDATED: Calculate with new units
      interest_accrued: interest_accrued,
      interest_paid: interest_paid,
      interest_deficit: interest_deficit,
      annuity_paid: annuity_paid,
      on_holiday: on_holiday,
      funder_earned: funder_earned
    ).tap do |q|
      q.cumulative_deficit = cumulative_deficit
    end
  end

  def update_holiday_status(reinvestment_value, currently_on_holiday)
    # CRITICAL: Holiday thresholds based on initial_investment, NOT total_loan
    holiday_enter_threshold = config.initial_investment * config.holiday_enter_fraction
    holiday_exit_threshold = config.initial_investment * config.holiday_exit_fraction

    if currently_on_holiday
      # Exit holiday if reinvestment grows above exit threshold
      reinvestment_value >= holiday_exit_threshold ? false : true
    else
      # Enter holiday if reinvestment falls below enter threshold
      reinvestment_value <= holiday_enter_threshold ? true : false
    end
  end
end

# =============================================================================
# RESULTS ANALYZER - Calculate key metrics
# =============================================================================

class ResultsAnalyzer
  attr_reader :simulator

  def initialize(simulator)
    @simulator = simulator
  end

  def analyze
    final_quarter = simulator.quarters.last

    puts "\n" + "=" * 70
    puts "RESULTS ANALYSIS"
    puts "=" * 70

    # Borrower results
    total_income_received = simulator.quarters.sum(&:annuity_paid)
    quarters_on_holiday = simulator.quarters.count(&:on_holiday)
    pct_on_holiday = (quarters_on_holiday.to_f / simulator.config.total_quarters * 100).round(1)

    puts "\nBORROWER:"
    puts "  Total Income Received:    $#{format_currency(total_income_received)}"
    puts "  Quarters on Holiday:      #{quarters_on_holiday} / #{simulator.config.total_quarters} (#{pct_on_holiday}%)"

    # Investment results
    initial_investment = simulator.config.initial_investment
    final_reinvestment = final_quarter.reinvestment_value
    investment_return = ((final_reinvestment / initial_investment) - 1) * 100

    puts "\nINVESTMENT:"
    puts "  Initial Investment:       $#{format_currency(initial_investment)}"
    puts "  Final Reinvestment Value: $#{format_currency(final_reinvestment)}"
    puts "  Investment Return:        #{investment_return.round(1)}%"

    # Funder results
    total_interest_accrued = simulator.quarters.sum(&:interest_accrued)
    total_interest_paid = simulator.quarters.sum(&:interest_paid)
    total_funder_earned = simulator.quarters.sum(&:funder_earned)
    final_deficit = final_quarter.cumulative_deficit

    puts "\nFUNDER:"
    puts "  Total Interest Accrued:   $#{format_currency(total_interest_accrued)}"
    puts "  Total Interest Paid:      $#{format_currency(total_interest_paid)}"
    puts "  Total Funder Earned:      $#{format_currency(total_funder_earned)}"
    puts "  Final Interest Deficit:   $#{format_currency(final_deficit)}"

    # Final position
    total_loan = simulator.config.total_loan
    borrower_payments = total_income_received  # For interest-only loan
    amount_owed = total_loan + final_deficit
    amount_available = final_reinvestment + borrower_payments
    shortfall = [ amount_owed - amount_available, 0 ].max

    puts "\nFINAL POSITION:"
    puts "  Amount Owed:              $#{format_currency(amount_owed)}"
    puts "    (Loan + Deficit)        ($#{format_currency(total_loan)} + $#{format_currency(final_deficit)})"
    puts "  Amount Available:         $#{format_currency(amount_available)}"
    puts "    (Reinvestment + Payments) ($#{format_currency(final_reinvestment)} + $#{format_currency(borrower_payments)})"
    puts "  Insurance Payout Needed:  $#{format_currency(shortfall)}"

    if shortfall > 0
      puts "\n  ⚠️  INSURANCE REQUIRED - Borrower cannot repay loan"
    else
      surplus = amount_available - amount_owed
      puts "\n  ✅ NO INSURANCE NEEDED - Surplus: $#{format_currency(surplus)}"
    end

    # XIRR-like return (simplified)
    years = simulator.config.loan_duration_years
    final_recovery = final_reinvestment
    simple_return = (final_recovery / initial_investment - 1)
    cagr = ((1 + simple_return) ** (1.0 / years) - 1) * 100

    puts "\nFUNDER RETURNS:"
    puts "  Simple Return:            #{(simple_return * 100).round(2)}%"
    puts "  CAGR (approx):            #{cagr.round(2)}%"

    puts "\n" + "=" * 70
  end

  def export_to_csv(filename: 'simulation_results.csv')
    CSV.open(filename, 'w') do |csv|
      # Header
      csv << [ 'Period', 'Year', 'Quarter', 'SP500 Price', 'SP500 Units',
              'Reinvestment Value', 'Interest Accrued', 'Interest Paid',
              'Interest Deficit', 'Cumulative Deficit', 'Annuity Paid',
              'On Holiday', 'Funder Earned' ]

      # Data
      simulator.quarters.each do |q|
        year = (q.period / 4) + 1
        quarter = (q.period % 4) + 1

        csv << [
          q.period,
          year,
          quarter,
          q.sp500_price.round(2),
          q.sp500_units.round(4),
          q.reinvestment_value.round(2),
          q.interest_accrued.round(2),
          q.interest_paid.round(2),
          q.interest_deficit.round(2),
          q.cumulative_deficit.round(2),
          q.annuity_paid.round(2),
          q.on_holiday,
          q.funder_earned.round(2)
        ]
      end
    end

    puts "\nResults exported to: #{filename}"
  end

  private

  def format_currency(value)
    value.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end

# =============================================================================
# MAIN EXECUTION
# =============================================================================

if __FILE__ == $0
  puts "=" * 70
  puts "EQUITY PRESERVATION MORTGAGE SIMULATOR"
  puts "Ruby Version - Optimized for Readability"
  puts "=" * 70

  # 1. Configure the mortgage
  config = MortgageConfiguration.new
  puts config

  # Ask user: single path or Monte Carlo?
  puts "Choose simulation mode:"
  puts "  1. Single path (fast, shows ONE possible outcome)"
  puts "  2. Monte Carlo (slow, shows AVERAGE of many outcomes)"
  print "\nEnter choice (1 or 2, default=1): "

  choice = gets.chomp
  choice = "1" if choice.empty?

  if choice == "2"
    print "How many Monte Carlo paths? (default=100): "
    num_paths = gets.chomp
    num_paths = num_paths.empty? ? 100 : num_paths.to_i

    puts "\n⚠️  Running #{num_paths} simulations - this will take a while..."
    puts "=" * 70

    all_results = []

    num_paths.times do |i|
      price_path = MonteCarloSimulation.generate_price_path(config: config, seed: 42 + i)
      simulator = MortgageSimulator.new(config: config, price_path: price_path)
      simulator.run_simulation

      final_quarter = simulator.quarters.last
      all_results << {
        reinvestment: final_quarter.reinvestment_value,
        deficit: final_quarter.cumulative_deficit,
        total_income: simulator.quarters.sum(&:annuity_paid),
        quarters_on_holiday: simulator.quarters.count(&:on_holiday)
      }

      if (i + 1) % 10 == 0
        puts "Completed #{i + 1}/#{num_paths} simulations..."
      end
    end

    puts "\n" + "=" * 70
    puts "MONTE CARLO RESULTS (#{num_paths} paths)"
    puts "=" * 70

    reinvestments = all_results.map { |r| r[:reinvestment] }
    deficits = all_results.map { |r| r[:deficit] }

    total_loan = config.total_loan
    total_income = all_results.first[:total_income]

    insurance_needed = all_results.count do |r|
      r[:reinvestment] + total_income < total_loan + r[:deficit]
    end

    mean_reinvestment = reinvestments.sum / reinvestments.size
    sorted = reinvestments.sort
    p10 = sorted[(reinvestments.size * 0.1).floor]
    p50 = sorted[(reinvestments.size * 0.5).floor]
    p90 = sorted[(reinvestments.size * 0.9).floor]

    puts "\nFINAL REINVESTMENT VALUE:"
    puts "  Mean:             $#{mean_reinvestment.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  10th percentile:  $#{p10.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  50th percentile:  $#{p50.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  90th percentile:  $#{p90.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

    mean_deficit = deficits.sum / deficits.size
    puts "\nFINAL INTEREST DEFICIT:"
    puts "  Mean:             $#{mean_deficit.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

    insurance_pct = (insurance_needed.to_f / num_paths * 100).round(1)
    puts "\nINSURANCE REQUIRED:"
    puts "  Scenarios needing insurance: #{insurance_needed} / #{num_paths} (#{insurance_pct}%)"

    avg_holidays = all_results.map { |r| r[:quarters_on_holiday] }.sum / all_results.size.to_f
    puts "\nPAYMENT HOLIDAYS:"
    puts "  Average quarters on holiday: #{avg_holidays.round(1)} / #{config.total_quarters}"

    puts "\n⚠️  IMPORTANT: This shows the AVERAGE outcome, not a single lucky path!"
    puts "=" * 70

  else
    # 2. Generate S&P 500 price path
    puts "\n⚠️  SINGLE PATH MODE - This shows ONE possible outcome (could be lucky or unlucky)"
    puts "For realistic assessment, run Monte Carlo mode (option 2)"
    puts "\nGenerating S&P 500 price path (Monte Carlo simulation)..."
    price_path = MonteCarloSimulation.generate_price_path(config: config, seed: 42)

    # 3. Run simulation
    simulator = MortgageSimulator.new(config: config, price_path: price_path)
    simulator.run_simulation

    # 4. Analyze results
    analyzer = ResultsAnalyzer.new(simulator)
    analyzer.analyze
    analyzer.export_to_csv

    puts "\n✅ Complete! Review simulation_results.csv for detailed quarter-by-quarter data."
    puts "\n⚠️  REMINDER: This is just ONE scenario. Run Monte Carlo mode to see the full picture!"
  end
end
