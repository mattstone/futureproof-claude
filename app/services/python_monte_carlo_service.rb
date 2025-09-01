require 'json'
require 'tempfile'

class PythonMonteCarloService
  def initialize(params)
    @params = params.is_a?(ActionController::Parameters) ? params : params.with_indifferent_access
    set_default_values
    validate_params
  end

  def calculate
    # Create Python Monte Carlo script with Ruby parameters
    python_script = generate_python_monte_carlo_script
    
    # Write script to python directory so imports work
    python_dir = Rails.root.join('python')
    temp_filename = "ruby_monte_carlo_#{Time.current.to_i}_#{rand(1000)}.py"
    temp_path = python_dir.join(temp_filename)
    
    File.write(temp_path, python_script)
    
    begin
      # Execute Python script and capture output
      Rails.logger.info "Executing Python Monte Carlo calculation with #{@params[:total_paths] || 1000} paths..."
      
      start_time = Time.current
      output = `cd #{python_dir} && python3 #{temp_filename} 2>&1`
      execution_time = Time.current - start_time
      
      Rails.logger.info "Python Monte Carlo completed in #{execution_time.round(3)} seconds"
      
      # Parse JSON output
      Rails.logger.info "Python script output (first 500 chars): #{output[0..500]}"
      
      json_line = output.split("\n").find { |line| line.strip.start_with?('{') }
      
      if json_line
        Rails.logger.info "Found JSON line, parsing..."
        result = JSON.parse(json_line)
        
        # Convert to Ruby-friendly format
        format_monte_carlo_result(result, execution_time)
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
    @params[:loan_to_value] = @params[:loan_to_value].present? ? @params[:loan_to_value].to_f / 100.0 : 0.8
    @params[:annual_income] = @params[:annual_income].present? ? @params[:annual_income].to_f : 30000.0
    @params[:at_risk_capital_fraction] = @params[:at_risk_capital_fraction].present? ? @params[:at_risk_capital_fraction].to_f / 100.0 : 0.0
    @params[:equity_return] = @params[:equity_return].present? ? @params[:equity_return].to_f / 100.0 : 0.0975
    @params[:volatility] = @params[:volatility].present? ? @params[:volatility].to_f / 100.0 : 0.15
    @params[:total_paths] = @params[:total_paths].present? ? @params[:total_paths].to_i : 1000
    @params[:random_seed] = @params[:random_seed].present? ? @params[:random_seed].to_i : 0
    @params[:cash_rate] = @params[:cash_rate].present? ? @params[:cash_rate].to_f / 100.0 : 0.04
    @params[:insurer_profit_margin] = @params[:insurer_profit_margin].present? ? @params[:insurer_profit_margin].to_f / 100.0 : 0.5
    @params[:wholesale_lending_margin] = @params[:wholesale_lending_margin].present? ? @params[:wholesale_lending_margin].to_f : 0.02
    @params[:additional_loan_margins] = @params[:additional_loan_margins].present? ? @params[:additional_loan_margins].to_f : 0.015
    @params[:holiday_enter_fraction] = @params[:holiday_enter_fraction].present? ? @params[:holiday_enter_fraction].to_f : 1.35
    @params[:holiday_exit_fraction] = @params[:holiday_exit_fraction].present? ? @params[:holiday_exit_fraction].to_f : 1.95
    @params[:subperform_loan_threshold_quarters] = @params[:subperform_loan_threshold_quarters].present? ? @params[:subperform_loan_threshold_quarters].to_i : 6
    @params[:insurance_cost_pa] = @params[:insurance_cost_pa].present? ? @params[:insurance_cost_pa].to_f : 0.02
    @params[:hedged] = @params[:hedged].present? && @params[:hedged] != "false" && @params[:hedged] != "0" ? true : false
    @params[:hedging_max_loss] = @params[:hedging_max_loss].present? ? @params[:hedging_max_loss].to_f : 0.1
    @params[:hedging_cap] = @params[:hedging_cap].present? ? @params[:hedging_cap].to_f : 0.2
    @params[:hedging_cost_pa] = @params[:hedging_cost_pa].present? ? @params[:hedging_cost_pa].to_f : 0.01
  end

  def generate_python_monte_carlo_script
    <<~PYTHON
      import sys
      import json
      import math
      import pandas as pd
      import numpy as np
      import time
      from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths

      # Set seed for reproducible results
      np.random.seed(#{@params[:random_seed]})

      # Parameters from Ruby form
      house_value = #{@params[:house_value]}
      loan_duration = #{@params[:loan_duration]}
      annuity_duration = #{@params[:annuity_duration]}
      loan_to_value = #{@params[:loan_to_value]}
      annual_income = #{@params[:annual_income]}
      total_loan = house_value * loan_to_value
      reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan
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
      year0 = 2000
      hedged = #{@params[:hedged] ? 'True' : 'False'}
      hedging_max_loss = #{@params[:hedging_max_loss]}
      hedging_cap = #{@params[:hedging_cap]}
      hedging_cost_pa = #{@params[:hedging_cost_pa]}

      # Monte Carlo parameters
      equity_return = #{@params[:equity_return]}
      volatility = #{@params[:volatility]}
      cash_rate = #{@params[:cash_rate]}
      total_paths = #{@params[:total_paths]}

      dt = 1.0/12
      n_steps = loan_duration * 12
      S0 = 100.0

      # Generate Monte Carlo paths  
      start_time = time.time()
      price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)
      path_generation_time = time.time() - start_time

      print(f"Generated {total_paths} paths in {path_generation_time:.3f} seconds")

      # Calculate insurance cost
      insurance_cost = insurance_cost_pa * total_loan * loan_duration

      # Run Monte Carlo simulation (batch processing)
      print(f"Running Monte Carlo simulation with {total_paths} paths...")
      start_time = time.time()
      
      cash_rate_series = [cash_rate] * n_steps
      
      df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                          insurance_profit_margin, insurance_cost,
                          cash_rate_series, wholesale_lending_margin, additional_loan_margins,
                          holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                          price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                          0, None, #{@params[:loan_type] != "Interest only" ? 'True' : 'False'}, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)

      simulation_time = time.time() - start_time
      print(f"Simulation completed in {simulation_time:.3f} seconds")

      # Extract results from batch processing
      # The batch result contains data for all paths combined
      
      # For batch processing, get the final period results for each path
      max_period = loan_duration * 4 - 1  # Last period (0-indexed) 
      
      # Get final reinvestment value for each path and collect all path data for charts
      final_values = []
      sample_paths = []
      all_paths_chart_data = []  # Store reinvestment values for all paths
      all_sp500_paths = []  # Store S&P 500 prices for all paths
      all_loan_paths = []  # Store loan values for all paths
      all_interest_deficit_paths = []  # Store interest deficit for all paths
      all_capital_deficit_paths = []  # Store capital deficit for all paths
      all_cumulative_annuity_paths = []  # Store cumulative annuity income
      all_cumulative_interest_accrued_paths = []  # Store cumulative interest accrued
      all_cumulative_interest_paid_paths = []  # Store cumulative interest paid
      all_surplus_paths = []  # Store surplus for all paths
      all_units_paths = []  # Store units for all paths
      all_pooled_units_paths = []  # Store pooled units for all paths
      all_insured_units_paths = []  # Store insured units (static)
      all_hedged_units_paths = []  # Store hedged units delta
      
      # Aggregate data for mean calculation
      periods_data = {}
      
      for path_id in range(total_paths):
          path_data = df[df['Path'] == path_id]
          if len(path_data) > 0:
              # Get final reinvestment value for this path
              final_row = path_data[path_data['Period'] == max_period]
              if len(final_row) > 0:
                  final_value = final_row['Reinvestment'].iloc[0]
                  final_values.append(final_value)
              else:
                  # Fallback to last available period
                  fallback_value = path_data['Reinvestment'].iloc[-1]
                  final_values.append(fallback_value)
              
              # Collect data for all paths for charting
              path_reinvestment = path_data['Reinvestment'].tolist()
              path_sp500 = path_data['SP500'].tolist()
              path_loan = path_data['Loan size'].tolist()
              path_interest_deficit = path_data['InterestDeficit'].tolist()
              path_capital_deficit = path_data['CapitalDeficit'].tolist()
              path_surplus = path_data['Surplus'].tolist()
              path_units = path_data['Units'].tolist()
              path_cumulative_annuity = path_data['AnnuityIncome'].cumsum().tolist()
              path_cumulative_interest_paid = path_data['CumInterestPaid'].tolist()
              path_pooled_units = path_data['CumUnitsToPool'].tolist()
              path_hedged_units = path_data['HedgeUnitsDelta'].tolist()
              
              all_paths_chart_data.append(path_reinvestment)
              all_sp500_paths.append(path_sp500)
              all_loan_paths.append(path_loan)
              all_interest_deficit_paths.append(path_interest_deficit)
              all_capital_deficit_paths.append(path_capital_deficit)
              all_surplus_paths.append(path_surplus)
              all_units_paths.append(path_units)
              all_cumulative_annuity_paths.append(path_cumulative_annuity)
              all_cumulative_interest_paid_paths.append(path_cumulative_interest_paid)
              all_pooled_units_paths.append(path_pooled_units)
              all_hedged_units_paths.append(path_hedged_units)
              
              # Aggregate for mean calculation
              for i, period in enumerate(path_data['Period']):
                  if period not in periods_data:
                      periods_data[period] = []
                  periods_data[period].append({
                      'Period': period,
                      'Year': path_data.iloc[i]['Year'],
                      'Quarter': path_data.iloc[i]['Quarter'],
                      'SP500': path_data.iloc[i]['SP500'],
                      'Interest': path_data.iloc[i]['Interest'],
                      'Loan size': path_data.iloc[i]['Loan size'],
                      'Units': path_data.iloc[i]['Units'],
                      'Reinvestment': path_data.iloc[i]['Reinvestment'],
                      'InterestDeficit': path_data.iloc[i]['InterestDeficit'],
                      'CapitalDeficit': path_data.iloc[i]['CapitalDeficit'],
                      'Surplus': path_data.iloc[i]['Surplus'],
                      'FunderEarned': path_data.iloc[i]['FunderEarned'],
                      'AnnuityIncome': path_data.iloc[i]['AnnuityIncome'],
                      'CumInterestPaid': path_data.iloc[i]['CumInterestPaid'],
                      'CumUnitsToPool': path_data.iloc[i]['CumUnitsToPool'],
                      'HedgeUnitsDelta': path_data.iloc[i]['HedgeUnitsDelta']
                  })
              
              # Save first few paths for detailed data
              if path_id < 5:
                  sample_paths.append({
                      'path_id': path_id,
                      'pathdf': path_data.to_dict('list')
                  })
      
      print(f"Final values extracted: {len(final_values)} values")
      
      # Calculate mean path data
      mean_path_data = []
      median_path_data = []
      percentile_2_data = []
      percentile_25_data = []
      percentile_75_data = []
      
      for period in sorted(periods_data.keys()):
          period_values = periods_data[period]
          if period_values:
              # Calculate mean values for this period
              mean_values = {}
              for key in period_values[0].keys():
                  if key in ['Period', 'Year', 'Quarter']:
                      mean_values[key] = period_values[0][key]  # These should be the same across paths
                  else:
                      values = [pv[key] for pv in period_values if pv[key] is not None]
                      if values:
                          mean_values[key] = np.mean(values)
                          # Calculate percentiles for key metrics
                          if key == 'Reinvestment':
                              percentiles = np.percentile(values, [2, 25, 50, 75])
                              if len(percentile_2_data) == len(mean_path_data):
                                  percentile_2_data.append(dict(mean_values, **{key: percentiles[0]}))
                                  percentile_25_data.append(dict(mean_values, **{key: percentiles[1]}))
                                  median_path_data.append(dict(mean_values, **{key: percentiles[2]}))
                                  percentile_75_data.append(dict(mean_values, **{key: percentiles[3]}))
                      else:
                          mean_values[key] = 0
              
              mean_path_data.append(mean_values)
      
      print(f"Mean path data calculated: {len(mean_path_data)} periods")

      # Calculate statistics
      mean_final = np.mean(final_values)
      std_final = np.std(final_values)
      percentiles = np.percentile(final_values, [2, 25, 50, 75, 98])

      # Prepare output
      output = {
          'total_paths': total_paths,
          'mean_final_reinvestment': mean_final,
          'std_final_reinvestment': std_final,
          'percentile_2': percentiles[0],
          'percentile_25': percentiles[1],
          'percentile_50': percentiles[2],
          'percentile_75': percentiles[3],
          'percentile_98': percentiles[4],
          'all_final_values': final_values,
          'all_paths_chart_data': all_paths_chart_data,
          'all_sp500_paths': all_sp500_paths,
          'all_loan_paths': all_loan_paths,
          'all_interest_deficit_paths': all_interest_deficit_paths,
          'all_capital_deficit_paths': all_capital_deficit_paths,
          'all_surplus_paths': all_surplus_paths,
          'all_units_paths': all_units_paths,
          'all_cumulative_annuity_paths': all_cumulative_annuity_paths,
          'all_cumulative_interest_paid_paths': all_cumulative_interest_paid_paths,
          'all_pooled_units_paths': all_pooled_units_paths,
          'all_hedged_units_paths': all_hedged_units_paths,
          'mean_path_data': mean_path_data,
          'median_path_data': median_path_data,
          'percentile_2_data': percentile_2_data,
          'percentile_25_data': percentile_25_data,
          'percentile_75_data': percentile_75_data,
          'sample_paths': sample_paths,
          'path_generation_time': path_generation_time,
          'simulation_time': simulation_time,
          'total_execution_time': path_generation_time + simulation_time,
          'parameters': {
              'house_value': house_value,
              'loan_duration': loan_duration,
              'annuity_duration': annuity_duration,
              'loan_to_value': loan_to_value,
              'annual_income': annual_income,
              'equity_return': equity_return,
              'volatility': volatility,
              'cash_rate': cash_rate,
              'total_paths': total_paths
          }
      }

      print(json.dumps(output))
    PYTHON
  end

  def format_monte_carlo_result(python_result, execution_time)
    {
      main_outputs: generate_monte_carlo_main_outputs(python_result),
      path_data: generate_monte_carlo_path_data(python_result),
      total_paths: python_result['total_paths'],
      chart_data: generate_monte_carlo_chart_data(python_result),
      execution_time: execution_time,
      data_source: 'python_monte_carlo',
      parameters: python_result['parameters'] || {
        volatility: @params[:volatility],
        equity_return: @params[:equity_return],
        cash_rate: @params[:cash_rate],
        house_value: @params[:house_value],
        loan_duration: @params[:loan_duration],
        annuity_duration: @params[:annuity_duration],
        total_paths: @params[:total_paths]
      },
      statistics: {
        mean: python_result['mean_final_reinvestment'],
        std: python_result['std_final_reinvestment'],
        percentiles: {
          p2: python_result['percentile_2'],
          p25: python_result['percentile_25'],
          p50: python_result['percentile_50'],
          p75: python_result['percentile_75'],
          p98: python_result['percentile_98']
        }
      },
      all_final_values: python_result['all_final_values'],
      sample_paths: python_result['sample_paths']
    }
  end

  def generate_monte_carlo_main_outputs(python_result)
    total_loan = @params[:house_value] * @params[:loan_to_value]
    
    [
      ["Reinvestment fraction", "", "#{((1 - (@params[:annuity_duration] * @params[:annual_income]) / total_loan) * 100).round(1)}%", "", "", "", ""],
      ["Total Income", "TI", "$#{@params[:annual_income] * @params[:annuity_duration]}", "", "", "", ""],
      ["Total Loan", "L", "$#{total_loan.round(0)}", "", "", "", ""],
      ["Insurance Cost", "", "$#{@params[:insurance_cost_pa] * total_loan * @params[:loan_duration]}", "", "", "", ""],
      ["Reinvestment value", "R", 
       "$#{python_result['mean_final_reinvestment'].round(0)}", 
       "$#{python_result['percentile_2'].round(0)}", 
       "$#{python_result['percentile_25'].round(0)}", 
       "$#{python_result['percentile_50'].round(0)}", 
       "$#{python_result['percentile_75'].round(0)}"],
      ["Standard Deviation", "", "$#{python_result['std_final_reinvestment'].round(0)}", "", "", "", ""],
      ["Total Paths", "", "#{python_result['total_paths']}", "", "", "", ""]
    ]
  end

  def generate_monte_carlo_path_data(python_result)
    # Use mean path data from Python if available
    mean_path_data = python_result['mean_path_data'] || []
    median_path_data = python_result['median_path_data'] || []
    percentile_2_data = python_result['percentile_2_data'] || []
    percentile_25_data = python_result['percentile_25_data'] || []
    percentile_75_data = python_result['percentile_75_data'] || []
    
    if mean_path_data.empty?
      sample_paths = python_result['sample_paths'] || []
      return { mean: [] } if sample_paths.empty?

      # Fallback to first sample path for structure
      first_path = sample_paths[0]['pathdf']
      periods = first_path['Period'] || []
      years = first_path['Year'] || []
      reinvestment = first_path['Reinvestment'] || []
      
      mean_data = periods.zip(years, reinvestment).map.with_index do |(period, year, reinvest), i|
        [
          period || i,
          1.0, # SP500
          year || (2000 + i/12.0), # Interest
          0, # Loan size
          reinvest || 0, # Units
          0, # Reinvestment
          0, # InterestDeficit
          0, # CapitalDeficit
          reinvest || 0, # Surplus
          0, # FunderEarned
          i < (@params[:annuity_duration] * 12) ? @params[:annual_income] / 12.0 : 0 # AnnuityIncome
        ]
      end
      return { mean: mean_data }
    end
    
    # Convert Python mean path data to format expected by frontend
    convert_path_data = lambda do |path_data|
      path_data.map do |row|
        [
          row['Period'] || 0,
          row['SP500'] || 100,
          row['Interest'] || 0,
          row['Loan size'] || 0,
          row['Units'] || 0,
          row['Reinvestment'] || 0,
          row['InterestDeficit'] || 0,
          row['CapitalDeficit'] || 0,
          row['Surplus'] || 0,
          row['FunderEarned'] || 0,
          row['AnnuityIncome'] || 0
        ]
      end
    end
    
    {
      mean: convert_path_data.call(mean_path_data),
      median: convert_path_data.call(median_path_data),
      percentile_2: convert_path_data.call(percentile_2_data),
      percentile_25: convert_path_data.call(percentile_25_data),
      percentile_75: convert_path_data.call(percentile_75_data)
    }
  end

  def generate_monte_carlo_chart_data(python_result)
    sample_paths = python_result['sample_paths'] || []
    all_final_values = python_result['all_final_values'] || []
    
    # Use the comprehensive chart data from Python script
    all_reinvestment_paths = python_result['all_paths_chart_data'] || []
    all_sp500_paths = python_result['all_sp500_paths'] || []
    all_loan_paths = python_result['all_loan_paths'] || []
    all_interest_deficit_paths = python_result['all_interest_deficit_paths'] || []
    all_capital_deficit_paths = python_result['all_capital_deficit_paths'] || []
    all_surplus_paths = python_result['all_surplus_paths'] || []
    all_units_paths = python_result['all_units_paths'] || []
    all_cumulative_annuity_paths = python_result['all_cumulative_annuity_paths'] || []
    all_cumulative_interest_paid_paths = python_result['all_cumulative_interest_paid_paths'] || []
    all_pooled_units_paths = python_result['all_pooled_units_paths'] || []
    all_hedged_units_paths = python_result['all_hedged_units_paths'] || []
    
    # Fallback to sample paths if chart data is not available  
    if all_reinvestment_paths.empty?
      sample_paths.each do |path_info|
        path_data = path_info['pathdf']
        if path_data && path_data['Reinvestment']
          all_reinvestment_paths << path_data['Reinvestment']
          all_sp500_paths << (path_data['SP500'] || [])
          all_loan_paths << (path_data['Loan size'] || [])
        end
      end
    end
    
    Rails.logger.info "Chart data: #{all_reinvestment_paths.size} paths available for visualization"
    
    # Calculate mean paths for charts
    mean_sp500_path = calculate_mean_path(all_sp500_paths)
    mean_reinvestment_path = calculate_mean_path(all_reinvestment_paths)
    mean_loan_path = calculate_mean_path(all_loan_paths)
    mean_interest_deficit_path = calculate_mean_path(all_interest_deficit_paths)
    mean_capital_deficit_path = calculate_mean_path(all_capital_deficit_paths)
    mean_surplus_path = calculate_mean_path(all_surplus_paths)
    mean_units_path = calculate_mean_path(all_units_paths)
    mean_cumulative_annuity_path = calculate_mean_path(all_cumulative_annuity_paths)
    mean_cumulative_interest_paid_path = calculate_mean_path(all_cumulative_interest_paid_paths)
    mean_pooled_units_path = calculate_mean_path(all_pooled_units_paths)
    mean_hedged_units_path = calculate_mean_path(all_hedged_units_paths)
    
    chart_data = {
      # Original data
      portfolio_values: [],
      equity_prices: [],
      periods: [],
      years: [],
      final_value_distribution: all_final_values,
      all_paths: all_reinvestment_paths,
      
      # New comprehensive chart data
      all_sp500_paths: all_sp500_paths,
      all_loan_paths: all_loan_paths,
      all_interest_deficit_paths: all_interest_deficit_paths,
      all_capital_deficit_paths: all_capital_deficit_paths,
      all_surplus_paths: all_surplus_paths,
      all_units_paths: all_units_paths,
      all_cumulative_annuity_paths: all_cumulative_annuity_paths,
      all_cumulative_interest_paid_paths: all_cumulative_interest_paid_paths,
      all_pooled_units_paths: all_pooled_units_paths,
      all_hedged_units_paths: all_hedged_units_paths,
      
      # Mean paths for main chart displays
      mean_sp500_path: mean_sp500_path,
      mean_reinvestment_path: mean_reinvestment_path,
      mean_loan_path: mean_loan_path,
      mean_interest_deficit_path: mean_interest_deficit_path,
      mean_capital_deficit_path: mean_capital_deficit_path,
      mean_surplus_path: mean_surplus_path,
      mean_units_path: mean_units_path,
      mean_cumulative_annuity_path: mean_cumulative_annuity_path,
      mean_cumulative_interest_paid_path: mean_cumulative_interest_paid_path,
      mean_pooled_units_path: mean_pooled_units_path,
      mean_hedged_units_path: mean_hedged_units_path
    }

    # Set default single path data from first sample if available
    if sample_paths.any?
      first_path = sample_paths[0]['pathdf']
      chart_data[:portfolio_values] = first_path['Reinvestment'] || []
      chart_data[:equity_prices] = first_path['SP500'] || []
      chart_data[:periods] = first_path['Period'] || []
      chart_data[:years] = first_path['Year'] || []
    elsif all_reinvestment_paths.any?
      chart_data[:portfolio_values] = all_reinvestment_paths[0] || []
      chart_data[:equity_prices] = all_sp500_paths[0] || []
      chart_data[:periods] = (0...chart_data[:portfolio_values].length).to_a
      chart_data[:years] = chart_data[:periods].map { |p| 2000 + p / 4.0 }
    end

    chart_data
  end
  
  private
  
  def calculate_mean_path(all_paths)
    return [] if all_paths.empty? || all_paths.first.nil?
    
    max_length = all_paths.map(&:length).max || 0
    mean_path = []
    
    (0...max_length).each do |i|
      values_at_period = all_paths.filter_map { |path| path[i] if path.length > i }
      mean_path << (values_at_period.empty? ? 0 : values_at_period.sum.to_f / values_at_period.length)
    end
    
    mean_path
  end

  def validate_params
    required_params = [:house_value, :loan_duration, :loan_to_value]
    required_params.each do |param|
      raise ArgumentError, "Missing required parameter: #{param}" unless @params[param].present?
    end
  end
end