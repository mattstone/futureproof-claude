require 'matrix'
require 'csv'

class MortgageCalculatorService
  def initialize(params)
    @params = params.is_a?(ActionController::Parameters) ? params : params.with_indifferent_access
    set_default_values
    validate_params
  end

  def calculate
    # Debug: Log the actual parameters being used
    Rails.logger.info "=== MORTGAGE CALCULATOR PARAMETERS ==="
    Rails.logger.info "House Value: #{@params[:house_value]}"
    Rails.logger.info "Loan Duration: #{@params[:loan_duration]}"
    Rails.logger.info "Annual Income: #{@params[:annual_income]}"
    Rails.logger.info "Equity Return: #{@params[:equity_return]}"
    Rails.logger.info "Volatility: #{@params[:volatility]}"
    Rails.logger.info "Total Paths: #{@params[:total_paths]}"
    Rails.logger.info "Cash Rate: #{@params[:cash_rate]}"
    Rails.logger.info "LTV: #{@params[:loan_to_value]}"
    Rails.logger.info "=================================="
    
    # Generate Monte Carlo price paths
    price_paths = generate_monte_carlo_paths
    
    # Run the mortgage simulation
    df = single_mortgage_simulation(price_paths)
    
    # Generate main outputs table
    main_outputs = main_outputs_table(df)
    
    # Generate path data for different percentiles
    path_data = generate_path_data(df)
    
    {
      main_outputs: main_outputs,
      path_data: path_data,
      total_paths: @params[:total_paths],
      chart_data: generate_chart_data(df, price_paths)
    }
  end

  private

  def set_default_values
    # Set defaults only for missing or empty values
    @params[:house_value] = @params[:house_value].present? ? @params[:house_value] : 1500000
    @params[:loan_duration] = @params[:loan_duration].present? ? @params[:loan_duration] : 30
    @params[:annuity_duration] = @params[:annuity_duration].present? ? @params[:annuity_duration] : 10
    @params[:loan_type] = @params[:loan_type].present? ? @params[:loan_type] : 'Interest only'
    @params[:principal_repayment] = @params[:principal_repayment].present? ? @params[:principal_repayment] : false
    @params[:loan_to_value] = @params[:loan_to_value].present? ? @params[:loan_to_value] : 80
    @params[:annual_income] = @params[:annual_income].present? ? @params[:annual_income] : 30000
    @params[:at_risk_captital_fraction] = @params[:at_risk_captital_fraction].present? ? @params[:at_risk_captital_fraction] : 0
    @params[:equity_return] = @params[:equity_return].present? ? @params[:equity_return] : 10.8
    @params[:volatility] = @params[:volatility].present? ? @params[:volatility] : 15
    @params[:total_paths] = @params[:total_paths].present? ? @params[:total_paths] : 1000
    @params[:random_seed] = @params[:random_seed].present? ? @params[:random_seed] : 0
    @params[:cash_rate] = @params[:cash_rate].present? ? @params[:cash_rate] : 3.85
    @params[:insurer_profit_margin] = @params[:insurer_profit_margin].present? ? @params[:insurer_profit_margin] : 50
    @params[:hedged] = @params[:hedged].present? ? @params[:hedged] : false
    @params[:hedging_cost_pa] = @params[:hedging_cost_pa].present? ? @params[:hedging_cost_pa] : 0.5
    @params[:hedging_max_loss] = @params[:hedging_max_loss].present? ? @params[:hedging_max_loss] : 10
    @params[:hedging_cap] = @params[:hedging_cap].present? ? @params[:hedging_cap] : 20
    @params[:wholesale_lending_margin] = @params[:wholesale_lending_margin].present? ? @params[:wholesale_lending_margin] : 2
    @params[:additional_loan_margins] = @params[:additional_loan_margins].present? ? @params[:additional_loan_margins] : 1.25
    @params[:holiday_enter_fraction] = @params[:holiday_enter_fraction].present? ? @params[:holiday_enter_fraction] : 0.9
    @params[:holiday_exit_fraction] = @params[:holiday_exit_fraction].present? ? @params[:holiday_exit_fraction] : 1.458
    @params[:subperform_loan_threshold_quarters] = @params[:subperform_loan_threshold_quarters].present? ? @params[:subperform_loan_threshold_quarters] : 12
    @params[:max_superpay_factor] = @params[:max_superpay_factor].present? ? @params[:max_superpay_factor] : 1.261
    @params[:superpay_start_factor] = @params[:superpay_start_factor].present? ? @params[:superpay_start_factor] : 1.50
    @params[:enable_pool] = @params[:enable_pool].present? ? @params[:enable_pool] : false
    
    # Convert all numeric parameters to proper types
    @params[:house_value] = @params[:house_value].to_f
    @params[:loan_duration] = @params[:loan_duration].to_i
    @params[:annuity_duration] = @params[:annuity_duration].to_i
    @params[:loan_to_value] = @params[:loan_to_value].to_f
    @params[:annual_income] = @params[:annual_income].to_f
    @params[:at_risk_captital_fraction] = @params[:at_risk_captital_fraction].to_f
    @params[:equity_return] = @params[:equity_return].to_f
    @params[:volatility] = @params[:volatility].to_f
    @params[:total_paths] = @params[:total_paths].to_i
    @params[:random_seed] = @params[:random_seed].to_i
    @params[:cash_rate] = @params[:cash_rate].to_f
    @params[:insurer_profit_margin] = @params[:insurer_profit_margin].to_f
    @params[:hedging_cost_pa] = @params[:hedging_cost_pa].to_f
    @params[:hedging_max_loss] = @params[:hedging_max_loss].to_f
    @params[:hedging_cap] = @params[:hedging_cap].to_f
    @params[:wholesale_lending_margin] = @params[:wholesale_lending_margin].to_f
    @params[:additional_loan_margins] = @params[:additional_loan_margins].to_f
    @params[:holiday_enter_fraction] = @params[:holiday_enter_fraction].to_f
    @params[:holiday_exit_fraction] = @params[:holiday_exit_fraction].to_f
    @params[:subperform_loan_threshold_quarters] = @params[:subperform_loan_threshold_quarters].to_i
    @params[:max_superpay_factor] = @params[:max_superpay_factor].to_f
    @params[:superpay_start_factor] = @params[:superpay_start_factor].to_f
    
    # Boolean conversion
    @params[:principal_repayment] = @params[:principal_repayment] == '1' || @params[:principal_repayment] == true
    @params[:hedged] = @params[:hedged] == '1' || @params[:hedged] == true
    @params[:enable_pool] = @params[:enable_pool] == '1' || @params[:enable_pool] == true
    
    # Convert percentages to decimals
    @params[:equity_return] = @params[:equity_return] / 100
    @params[:volatility] = @params[:volatility] / 100
    @params[:cash_rate] = @params[:cash_rate] / 100
    @params[:loan_to_value] = @params[:loan_to_value] / 100
    @params[:at_risk_captital_fraction] = @params[:at_risk_captital_fraction] / 100
    @params[:insurer_profit_margin] = @params[:insurer_profit_margin] / 100
    @params[:hedging_cost_pa] = @params[:hedging_cost_pa] / 100
    @params[:hedging_max_loss] = @params[:hedging_max_loss] / 100
    @params[:hedging_cap] = @params[:hedging_cap] / 100
    @params[:wholesale_lending_margin] = @params[:wholesale_lending_margin] / 100
    @params[:additional_loan_margins] = @params[:additional_loan_margins] / 100
  end

  def validate_params
    required = [:house_value, :loan_duration, :annuity_duration, :annual_income, :total_paths]
    required.each do |param|
      raise ArgumentError, "#{param} is required" if @params[param].blank?
    end

    raise ArgumentError, "total_paths must be positive" if @params[:total_paths].to_i <= 0
    raise ArgumentError, "loan_duration must be positive" if @params[:loan_duration].to_i <= 0
    
    # Business rule validation
    loan_duration = @params[:loan_duration].to_i
    annuity_duration = @params[:annuity_duration].to_i
    
    # Validate loan term is one of the allowed values
    allowed_loan_terms = [15, 20, 25, 30]
    unless allowed_loan_terms.include?(loan_duration)
      raise ArgumentError, "loan_duration must be one of: #{allowed_loan_terms.join(', ')}"
    end
    
    # Validate annuity duration is one of the allowed values
    allowed_annuity_terms = [10, 15, 20, 25, 30]
    unless allowed_annuity_terms.include?(annuity_duration)
      raise ArgumentError, "annuity_duration must be one of: #{allowed_annuity_terms.join(', ')}"
    end
    
    # Business rule: Annuity cannot be longer than loan term
    # Auto-correct by adjusting loan term to match annuity if needed
    if annuity_duration > loan_duration
      Rails.logger.info "Auto-adjusting loan term from #{loan_duration} to #{annuity_duration} to match annuity duration"
      @params[:loan_duration] = annuity_duration
      # Re-convert to proper type after adjustment
      @params[:loan_duration] = @params[:loan_duration].to_i
    end
  end

  def generate_monte_carlo_paths
    # Set random seed for reproducibility
    Random.srand(@params[:random_seed].to_i) if @params[:random_seed].to_i > 0
    
    dt = 1.0 / 120.0  # Monthly time step
    loan_duration = @params[:loan_duration].to_f
    equity_return = @params[:equity_return]
    volatility = @params[:volatility]
    total_paths = @params[:total_paths].to_i
    s0 = 1.0  # Starting price normalized to 1
    
    n = (loan_duration / dt).round
    paths = []
    
    total_paths.times do |path_num|
      # Generate standard normal random variables
      randoms = Array.new(n) { random_normal }
      
      # Calculate geometric Brownian motion path
      ts = (0...n).map { |i| i * dt }
      w = randoms.map.with_index do |rand, i|
        i == 0 ? rand * Math.sqrt(dt) : randoms[0..i].sum * Math.sqrt(dt)
      end
      
      x = ts.zip(w).map do |t, w_t|
        (equity_return - 0.5 * volatility**2) * t + volatility * w_t
      end
      
      s = x.map { |x_t| s0 * Math.exp(x_t) }
      
      paths << [path_num, s]
    end
    
    paths
  end

  def random_normal
    # Box-Muller transform to generate standard normal random variables
    @spare_random ||= nil
    
    if @spare_random
      result = @spare_random
      @spare_random = nil
      result
    else
      u = 0
      v = 0
      w = 0
      
      loop do
        u = 2 * rand - 1
        v = 2 * rand - 1
        w = u * u + v * v
        break if w < 1 && w != 0
      end
      
      w = Math.sqrt(-2 * Math.log(w) / w)
      @spare_random = v * w
      u * w
    end
  end

  def single_mortgage_simulation(price_paths)
    # Calculate loan parameters
    total_loan = @params[:house_value].to_f * @params[:loan_to_value]
    reinvest_fraction = @params[:loan_to_value]
    loan_duration = @params[:loan_duration].to_f
    annual_income = @params[:annual_income].to_f
    annuity_duration = @params[:annuity_duration].to_f
    
    # Insurance parameters
    insurance_profit_margin = @params[:insurer_profit_margin] + 1
    cash_rate = @params[:cash_rate]
    
    # Calculate insurance cost (simplified)
    insurance_cost = total_loan * 0.1  # Simplified calculation
    
    all_data = []
    
    price_paths.each do |path_num, s_path|
      path_data = simulate_single_path(
        path_num, s_path, total_loan, reinvest_fraction, loan_duration,
        annual_income, annuity_duration, insurance_profit_margin, insurance_cost
      )
      all_data.concat(path_data)
    end
    
    all_data
  end

  def simulate_single_path(path_num, s_path, total_loan, reinvest_fraction, loan_duration,
                           annual_income, annuity_duration, insurance_profit_margin, insurance_cost)
    
    cash_rate = @params[:cash_rate]
    wholesale_lending_margin = @params[:wholesale_lending_margin]
    additional_loan_margins = @params[:additional_loan_margins]
    holiday_enter_fraction = @params[:holiday_enter_fraction]
    holiday_exit_fraction = @params[:holiday_exit_fraction]
    
    dt = 1.0/120.0
    quarter_div = 0.25
    dt_quarter_inv = 1.0/(dt*4)
    annual_income_quarter = annual_income * quarter_div
    annuity_duration_quarters = (annuity_duration * 4).to_i
    total_periods = (4 * loan_duration + 1).to_i
    
    # Initial values
    s0 = s_path[0]
    avg_cash_rate = cash_rate
    initial_reinvestment = total_loan * reinvest_fraction - 
      insurance_profit_margin * insurance_cost / (1 + avg_cash_rate)**loan_duration
    
    holiday_enter = initial_reinvestment * holiday_enter_fraction
    holiday_exit = initial_reinvestment * holiday_exit_fraction
    
    # Path variables
    holdings = initial_reinvestment / s0
    cumulative_units_sold = 0.0
    loan_size = total_loan * reinvest_fraction + annual_income_quarter
    in_holiday = holiday_enter_fraction > 1
    holiday_quarters = 0
    deferred = 0.0
    funder_earned = 0.0
    cum_interest_paid = 0.0
    
    result_data = []
    
    # Initial row
    holdings_s0 = holdings * s0
    result_data << [
      path_num, 0, 0, 0, s0, 0, (total_loan * reinvest_fraction).round,
      holdings, holdings_s0.round, 0, [loan_size - holdings_s0, 0].max.round,
      (holdings_s0 - loan_size - deferred).round, in_holiday, 0,
      annual_income_quarter, 0, false, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ]
    
    # Simulate each quarter
    (1...total_periods).each do |t|
      price_idx = (t * dt_quarter_inv - 1).to_i
      s = s_path[price_idx] || s_path[-1]
      
      loan_interest_rate = cash_rate + wholesale_lending_margin + additional_loan_margins
      interest_due = loan_size * loan_interest_rate * quarter_div
      
      interest_paid = 0.0
      interest_paid_to_funder = 0.0
      deferred_delta = 0.0
      units_sold_now = 0.0
      
      interest_due_per_share = interest_due / s
      holdings_value = holdings * s
      
      # Holiday logic (simplified)
      if in_holiday
        if holdings_value > holiday_exit
          in_holiday = false
          holdings -= interest_due_per_share
          units_sold_now += interest_due_per_share
          interest_paid = interest_due
          interest_paid_to_funder = loan_size * (wholesale_lending_margin + cash_rate) * quarter_div
          holiday_quarters = 0
        else
          holiday_quarters += 1
          deferred += interest_due
          deferred_delta += interest_due
        end
      else
        if holdings_value < holiday_enter
          deferred += interest_due
          deferred_delta += interest_due
          in_holiday = true
          holiday_quarters += 1
        else
          holiday_quarters = 0
          holdings -= interest_due_per_share
          units_sold_now += interest_due_per_share
          interest_paid = interest_due
          interest_paid_to_funder = loan_size * (wholesale_lending_margin + cash_rate) * quarter_div
        end
      end
      
      funder_earned += interest_paid_to_funder
      cumulative_units_sold += units_sold_now
      cum_interest_paid += interest_paid
      yearly_annuity_income = 0.0
      
      if t < annuity_duration_quarters
        yearly_annuity_income += annual_income_quarter
        loan_size += annual_income_quarter unless @params[:principal_repayment]
      end
      
      subperform = holiday_quarters >= @params[:subperform_loan_threshold_quarters]
      
      year = ((t - 1) / 4).to_i + 1
      quarter = t - (year - 1) * 4
      
      holdings_value = holdings * s
      
      # Store results
      result_data << [
        path_num, t, year, quarter, s, interest_due.round, loan_size.round,
        holdings, holdings_value.round, deferred.round, 
        [loan_size - holdings_value, 0].max.round,
        (holdings_value - loan_size - deferred).round, in_holiday,
        funder_earned.round, yearly_annuity_income, holiday_quarters, subperform,
        interest_paid.round, interest_paid_to_funder.round, loan_interest_rate,
        units_sold_now, cumulative_units_sold, deferred_delta.round,
        0, 0, cum_interest_paid.round, 0, units_sold_now, 0
      ]
    end
    
    result_data
  end

  def main_outputs_table(df_data)
    # Convert array data to hash structure for easier processing
    columns = [
      "Path", "Period", "Year", "Quarter", "SP500", "Interest", "Loan size",
      "Units", "Reinvestment", "InterestDeficit", "CapitalDeficit", "Surplus",
      "Prob Holiday", "FunderEarned", "AnnuityIncome", "HolidayQuarters", 
      "Prob Subperform", "InterestPaid", "InterestPaidToFunder", "InterestRate", 
      "UnitsSold", "CumUnitsSold", "InterestDeficitDelta", "UnitsToPool", 
      "CumUnitsToPool", "CumInterestPaid", "UnitsToPrincipal", "TotalUnitsSold", "HedgeUnitsDelta"
    ]
    
    df = df_data.map do |row|
      Hash[columns.zip(row)]
    end
    
    # Get end period data
    loan_duration = @params[:loan_duration].to_f
    total_loan = @params[:house_value].to_f * @params[:loan_to_value]
    annual_income = @params[:annual_income].to_f
    annuity_duration = @params[:annuity_duration].to_f
    
    dfend = df.select { |row| row["Period"] == loan_duration * 4 }
    
    # Calculate key metrics
    reinvestment_values = dfend.map { |row| row["Reinvestment"] }
    interest_deficit_values = dfend.map { |row| row["InterestDeficit"] }
    
    mean_reinvestment = reinvestment_values.sum.to_f / reinvestment_values.size
    mean_interest_deficit = interest_deficit_values.sum.to_f / interest_deficit_values.size
    
    # Sort paths by SP500 performance for percentile analysis
    sorted_paths = dfend.sort_by { |row| row["SP500"] }
    total_paths = sorted_paths.size
    
    worse_path = sorted_paths[(0.02 * total_paths).round]
    bad_path = sorted_paths[(0.25 * total_paths).round]
    median_path = sorted_paths[(0.50 * total_paths).round]
    good_path = sorted_paths[(0.75 * total_paths).round]
    
    # Build output table
    outputs = []
    outputs << ["Reinvestment fraction", "", format_percent(@params[:loan_to_value]), "", "", "", ""]
    outputs << ["Initial reinvestment", "R0", format_currency(mean_reinvestment), "", "", "", ""]
    outputs << ["Total Income", "TI", format_currency(annual_income * annuity_duration), "", "", "", ""]
    outputs << ["Outstanding", "L+D", 
                format_currency(total_loan + mean_interest_deficit),
                format_currency(total_loan + worse_path["InterestDeficit"]),
                format_currency(total_loan + bad_path["InterestDeficit"]),
                format_currency(total_loan + median_path["InterestDeficit"]),
                format_currency(total_loan + good_path["InterestDeficit"])]
    outputs << ["Reinvestment value", "R",
                format_currency(mean_reinvestment),
                format_currency(worse_path["Reinvestment"]),
                format_currency(bad_path["Reinvestment"]),
                format_currency(median_path["Reinvestment"]),
                format_currency(good_path["Reinvestment"])]
    
    outputs
  end

  def generate_path_data(df_data)
    # Group data by path and calculate statistics
    paths = df_data.group_by { |row| row[0] }  # Group by Path (first column)
    
    # Calculate mean values for each period
    periods = df_data.map { |row| row[1] }.uniq.sort  # Get unique periods
    
    mean_data = periods.map do |period|
      period_rows = df_data.select { |row| row[1] == period }
      
      if period_rows.any?
        [
          period,
          period_rows.map { |row| row[4] }.sum.to_f / period_rows.size,  # SP500
          period_rows.map { |row| row[5] }.sum.to_f / period_rows.size,  # Interest
          period_rows.map { |row| row[6] }.sum.to_f / period_rows.size,  # Loan size
          period_rows.map { |row| row[7] }.sum.to_f / period_rows.size,  # Units
          period_rows.map { |row| row[8] }.sum.to_f / period_rows.size,  # Reinvestment
          period_rows.map { |row| row[9] }.sum.to_f / period_rows.size,  # InterestDeficit
          period_rows.map { |row| row[10] }.sum.to_f / period_rows.size, # CapitalDeficit
          period_rows.map { |row| row[11] }.sum.to_f / period_rows.size, # Surplus
          period_rows.map { |row| row[13] }.sum.to_f / period_rows.size, # FunderEarned
          period_rows.map { |row| row[14] }.sum.to_f / period_rows.size  # AnnuityIncome
        ]
      end
    end.compact
    
    {
      mean: mean_data,
      median: mean_data, # Simplified - using mean for now
      "2_percentile" => mean_data,
      "25_percentile" => mean_data,
      "75_percentile" => mean_data
    }
  end

  def generate_chart_data(df_data, price_paths)
    # Extract periods for x-axis
    periods = df_data.map { |row| row[1] }.uniq.sort
    
    # Calculate mean values for key metrics
    mean_prices = []
    mean_reinvest = []
    mean_loan = []
    
    periods.each do |period|
      period_rows = df_data.select { |row| row[1] == period }
      next if period_rows.empty?
      
      mean_prices << period_rows.map { |row| row[4] }.sum.to_f / period_rows.size
      mean_reinvest << period_rows.map { |row| row[8] }.sum.to_f / period_rows.size
      mean_loan << period_rows.map { |row| row[6] }.sum.to_f / period_rows.size
    end
    
    # Generate all simulation paths for D3.js visualization
    all_paths = []
    
    # Group data by path number and extract portfolio values (Units column)
    price_paths.each do |path_num, _|
      path_data = df_data.select { |row| row[0] == path_num }
                         .sort_by { |row| row[1] } # Sort by period
                         .map { |row| row[4].to_f } # Extract Units (portfolio value)
      
      all_paths << path_data if path_data.size > 0
    end
    
    {
      mean_period: periods,
      mc_prices: mean_prices,
      mean_reinvest: mean_reinvest,
      mean_loan: mean_loan,
      mean_deficit: Array.new(periods.size, 0), # Placeholder
      all_paths: all_paths
    }
  end

  def format_currency(value)
    "$#{value.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end

  def format_percent(value)
    "#{(value * 100).round(1)}%"
  end
end