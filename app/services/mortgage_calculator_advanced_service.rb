require 'csv'

class MortgageCalculatorAdvancedService
  def initialize(params)
    @params = params.is_a?(ActionController::Parameters) ? params : params.with_indifferent_access
    set_default_values
    load_historical_data
    validate_params
  end

  def calculate
    Rails.logger.info "=== ADVANCED MORTGAGE CALCULATOR (MONTE CARLO) ==="
    Rails.logger.info "Using Monte Carlo simulation with complex quarterly logic"
    Rails.logger.info "Paths: #{@params[:total_paths] || 1000}, Equity return: #{(@params[:equity_return] || 0.108)*100}%, Volatility: #{(@params[:volatility] || 0.15)*100}%"
    
    # Generate Monte Carlo price paths
    price_paths = generate_monte_carlo_paths
    s0 = 100.0  # Starting price for Monte Carlo
    
    # Use cash rate for interest calculations
    interest_rate = @params[:cash_rate] || 0.04
    
    # Process each Monte Carlo path individually (like Python implementation)
    all_results = []
    combined_pathdf = {}
    
    Rails.logger.info "Processing #{price_paths.length} Monte Carlo paths..."
    
    price_paths.each_with_index do |(path_id, price_path), index|
      # Process single path
      single_path_data = [[path_id, price_path]]
      
      path_result = single_mortgage_advanced(
        @total_loan, @reinvest_fraction, @params[:loan_duration], @params[:annual_income], 
        @params[:annuity_duration], @insurance_profit_margin, @insurance_cost,
        interest_rate, @params[:wholesale_lending_margin], @params[:additional_loan_margins],
        @params[:holiday_enter_fraction], @params[:holiday_exit_fraction], 
        @params[:subperform_loan_threshold_quarters], single_path_data, s0, 1.0/120.0,
        @params[:start_year] - 1, 1.0, 1.0, false, 0, nil, 
        @params[:loan_type] != "Interest only", @params[:hedged], 
        @params[:hedging_max_loss], @params[:hedging_cap], @params[:hedging_cost_pa]
      )
      
      # Extract pathdf from single path result
      single_pathdf = path_result[:pathdf] || path_result
      all_results << single_pathdf
      
      # Combine all paths into single pathdf structure
      if combined_pathdf.empty?
        # Initialize with first path
        single_pathdf.each do |key, values|
          combined_pathdf[key] = values.dup
        end
      else
        # Append subsequent paths
        single_pathdf.each do |key, values|
          combined_pathdf[key] ||= []
          combined_pathdf[key].concat(values)
        end
      end
      
      if index % 100 == 0
        Rails.logger.info "Processed #{index + 1}/#{price_paths.length} paths"
      end
    end
    
    result = { pathdf: combined_pathdf }
    
    Rails.logger.info "Advanced calculation completed"
    
    # Extract pathdf from result (single_mortgage_advanced returns a nested structure)
    pathdf = result[:pathdf] || result
    
    # Format result to match expected structure for UI
    {
      main_outputs: generate_main_outputs(pathdf),
      path_data: generate_path_data(pathdf),
      total_paths: @params[:total_paths] || 1000,
      chart_data: generate_chart_data(pathdf, price_paths),
      data_source: 'ruby_advanced_monte_carlo',
      pathdf: pathdf,
      price_paths: price_paths,
      sp500df: format_sp500df,
      accounts_table: generate_accounts_table(pathdf),
      debug_msgs: {
        insurance_cost: @insurance_cost,
        interest: interest_rate,
        monte_carlo: {
          paths: price_paths.length,
          equity_return: @params[:equity_return],
          volatility: @params[:volatility]
        }
      }
    }
  end

  private

  def generate_monte_carlo_paths
    # Set random seed for reproducible results
    srand(@params[:random_seed]) if @params[:random_seed]
    
    dt = 1.0 / 120.0  # Monthly time step (matches Python)
    n_steps = (@params[:loan_duration] / dt).round
    total_paths = @params[:total_paths] || 1000
    s0 = 100.0
    equity_return = @params[:equity_return] || 0.108
    volatility = @params[:volatility] || 0.15
    
    Rails.logger.info "Generating #{total_paths} Monte Carlo paths with #{n_steps} steps"
    Rails.logger.info "Parameters: S0=#{s0}, μ=#{equity_return}, σ=#{volatility}, dt=#{dt}"
    
    paths = []
    
    (0...total_paths).each do |path_idx|
      # Generate geometric Brownian motion path
      price_path = [s0]
      current_price = s0
      
      (1...n_steps).each do |step|
        # Standard Brownian motion increment
        dW = Math.sqrt(dt) * random_normal
        
        # Geometric Brownian motion formula: dS = μ*S*dt + σ*S*dW
        drift = equity_return * current_price * dt
        diffusion = volatility * current_price * dW
        
        current_price = current_price + drift + diffusion
        current_price = [current_price, 0.01].max  # Prevent negative prices
        
        price_path << current_price
      end
      
      paths << [path_idx, price_path]
    end
    
    Rails.logger.info "Generated #{paths.length} paths, sample final prices: #{paths[0..4].map { |p| p[1].last.round(2) }}"
    paths
  end

  def random_normal
    # Box-Muller transformation to generate standard normal random variables
    @spare_random ||= nil
    
    if @spare_random
      result = @spare_random
      @spare_random = nil
      return result
    end
    
    u = rand
    v = rand
    
    while u <= Float::EPSILON
      u = rand
    end
    
    mag = Math.sqrt(-2.0 * Math.log(u))
    @spare_random = mag * Math.cos(2.0 * Math::PI * v)
    
    mag * Math.sin(2.0 * Math::PI * v)
  end

  def set_default_values
    # Match Python defaults exactly
    @params[:house_value] = @params[:house_value].present? ? @params[:house_value].to_f : 1500000.0
    @params[:loan_duration] = @params[:loan_duration].present? ? @params[:loan_duration].to_i : 30
    @params[:annuity_duration] = @params[:annuity_duration].present? ? @params[:annuity_duration].to_i : 15
    @params[:loan_type] = @params[:loan_type].present? ? @params[:loan_type] : "Interest only"
    @params[:loan_to_value] = @params[:loan_to_value].present? ? @params[:loan_to_value].to_f : 0.8
    @params[:annual_income] = @params[:annual_income].present? ? @params[:annual_income].to_f : 30000.0
    @params[:at_risk_capital_fraction] = @params[:at_risk_capital_fraction].present? ? @params[:at_risk_capital_fraction].to_f : 0.0
    @params[:annual_house_price_appreciation] = @params[:annual_house_price_appreciation].present? ? @params[:annual_house_price_appreciation].to_f : 0.04
    @params[:insurer_profit_margin] = @params[:insurer_profit_margin].present? ? @params[:insurer_profit_margin].to_f : 0.5
    @params[:wholesale_lending_margin] = @params[:wholesale_lending_margin].present? ? @params[:wholesale_lending_margin].to_f : 0.02
    @params[:additional_loan_margins] = @params[:additional_loan_margins].present? ? @params[:additional_loan_margins].to_f : 0.015
    @params[:holiday_enter_fraction] = @params[:holiday_enter_fraction].present? ? @params[:holiday_enter_fraction].to_f : 1.35
    @params[:holiday_exit_fraction] = @params[:holiday_exit_fraction].present? ? @params[:holiday_exit_fraction].to_f : 1.95
    @params[:subperform_loan_threshold_quarters] = @params[:subperform_loan_threshold_quarters].present? ? @params[:subperform_loan_threshold_quarters].to_i : 6
    @params[:insurance_cost_pa] = @params[:insurance_cost_pa].present? ? @params[:insurance_cost_pa].to_f : 0.02
    @params[:start_year] = @params[:start_year].present? ? @params[:start_year].to_i : 2000
    @params[:hedged] = @params[:hedged].present? ? @params[:hedged] : false
    @params[:hedging_max_loss] = @params[:hedging_max_loss].present? ? @params[:hedging_max_loss].to_f : 0.1
    @params[:hedging_cap] = @params[:hedging_cap].present? ? @params[:hedging_cap].to_f : 0.2
    @params[:hedging_cost_pa] = @params[:hedging_cost_pa].present? ? @params[:hedging_cost_pa].to_f : 0.01
    
    # Monte Carlo parameters
    @params[:equity_return] = @params[:equity_return].present? ? @params[:equity_return].to_f : 0.108
    @params[:volatility] = @params[:volatility].present? ? @params[:volatility].to_f : 0.15
    @params[:total_paths] = @params[:total_paths].present? ? @params[:total_paths].to_i : 1000
    @params[:random_seed] = @params[:random_seed].present? ? @params[:random_seed].to_i : 42
    @params[:cash_rate] = @params[:cash_rate].present? ? @params[:cash_rate].to_f : 0.04
    
    # Calculate derived values
    @total_loan = @params[:house_value] * @params[:loan_to_value]
    @reinvest_fraction = 1.0 - (@params[:annuity_duration] * @params[:annual_income]) / @total_loan
    @insurance_profit_margin = 1.0 + @params[:insurer_profit_margin]
    @insurance_cost = @params[:insurance_cost_pa] * @total_loan * @params[:loan_duration]
  end

  def load_historical_data
    # Load S&P 500 data (must be CSV with Date and AdjClose columns)
    sp500_path = Rails.root.join('python', 'sp500tr.csv')
    @sp500_data = []
    CSV.foreach(sp500_path, headers: true) do |row|
      @sp500_data << {
        date: row['Date'],
        adj_close: row['AdjClose'].gsub(',', '').to_f
      }
    end
    
    # Load Federal Funds data (must be CSV with DATE and FEDFUNDS columns)
    fedfunds_path = Rails.root.join('python', 'FEDFUNDS2.csv')
    @fedfunds_data = []
    CSV.foreach(fedfunds_path, headers: true) do |row|
      @fedfunds_data << {
        date: row['DATE'],
        rate: row['FEDFUNDS'].to_f / 100.0  # Convert percentage to decimal
      }
    end
    
    Rails.logger.info "Loaded #{@sp500_data.length} S&P 500 data points"
    Rails.logger.info "Loaded #{@fedfunds_data.length} Fed Funds data points"
  end

  def extract_historical_paths
    # Python logic: reverse SP500 prices and calculate start offset
    sp_prices = @sp500_data.map { |d| d[:adj_close] }.reverse
    all_interest_series = @fedfunds_data.map { |d| d[:rate] }
    
    # Calculate start offset like Python
    start_offset = (@params[:start_year] - 1988) * 12
    required_months = @params[:loan_duration] * 12
    
    # Ensure we have enough data
    max_available_months = sp_prices.length
    max_interest_months = all_interest_series.length
    
    if start_offset + required_months > max_available_months
      start_offset = [0, max_available_months - required_months].max
    end
    
    if start_offset + required_months > max_interest_months
      start_offset = [0, max_interest_months - required_months].max
    end
    
    start_offset = [0, start_offset].max
    
    # Extract price path and interest series
    price_path = sp_prices[start_offset, required_months] || []
    interest_series = all_interest_series[start_offset, required_months] || []
    
    # Fallback if no data
    if price_path.empty?
      price_path = [100.0] * required_months
    end
    if interest_series.empty?
      interest_series = [0.04] * required_months
    end
    
    Rails.logger.info "Price path starts at: #{price_path.first}, ends at: #{price_path.last}"
    Rails.logger.info "Interest series starts at: #{interest_series.first}, ends at: #{interest_series.last}"
    
    [price_path, interest_series]
  end

  # Python's single_mortgage function translated to Ruby with EXACT same logic
  def single_mortgage_advanced(total_loan, reinvest_fraction, loan_duration, annual_income, 
                               annuity_duration, insurance_profit_margin, insurance_cost,
                               cash_rate_series, wholesale_lending_margin, additional_loan_margins,
                               holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                               price_path, s0, dt, year_offset = 0, max_superpay_factor = 1.0, 
                               superpay_start_factor = 1.0, enable_pool = false, insured_units = 0, 
                               expected_reinvestment_ratio = nil, pi_progressive_repayment = false, 
                               hedged = false, hedging_max_loss = 0, hedging_cap = 1000, hedging_cost_pa = 0)

    # Pre-calculate constants exactly like Python
    is_cash_rate_list = cash_rate_series.is_a?(Array)
    
    # Calculate average cash rate (geometric mean for arrays) - MATCHING PYTHON BUG EXACTLY
    if is_cash_rate_list
      # Python bug: geometric_mean(cash_rate_series) instead of geometric_mean([1+r for r in rates]) - 1
      # Use logarithmic method to avoid underflow (Ruby direct multiplication fails)
      n = cash_rate_series.length.to_f
      avg_cash_rate = Math.exp(cash_rate_series.map { |x| Math.log(x) }.sum / n)
    else
      avg_cash_rate = cash_rate_series
    end
    
    # Initial reinvestment calculation EXACTLY like Python
    initial_reinvestment = total_loan * reinvest_fraction - 
      insurance_profit_margin * insurance_cost / ((1 + avg_cash_rate) ** loan_duration)
    
    Rails.logger.info "DEBUG: initial_reinvestment = #{initial_reinvestment.round(2)}"
    
    expected_reinvestment = nil
    if expected_reinvestment_ratio
      expected_reinvestment = expected_reinvestment_ratio * initial_reinvestment
    end
    
    holiday_enter = initial_reinvestment * holiday_enter_fraction
    holiday_exit = initial_reinvestment * holiday_exit_fraction
    
    # Pre-calculate constants matching Python exactly
    quarter_div = 0.25  # Quarterly division
    dt_quarter_inv = 1.0 / (dt * 4)  # For price indexing
    annual_income_quarter = annual_income * quarter_div  # Quarterly annuity income
    annuity_duration_quarters = (annuity_duration * 4).to_i
    total_periods = (4 * loan_duration + 1).to_i  # QUARTERLY periods, not monthly!
    
    all_data = []
    
    # Process for single path (path 0)
    pathn = 0
    
    # Initialize state variables exactly like Python
    holdings = initial_reinvestment / s0  # Number of units
    cummlative_units_sold = 0.0
    init_units_to_principal = 0.0
    loan_size = total_loan * reinvest_fraction + annual_income_quarter  # Include Y1 income
    
    if pi_progressive_repayment
      init_units_to_principal = annual_income_quarter / s0
      loan_size -= annual_income_quarter
      holdings -= init_units_to_principal
    end
    
    in_holiday = holiday_enter_fraction > 1  # Initial holiday state
    holiday_quarters = 0
    cum_units_to_pool = 0.0
    cum_interest_paid = 0.0
    deferred = 0.0
    funder_earned = 0.0
    
    # Initialize first row exactly like Python (row 0)
    holdings_s0 = holdings * s0
    first_row = [
      pathn, 0, year_offset, 0, s0, 0, (total_loan * reinvest_fraction).round, 
      holdings, holdings_s0.round, 0.round, 
      [loan_size - holdings_s0, 0].max.round, 
      (holdings_s0 - loan_size - deferred).round,
      in_holiday, 0, annual_income_quarter, 0, false, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
      init_units_to_principal, 0, 0
    ]
    all_data << first_row
    
    last_yearly_hedge_price = s0
    last_5yearly_hedge_price = s0
    
    # Pre-calculate price indices and rates for vectorized access like Python
    if is_cash_rate_list
      # Calculate quarterly indices (Python uses dt_quarter_inv)
      price_indices = (1...total_periods).map { |t| ((t * dt_quarter_inv) - 1).to_i }
      cash_rates = price_indices.map { |idx| cash_rate_series[idx] || 0.04 }
      prices = price_indices.map { |idx| price_path[idx] || price_path[-1] }
    else
      cash_rates = Array.new(total_periods - 1, cash_rate_series)
      price_indices = (1...total_periods).map { |t| ((t * dt_quarter_inv) - 1).to_i }
      prices = price_indices.map { |idx| price_path[idx] || price_path[-1] }
    end
    
    # Pre-calculate loan interest rates
    loan_interest_rates = cash_rates.map { |rate| rate + wholesale_lending_margin + additional_loan_margins }
    
    # Main quarterly loop (periods 1 to total_periods-1)
    (1...total_periods).each_with_index do |t, i|
      s = prices[i]
      cash_rate = cash_rates[i]
      loan_interest_rate = loan_interest_rates[i]
      interest_due = loan_size * loan_interest_rate * quarter_div
      
      # Initialize variables for this quarter
      interest_paid = 0.0
      interest_paid_to_funder = 0.0
      deferred_delta = 0.0
      units_sold_now = 0.0
      units_to_pool = 0.0
      units_to_principal = 0.0
      
      # Pre-calculate common values
      interest_due_per_share = interest_due / s
      holdings_value = holdings * s
      
      # EXACT Python holiday logic
      if in_holiday
        if holdings_value > holiday_exit
          in_holiday = false
          if enable_pool && holdings <= insured_units
            units_to_pool -= interest_due_per_share
          else
            holdings -= interest_due_per_share
            units_sold_now += interest_due_per_share
          end
          interest_paid = interest_due
          interest_paid_to_funder = loan_size * (wholesale_lending_margin + cash_rate) * quarter_div
          holiday_quarters = 0
        else
          if enable_pool && holdings <= insured_units
            units_to_pool -= interest_due_per_share
          else
            holiday_quarters += 1
            deferred += interest_due
            deferred_delta += interest_due
          end
        end
      else
        if holdings_value < holiday_enter
          if enable_pool && holdings <= insured_units
            units_to_pool -= interest_due_per_share
          else
            deferred += interest_due
            deferred_delta += interest_due
            in_holiday = true
            holiday_quarters += 1
          end
        else
          holiday_quarters = 0
          if enable_pool && holdings <= insured_units
            units_to_pool -= interest_due_per_share
          else
            holdings -= interest_due_per_share
            units_sold_now += interest_due_per_share
          end
          interest_paid = interest_due
          interest_paid_to_funder = loan_size * (wholesale_lending_margin + cash_rate) * quarter_div
          
          if holdings_value > holiday_exit * superpay_start_factor && deferred > 0 && holdings > insured_units
            surplus_pay = [max_superpay_factor * interest_due, deferred].min
            surplus_pay_per_share = surplus_pay / s
            holdings -= surplus_pay_per_share
            deferred -= surplus_pay
            deferred_delta -= surplus_pay
            units_sold_now += surplus_pay_per_share
            interest_paid += surplus_pay
            interest_paid_to_funder += surplus_pay * (wholesale_lending_margin + cash_rate) / loan_interest_rate
          end
        end
      end
      
      # Pool excess units logic
      if enable_pool && !in_holiday && deferred < 1 && expected_reinvestment && holdings_value > expected_reinvestment[t] && holdings > insured_units
        excess_units = (holdings_value - expected_reinvestment[t]) / s
        holdings -= excess_units
        units_to_pool = excess_units
      end
      
      # Hedging logic (if enabled) - EXACT Python implementation
      hedge_units_delta = 0.0
      if hedged
        t_mod_4 = t & 3  # Bitwise AND for modulo 4
        if t_mod_4 == 0
          holdings -= holdings * hedging_cost_pa
          year_move = (s - last_yearly_hedge_price) / last_yearly_hedge_price
          if year_move < -hedging_max_loss
            buy_units = ((last_yearly_hedge_price / s) * (1 - hedging_max_loss) - 1) * holdings
            hedge_units_delta = buy_units
            holdings += buy_units
          end
          last_yearly_hedge_price = s
        end
        
        if t % 20 == 0  # Every 5 years (4*5=20 quarters)
          year_move = (s - last_5yearly_hedge_price) / last_5yearly_hedge_price
          adj_holds = holdings * (last_5yearly_hedge_price / s) * (1 + hedging_cap * 5)
          if holdings > adj_holds
            sell_units = holdings - adj_holds
            hedge_units_delta -= sell_units
            holdings -= sell_units
          end
          last_5yearly_hedge_price = s
        end
      end
      
      # Update cumulative tracking
      cum_units_to_pool += units_to_pool
      funder_earned += interest_paid_to_funder
      cummlative_units_sold += units_sold_now
      cum_interest_paid += interest_paid
      yearly_annuity_income = 0.0
      
      # Annuity income (quarterly)
      if t < annuity_duration_quarters
        yearly_annuity_income += annual_income_quarter
        if pi_progressive_repayment
          units_to_principal = annual_income_quarter / s
        end
      end
      
      subperform = holiday_quarters >= subperform_loan_threshold_quarters
      
      # Calculate year and quarter exactly like Python
      t_minus_1 = t - 1
      year = (t_minus_1 >> 2) + 1  # Bitwise right shift for division by 4
      quarter = t - (year - 1) * 4
      
      # Update holdings value after all calculations
      holdings_value = holdings * s
      
      # Store results in array matching Python's exact 29 columns and order
      row_data = [
        pathn, t, year_offset + year, quarter, s, interest_due.round, loan_size.round,
        holdings, holdings_value.round, deferred, 
        [loan_size - holdings_value, 0].max.round,
        (holdings_value - loan_size - deferred + cum_units_to_pool * s).round,
        in_holiday, funder_earned, yearly_annuity_income, holiday_quarters, subperform,
        interest_paid, interest_paid_to_funder, loan_interest_rate, units_sold_now,
        cummlative_units_sold, deferred_delta, units_to_pool, cum_units_to_pool,
        cum_interest_paid, units_to_principal, units_sold_now + units_to_principal,
        hedge_units_delta
      ]
      all_data << row_data
      
      # Update loan size with annuity income
      if t < annuity_duration_quarters
        if pi_progressive_repayment
          holdings -= units_to_principal
        else
          loan_size += annual_income_quarter
        end
      end
    end
    
    # Convert to DataFrame format exactly matching Python column names
    columns = [
      "Path", "Period", "Year", "Quarter", "SP500", "Interest", "Loan size",
      "Units", "Reinvestment", "InterestDeficit", "CapitalDeficit", "Surplus",
      "Prob Holiday", "FunderEarned", "AnnuityIncome", "HolidayQuarters", 
      "Prob Subperform", "InterestPaid", "InterestPaidToFunder", "InterestRate",
      "UnitsSold", "CumUnitsSold", "InterestDeficitDelta", "UnitsToPool", 
      "CumUnitsToPool", "CumInterestPaid", "UnitsToPrincipal", "TotalUnitsSold", "HedgeUnitsDelta"
    ]
    
    # Convert to hash format for Ruby
    pathdf = {}
    columns.each_with_index do |col, idx|
      pathdf[col] = all_data.map { |row| row[idx] }
    end
    
    # Add cumulative columns
    pathdf['CumAnnuityIncome'] = cumulative_sum(pathdf['AnnuityIncome'])
    pathdf['CumInterestAccrued'] = cumulative_sum(pathdf['Interest'])
    
    # Format final result
    {
      pathdf: pathdf,
      price_paths: [[0, price_path]],
      sp500df: format_sp500df,
      accounts_table: generate_accounts_table(pathdf),
      debug_msgs: {
        insurance_cost: @insurance_cost,
        interest: cash_rate_series.is_a?(Array) ? cash_rate_series[0..5] : [cash_rate_series] * 6
      }
    }
  end

  def cumulative_sum(array)
    cumulative = 0.0
    array.map { |val| cumulative += val }
  end

  def format_sp500df
    # Convert S&P 500 data to expected format
    {
      'Date' => @sp500_data.map { |d| d[:date] },
      'AdjClose' => @sp500_data.map { |d| d[:adj_close] }
    }
  end

  def generate_main_outputs(pathdf)
    # Generate main outputs table for display, similar to Python service
    return [] if pathdf.nil? || pathdf.empty?
    
    [
      ["Reinvestment fraction", "", "#{(@reinvest_fraction * 100).round(1)}%", "", "", "", ""],
      ["Total Income", "TI", "$#{@params[:annual_income] * @params[:annuity_duration]}", "", "", "", ""],
      ["Total Loan", "L", "$#{@total_loan.round(0)}", "", "", "", ""],
      ["Insurance Cost", "", "$#{@insurance_cost.round(0)}", "", "", "", ""],
      ["Final Portfolio", "", "$#{pathdf['Reinvestment']&.last&.round(0) || 'N/A'}", "", "", "", ""],
      ["Cumulative Interest", "", "$#{pathdf['CumInterestAccrued']&.last&.round(0) || 'N/A'}", "", "", "", ""]
    ]
  end

  def generate_path_data(pathdf)
    # Generate path data for table display
    return { mean: [] } if pathdf.nil? || pathdf.empty?
    
    # Convert pathdf hash to array format for display
    mean_data = []
    
    if pathdf['Period'] && pathdf['SP500'] && pathdf['Reinvestment']
      pathdf['Period'].each_with_index do |period, i|
        mean_data << [
          period,
          pathdf['SP500'][i]&.round(2) || 0,
          pathdf['Interest'][i]&.round(4) || 0,
          pathdf['Loan size'][i]&.round(0) || 0,
          pathdf['Units'][i]&.round(6) || 0,
          pathdf['Reinvestment'][i]&.round(0) || 0,
          pathdf['InterestDeficit'][i]&.round(2) || 0,
          pathdf['CapitalDeficit'][i]&.round(2) || 0,
          pathdf['Surplus'][i]&.round(2) || 0,
          pathdf['FunderEarned'][i]&.round(2) || 0,
          pathdf['AnnuityIncome'][i]&.round(2) || 0
        ]
      end
    end
    
    { mean: mean_data }
  end

  def generate_chart_data(pathdf, price_paths = nil)
    # Generate chart data for visualization
    return { all_paths: [] } if pathdf.nil? || pathdf.empty?
    
    # For Monte Carlo simulation, we need to extract reinvestment paths for each simulation
    if pathdf['Path'] && pathdf['Reinvestment']
      # Group by path to create separate reinvestment paths
      paths_data = {}
      pathdf['Path'].each_with_index do |path_id, i|
        paths_data[path_id] ||= []
        paths_data[path_id] << pathdf['Reinvestment'][i]
      end
      
      # Convert to array format expected by JavaScript
      all_paths = paths_data.values
      { all_paths: all_paths }
    elsif pathdf['Reinvestment']
      # Single path case
      path = pathdf['Reinvestment']
      { all_paths: [path] }
    else
      { all_paths: [] }
    end
  end

  def generate_accounts_table(pathdf)
    # Generate summary table similar to Python accounts_table function
    return [] if pathdf.nil? || pathdf.empty?
    
    # Use Python column names
    final_reinvestment = pathdf['Reinvestment']&.last || 0
    final_loan = pathdf['Loan size']&.last || 0
    final_net_equity = pathdf['Surplus']&.last || 0
    total_annuity = pathdf['CumAnnuityIncome']&.last || 0
    total_interest_paid = pathdf['CumInterestPaid']&.last || 0
    total_units_sold = pathdf['CumUnitsSold']&.last || 0
    final_holiday_quarters = pathdf['HolidayQuarters']&.last || 0
    final_deferred = pathdf['InterestDeficit']&.last || 0
    
    [
      ['Total Loan', @total_loan.round(2)],
      ['Final Portfolio Value', final_reinvestment.round(2)],
      ['Final Loan Balance', final_loan.round(2)],
      ['Final Net Equity', final_net_equity.round(2)],
      ['Total Annuity Income', total_annuity.round(2)],
      ['Total Interest Paid', total_interest_paid.round(2)],
      ['Total Units Sold', total_units_sold.round(6)],
      ['Holiday Quarters (Final)', final_holiday_quarters],
      ['Deferred Amount (Final)', final_deferred.round(2)]
    ]
  end

  def validate_params
    required_params = [:house_value, :loan_duration, :loan_to_value]
    required_params.each do |param|
      raise ArgumentError, "Missing required parameter: #{param}" unless @params[param].present?
    end
    
    raise ArgumentError, "Loan duration must be positive" if @params[:loan_duration] <= 0
    raise ArgumentError, "House value must be positive" if @params[:house_value] <= 0
    raise ArgumentError, "LTV must be between 0 and 1" unless (0..1).include?(@params[:loan_to_value])
  end
end