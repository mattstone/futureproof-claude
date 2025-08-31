class Admin::CalculatorsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: [:calculate]
  
  layout 'admin/application'
  
  def index
    @page_title = "Monte Carlo Mortgage Calculator"
  end
  
  def calculate
    begin
      Rails.logger.info "=== RECEIVED CALCULATOR PARAMS ==="
      Rails.logger.info "Raw params: #{params.inspect}"
      Rails.logger.info "Calculator params exist: #{params[:calculator].present?}"
      if params[:calculator].present?
        calculator_params.each { |k, v| Rails.logger.info "#{k}: #{v}" }
      end
      Rails.logger.info "=================================="
      
      # Convert percentage parameters to decimals for service compatibility
      converted_params = convert_percentage_params(calculator_params)
      
      # Choose calculation service based on engine parameter
      # Note: Python Monte Carlo is 78x faster than Ruby - using Python for production
      engine = converted_params[:calculation_engine] || 'python_monte_carlo'
      
      calculator = case engine
      when 'python_monte_carlo'
        Rails.logger.info "Using Python Monte Carlo Service (PRODUCTION DEFAULT)"
        PythonMonteCarloService.new(converted_params)
      when 'python_historical'
        Rails.logger.info "Using Python Historical Service"
        PythonCalculatorService.new(converted_params)
      when 'ruby_monte_carlo'
        Rails.logger.info "Using Ruby Monte Carlo Service (78x slower than Python)"
        MortgageCalculatorService.new(converted_params)
      when 'ruby_advanced'
        Rails.logger.info "Using Ruby Advanced Service (Python Logic Match)"
        MortgageCalculatorAdvancedService.new(converted_params)
      else # 'ruby_historical'
        Rails.logger.info "Using Ruby Historical Service"
        MortgageCalculatorHistoricalService.new(converted_params)
      end
      
      @result = calculator.calculate
      @result[:calculation_engine] = engine
      
      Rails.logger.info "=== CALCULATION RESULT ==="
      Rails.logger.info "Main outputs: #{@result[:main_outputs]}"
      Rails.logger.info "Statistics: #{@result[:statistics]}"
      Rails.logger.info "Chart data keys: #{@result[:chart_data]&.keys}"
      Rails.logger.info "=========================="
      
      respond_to do |format|
        format.json { render json: @result }
        format.html { render :index }
      end
    rescue => e
      Rails.logger.error "Calculator error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      respond_to do |format|
        format.json { render json: { error: e.message }, status: 422 }
        format.html { 
          flash.now[:alert] = "Calculation error: #{e.message}"
          render :index 
        }
      end
    end
  end
  
  private
  
  def calculator_params
    params.require(:calculator).permit(
      :house_value, :loan_duration, :annuity_duration, :loan_type, :principal_repayment,
      :loan_to_value, :annual_income, :at_risk_captital_fraction, :equity_return,
      :volatility, :total_paths, :random_seed, :cash_rate, :insurer_profit_margin,
      :hedged, :hedging_cost_pa, :hedging_max_loss, :hedging_cap, :wholesale_lending_margin,
      :additional_loan_margins, :holiday_enter_fraction, :holiday_exit_fraction,
      :subperform_loan_threshold_quarters, :max_superpay_factor, :superpay_start_factor,
      :enable_pool, :path_table_type, :calculation_engine, :start_year, :insurance_cost_pa,
      :annual_house_price_appreciation, :at_risk_capital_fraction
    )
  end
  
  def convert_percentage_params(params)
    converted = params.dup
    
    # Convert percentage fields (0-100) to decimals (0.0-1.0) 
    percentage_fields = [
      :loan_to_value, :at_risk_captital_fraction, :at_risk_capital_fraction,
      :equity_return, :volatility, :cash_rate, :insurer_profit_margin,
      :hedging_cost_pa, :hedging_max_loss, :hedging_cap, :wholesale_lending_margin,
      :additional_loan_margins, :insurance_cost_pa, :annual_house_price_appreciation
    ]
    
    percentage_fields.each do |field|
      if converted[field].present?
        value = converted[field].to_f
        # Convert percentage (0-100) to decimal (0.0-1.0) for most fields
        # Some fields like equity_return might be entered as 10.8% = 0.108
        if field == :loan_to_value && value > 1
          converted[field] = value / 100.0
        elsif [:at_risk_captital_fraction, :at_risk_capital_fraction].include?(field) && value > 1
          converted[field] = value / 100.0
        elsif [:equity_return, :volatility, :cash_rate].include?(field) && value > 1
          converted[field] = value / 100.0
        elsif [:insurer_profit_margin, :hedging_cost_pa, :hedging_max_loss, :hedging_cap].include?(field) && value > 1
          converted[field] = value / 100.0
        elsif [:wholesale_lending_margin, :additional_loan_margins, :insurance_cost_pa, :annual_house_price_appreciation].include?(field) && value > 1
          converted[field] = value / 100.0
        end
      end
    end
    
    Rails.logger.info "=== CONVERTED PARAMS ==="
    converted.each { |k, v| Rails.logger.info "#{k}: #{v}" }
    Rails.logger.info "========================="
    
    converted
  end
end