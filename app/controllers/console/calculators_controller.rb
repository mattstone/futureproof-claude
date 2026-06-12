# Monte Carlo modelling calculator — same engines and parameter contract as
# the legacy admin tool; the monte-carlo-calculator Stimulus controller posts
# the form here and renders charts/tables client-side.
class Console::CalculatorsController < Console::BaseController
  before_action -> { require_capability(:manage_product) }
  skip_before_action :verify_authenticity_token, only: [ :calculate ]

  def index
  end

  def calculate
    converted_params = convert_percentage_params(calculator_params)
    engine = converted_params[:calculation_engine] || "python_monte_carlo"

    calculator = case engine
    when "python_monte_carlo" then PythonMonteCarloService.new(converted_params)
    when "python_historical" then PythonCalculatorService.new(converted_params)
    when "ruby_monte_carlo" then MortgageCalculatorService.new(converted_params)
    when "ruby_advanced" then MortgageCalculatorAdvancedService.new(converted_params)
    else MortgageCalculatorHistoricalService.new(converted_params)
    end

    @result = calculator.calculate
    @result[:calculation_engine] = engine

    render json: @result
  rescue => e
    Rails.logger.error "Calculator error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
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
    percentage_fields = [
      :loan_to_value, :at_risk_captital_fraction, :at_risk_capital_fraction,
      :equity_return, :volatility, :cash_rate, :insurer_profit_margin,
      :hedging_cost_pa, :hedging_max_loss, :hedging_cap, :wholesale_lending_margin,
      :additional_loan_margins, :insurance_cost_pa, :annual_house_price_appreciation
    ]

    percentage_fields.each do |field|
      next if converted[field].blank?

      value = converted[field].to_f
      converted[field] = value / 100.0 if value > 1
    end

    converted
  end
end
