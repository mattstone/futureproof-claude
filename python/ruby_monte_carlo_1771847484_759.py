import sys
import json
import math
import pandas as pd
import numpy as np
import time
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths

# Set seed for reproducible results
np.random.seed(0)

# Parameters from Ruby form
house_value = 1500000.0
loan_duration = 30
annuity_duration = 15
loan_to_value = 0.8
annual_income = 30000.0
total_loan = house_value * loan_to_value
reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan
insurer_profit_margin = 0.5
insurance_profit_margin = 1.0 + insurer_profit_margin
wholesale_lending_margin = 0.02
additional_loan_margins = 0.015
holiday_enter_fraction = 1.35
holiday_exit_fraction = 1.95
subperform_loan_threshold_quarters = 6
superpay_start_factor = 1.0
max_superpay_factor = 1.0
insurance_cost_pa = 0.02
year0 = 2000
hedged = False
hedging_max_loss = 0.1
hedging_cap = 0.2
hedging_cost_pa = 0.01

# Monte Carlo parameters
equity_return = 0.0975
volatility = 0.15
cash_rate = 0.04
total_paths = 1000

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
                    0, None, False, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)

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
