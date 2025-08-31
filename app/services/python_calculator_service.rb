require 'json'
require 'tempfile'

class PythonCalculatorService
  def initialize(params)
    @params = params.is_a?(ActionController::Parameters) ? params : params.with_indifferent_access
    set_default_values
    validate_params
  end

  def calculate
    # Create Python script with Ruby parameters
    python_script = generate_python_script_with_params
    
    # Write script to python directory so imports work
    python_dir = Rails.root.join('python')
    temp_filename = "ruby_calculator_#{Time.current.to_i}_#{rand(1000)}.py"
    temp_path = python_dir.join(temp_filename)
    
    File.write(temp_path, python_script)
    
    begin
      # Execute Python script and capture output
      Rails.logger.info "Executing Python calculation with Ruby parameters..."
      
      start_time = Time.current
      output = `cd #{python_dir} && python3 #{temp_filename} 2>&1`
      execution_time = Time.current - start_time
      
      Rails.logger.info "Python execution completed in #{execution_time.round(3)} seconds"
      
      # Parse JSON output
      Rails.logger.info "Python script output (first 500 chars): #{output[0..500]}"
      
      json_line = output.split("\n").find { |line| line.strip.start_with?('{') }
      
      if json_line
        Rails.logger.info "Found JSON line, parsing..."
        result = JSON.parse(json_line)
        
        # Convert to Ruby-friendly format
        format_python_result(result, execution_time)
      else
        Rails.logger.error "Full Python script output: #{output}"
        raise StandardError, "Failed to parse Python output: No JSON found"
      end
      
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing failed: #{e.message}"
      Rails.logger.error "Python output: #{output}"
      raise StandardError, "Invalid JSON response from Python script"
    rescue => e
      Rails.logger.error "Python execution failed: #{e.message}"
      raise e
    ensure
      # Clean up temporary file
      File.delete(temp_path) if File.exist?(temp_path)
    end
  end

  private

  def set_default_values
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
  end

  def generate_python_script_with_params
    <<~PYTHON
      import sys
      import json
      import math
      import pandas as pd
      import matplotlib
      matplotlib.use('Agg')  # Use non-interactive backend
      import matplotlib.pyplot as plt
      import numpy as np
      import pprint
      import math
      import numpy_financial as npf
      from core_model_advanced import single_mortgage, accounts_table
      from utils import mean_sd, dollar, pcntdf, pcnt, secant

      # Parameters from Ruby form
      output = {}

      house_value = #{@params[:house_value]}
      loan_duration = #{@params[:loan_duration]}
      annuity_duration = #{@params[:annuity_duration]}
      loan_type = "#{@params[:loan_type]}"
      loan_to_value = #{@params[:loan_to_value]}
      principal_repayment = #{@params[:loan_type] != "Interest only" ? 'True' : 'False'}

      annual_income = #{@params[:annual_income]}
      at_risk_capital_fraction = #{@params[:at_risk_capital_fraction]}

      total_loan = house_value * loan_to_value
      reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan

      annual_house_price_appreciation = #{@params[:annual_house_price_appreciation]}
      insurer_profit_margin = #{@params[:insurer_profit_margin]}
      insurance_profit_margin = 1.0 + insurer_profit_margin

      wholesale_lending_margin = #{@params[:wholesale_lending_margin]}
      additional_loan_margins = #{@params[:additional_loan_margins]}

      holiday_enter_fraction = #{@params[:holiday_enter_fraction]}
      holiday_exit_fraction = #{@params[:holiday_exit_fraction]}
      subperform_loan_threshold_quarters = #{@params[:subperform_loan_threshold_quarters]}
      superpay_start_factor = 1.0
      max_superpay_factor = 1.0

      insurance_cost_pa = #{@params[:insurance_cost_pa]}
      year0 = #{@params[:start_year]}
      hedged = #{@params[:hedged] ? 'True' : 'False'}
      hedging_max_loss = #{@params[:hedging_max_loss]}
      hedging_cap = #{@params[:hedging_cap]}
      hedging_cost_pa = #{@params[:hedging_cost_pa]}

      # Load historical data
      sp500df = pd.read_csv('sp500tr.csv', thousands=',')
      fedfunds = pd.read_csv('FEDFUNDS2.csv')

      all_interest_series = list(map(lambda x: x/100, fedfunds['FEDFUNDS'].values.tolist()))

      sp_prices = sp500df['AdjClose'].values.tolist()
      sp_prices.reverse()

      start_offset = (year0 - 1988)*12

      # Ensure we have enough data
      max_available_months = len(sp_prices)
      max_interest_months = len(all_interest_series)
      required_months = loan_duration * 12

      if start_offset + required_months > max_available_months:
          start_offset = max(0, max_available_months - required_months)

      if start_offset + required_months > max_interest_months:
          start_offset = max(0, max_interest_months - required_months)

      start_offset = max(0, start_offset)

      price_path = sp_prices[start_offset:start_offset+loan_duration*12]
      price_paths=[(0,price_path)]
      interest_series = all_interest_series[start_offset:start_offset+loan_duration*12]

      # Handle case where we don't have enough data
      if len(price_path) == 0:
          price_path = [100] * (loan_duration * 12)
      if len(interest_series) == 0:
          interest_series = [0.04] * (loan_duration * 12)

      dt = 1.0/12
      S0=price_path[0]

      output['sp500df'] = sp500df.to_dict('list')
      output['price_paths'] = price_paths

      insurance_cost = insurance_cost_pa*total_loan*loan_duration

      df= single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                          insurance_profit_margin,insurance_cost,
                          interest_series,wholesale_lending_margin,additional_loan_margins,
                          holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                          price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                          0, None, principal_repayment, hedged, hedging_max_loss,hedging_cap, hedging_cost_pa )
      df["CumAnnuityIncome"] = df["AnnuityIncome"].cumsum()                    
      df["CumInterestAccrued"] = df["Interest"].cumsum()                    
      df["CumInterestPaid"] = df["InterestPaid"].cumsum()                    
      output['pathdf'] = df.to_dict('list')
      output["accounts_table"] = accounts_table(df).to_dict('list')

      output['debug_msgs'] = {'insurance_cost':insurance_cost, "interest": interest_series }

      print(json.dumps(output))
    PYTHON
  end

  def format_python_result(python_result, execution_time)
    {
      main_outputs: generate_main_outputs_from_python(python_result),
      path_data: generate_path_data_from_python(python_result),
      total_paths: 1,
      chart_data: generate_chart_data_from_python(python_result),
      execution_time: execution_time,
      data_source: 'python_historical',
      pathdf: python_result['pathdf'],
      price_paths: python_result['price_paths'],
      accounts_table: python_result['accounts_table'],
      debug_msgs: python_result['debug_msgs']
    }
  end

  def generate_main_outputs_from_python(python_result)
    pathdf = python_result['pathdf']
    return [] unless pathdf

    total_loan = @params[:house_value] * @params[:loan_to_value]
    
    [
      ["Reinvestment fraction", "", "#{((1 - (@params[:annuity_duration] * @params[:annual_income]) / total_loan) * 100).round(1)}%", "", "", "", ""],
      ["Total Income", "TI", "$#{@params[:annual_income] * @params[:annuity_duration]}", "", "", "", ""],
      ["Total Loan", "L", "$#{total_loan.round(0)}", "", "", "", ""],
      ["Insurance Cost", "", "$#{python_result['debug_msgs']['insurance_cost']}", "", "", "", ""],
      ["Final Portfolio", "", "$#{pathdf['Reinvestment']&.last&.round(0) || 'N/A'}", "", "", "", ""],
      ["Cumulative Interest", "", "$#{pathdf['CumInterestAccrued']&.last&.round(0) || 'N/A'}", "", "", "", ""]
    ]
  end

  def generate_path_data_from_python(python_result)
    pathdf = python_result['pathdf']
    return {} unless pathdf

    # Convert Python pathdf to Ruby path data format
    periods = pathdf['Period'] || []
    years = pathdf['Year'] || []
    reinvestment = pathdf['Reinvestment'] || []
    
    mean_data = periods.zip(years, reinvestment).map.with_index do |(period, year, reinvest), i|
      [
        period || i,
        1.0, # placeholder for other metrics
        year || (2000 + i/12.0),
        0, # placeholder
        0, # placeholder  
        0, # placeholder
        0, # placeholder
        reinvest || 0,
        -(reinvest || 0), # net equity approximation
        0, # placeholder
        @params[:annual_income] / 12.0 # monthly income during annuity period
      ]
    end

    { mean: mean_data }
  end

  def generate_chart_data_from_python(python_result)
    pathdf = python_result['pathdf']
    return {} unless pathdf

    {
      portfolio_values: pathdf['Reinvestment'] || [],
      equity_prices: pathdf['SP500'] || [],
      periods: pathdf['Period'] || [],
      years: pathdf['Year'] || []
    }
  end

  def validate_params
    required_params = [:house_value, :loan_duration, :loan_to_value]
    required_params.each do |param|
      raise ArgumentError, "Missing required parameter: #{param}" unless @params[param].present?
    end
  end
end