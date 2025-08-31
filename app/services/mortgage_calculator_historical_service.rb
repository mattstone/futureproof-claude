require 'csv'

class MortgageCalculatorHistoricalService
  def initialize(params)
    @params = params.is_a?(ActionController::Parameters) ? params : params.with_indifferent_access
    set_default_values
    load_historical_data
    validate_params
  end

  def calculate
    # Use historical data approach like Python
    Rails.logger.info "=== HISTORICAL MORTGAGE CALCULATOR ==="
    Rails.logger.info "Using historical S&P 500 and Fed Funds data"
    Rails.logger.info "Start year: #{@params[:start_year]}"
    Rails.logger.info "Loan duration: #{@params[:loan_duration]} years"
    
    # Extract historical price and interest paths
    price_path, interest_series = extract_historical_paths
    
    # Run single mortgage calculation with historical data
    result = single_mortgage_historical(price_path, interest_series)
    
    Rails.logger.info "Historical calculation completed"
    result
  end

  private

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
    
    # Calculate derived values
    @total_loan = @params[:house_value] * @params[:loan_to_value]
    @reinvest_fraction = 1.0 - (@params[:annuity_duration] * @params[:annual_income]) / @total_loan
    @insurance_profit_margin = 1.0 + @params[:insurer_profit_margin]
    @insurance_cost = @params[:insurance_cost_pa] * @total_loan * @params[:loan_duration]
  end

  def load_historical_data
    # Load S&P 500 data
    sp500_path = Rails.root.join('data', 'sp500tr.csv')
    @sp500_data = []
    CSV.foreach(sp500_path, headers: true) do |row|
      @sp500_data << {
        date: row['Date'],
        adj_close: row['AdjClose'].gsub(',', '').to_f
      }
    end
    
    # Load Federal Funds data  
    fedfunds_path = Rails.root.join('data', 'FEDFUNDS2.csv')
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

  def single_mortgage_historical(price_path, interest_series)
    # Implement the core mortgage calculation logic from Python core_model_advanced.py
    dt = 1.0 / 12.0
    s0 = price_path[0]
    periods = price_path.length
    
    # Initialize arrays to track simulation
    result_data = []
    
    # Track key variables over time
    portfolio_value = 0.0
    loan_balance = @total_loan
    cumulative_interest = 0.0
    cumulative_interest_paid = 0.0
    cumulative_annuity_income = 0.0
    
    # Initial reinvestment (negative because it's money going out)
    initial_reinvestment = @reinvest_fraction * @total_loan
    portfolio_value = -initial_reinvestment
    
    # Simulate each month
    (0...periods).each do |month|
      year = @params[:start_year] - 1 + (month / 12.0)
      
      # Current equity price
      current_price = price_path[month]
      price_return = month == 0 ? 0.0 : (price_path[month] - price_path[month - 1]) / price_path[month - 1]
      
      # Current interest rate
      current_interest_rate = interest_series[month]
      
      # Monthly mortgage calculations
      monthly_interest = loan_balance * (current_interest_rate + @params[:wholesale_lending_margin] + @params[:additional_loan_margins]) / 12.0
      cumulative_interest += monthly_interest
      
      # Interest payment logic (simplified - could be interest-only or principal+interest)
      if @params[:loan_type] == "Interest only"
        monthly_interest_payment = monthly_interest
        principal_payment = 0.0
      else
        # Principal + Interest calculation would go here
        monthly_interest_payment = monthly_interest
        principal_payment = 0.0  # Simplified for now
      end
      
      cumulative_interest_paid += monthly_interest_payment
      loan_balance -= principal_payment
      
      # Annuity income (only for first @annuity_duration years)
      if month < @params[:annuity_duration] * 12
        monthly_annuity = @params[:annual_income] / 12.0
        cumulative_annuity_income += monthly_annuity
      else
        monthly_annuity = 0.0
      end
      
      # Portfolio value update (simplified equity investment growth)
      if portfolio_value > 0
        portfolio_value *= (1.0 + price_return)
      else
        # If we have negative portfolio (debt), it grows by equity returns
        portfolio_value *= (1.0 + price_return)
      end
      
      # Add new investments from annuity income
      portfolio_value += monthly_annuity * @reinvest_fraction
      
      # Net equity = Portfolio value - Loan balance
      net_equity = portfolio_value - loan_balance
      
      # Store monthly results
      result_data << {
        month: month,
        year: year.round(2),
        equity_price: current_price,
        portfolio_value: portfolio_value,
        loan_balance: loan_balance,
        interest_accrued: monthly_interest,
        interest_paid: monthly_interest_payment,
        annuity_income: monthly_annuity,
        cumulative_annuity_income: cumulative_annuity_income,
        cumulative_interest: cumulative_interest,
        cumulative_interest_paid: cumulative_interest_paid,
        net_equity: net_equity
      }
    end
    
    # Format result to match expected structure
    {
      pathdf: format_pathdf(result_data),
      price_paths: [[0, price_path]],
      sp500df: format_sp500df,
      accounts_table: generate_accounts_table(result_data),
      debug_msgs: {
        insurance_cost: @insurance_cost,
        interest: interest_series[0..5]  # First few interest rates for debugging
      }
    }
  end

  def format_pathdf(result_data)
    # Convert result data to the expected pathdf format
    pathdf = {
      'Path' => [],
      'Period' => [],
      'Year' => [],
      'EquityPrice' => [],
      'PortfolioValue' => [],
      'LoanBalance' => [],
      'InterestAccrued' => [],
      'InterestPaid' => [],
      'AnnuityIncome' => [],
      'CumAnnuityIncome' => [],
      'CumInterestAccrued' => [],
      'CumInterestPaid' => [],
      'NetEquity' => []
    }
    
    result_data.each do |data|
      pathdf['Path'] << 0  # Single path
      pathdf['Period'] << data[:month]
      pathdf['Year'] << data[:year]
      pathdf['EquityPrice'] << data[:equity_price]
      pathdf['PortfolioValue'] << data[:portfolio_value]
      pathdf['LoanBalance'] << data[:loan_balance]
      pathdf['InterestAccrued'] << data[:interest_accrued]
      pathdf['InterestPaid'] << data[:interest_paid]
      pathdf['AnnuityIncome'] << data[:annuity_income]
      pathdf['CumAnnuityIncome'] << data[:cumulative_annuity_income]
      pathdf['CumInterestAccrued'] << data[:cumulative_interest]
      pathdf['CumInterestPaid'] << data[:cumulative_interest_paid]
      pathdf['NetEquity'] << data[:net_equity]
    end
    
    pathdf
  end

  def format_sp500df
    # Convert S&P 500 data to expected format
    {
      'Date' => @sp500_data.map { |d| d[:date] },
      'AdjClose' => @sp500_data.map { |d| d[:adj_close] }
    }
  end

  def generate_accounts_table(result_data)
    # Generate summary table similar to Python accounts_table function
    final_data = result_data.last
    
    [
      ['Total Loan', @total_loan.round(2)],
      ['Final Portfolio Value', final_data[:portfolio_value].round(2)],
      ['Final Loan Balance', final_data[:loan_balance].round(2)],
      ['Final Net Equity', final_data[:net_equity].round(2)],
      ['Total Annuity Income', final_data[:cumulative_annuity_income].round(2)],
      ['Total Interest Paid', final_data[:cumulative_interest_paid].round(2)]
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