import sys
import json
import math
import pandas as pd
import numpy as np
import time
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths
from utils import mean_sd, dollar, pcntdf, pcnt, secant

# Set seed for reproducible results
np.random.seed(42)

# Exact same parameters as baseline test
house_value = 1500000
loan_duration = 30
annuity_duration = 15
loan_type = "Interest only"
loan_to_value = 0.8
annual_income = 30000
at_risk_captital_fraction = 0.0
total_loan = house_value * loan_to_value
reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan
annual_house_price_appreciation = 0.04
insurer_profit_margin = 0.5
insurance_profit_margin = 1.0+ insurer_profit_margin
wholesale_lending_margin = 0.02
additional_loan_margins = 0.015
holiday_enter_fraction = 1.35
holiday_exit_fraction = 1.95
subperform_loan_threshold_quarters = 6
superpay_start_factor = 1.0
max_superpay_factor = 1.0
insurance_cost_pa = 0.02
year0 = 2000
principal_repayment = False
hedged = False
hedging_max_loss = 0.1
hedging_cap = 0.2
hedging_cost_pa = 0.01

# Monte Carlo parameters
equity_return = 0.0975
volatility = 0.15
S0 = 100
cash_rate = 0.04
total_paths = 100

# Generate Monte Carlo paths with vectorized generation
print("Generating Monte Carlo paths (vectorized)...")
start_time = time.time()
price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)
path_gen_time = time.time() - start_time
print(f"Path generation time: {path_gen_time:.3f}s")

# Run simulation with optimized core model
print("Running Monte Carlo simulation (optimized)...")
insurance_cost = insurance_cost_pa * total_loan * loan_duration
dt = 1.0/120

start_time = time.time()
df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin, insurance_cost,
                    cash_rate, wholesale_lending_margin, additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)
sim_time = time.time() - start_time
print(f"Simulation time: {sim_time:.3f}s")
print(f"Total time: {path_gen_time + sim_time:.3f}s")

# Create test metrics using same structure as baseline
test_metrics = {}

# Per-path final metrics
dfend = df[df['Period'] == loan_duration * 4]
test_metrics['final_reinvestments'] = dfend['Reinvestment'].tolist()
test_metrics['final_deficits'] = dfend['InterestDeficit'].tolist() 
test_metrics['final_surpluses'] = dfend['Surplus'].tolist()
test_metrics['total_paths'] = len(dfend)

# Aggregate metrics
test_metrics['mean_final_reinvestment'] = dfend['Reinvestment'].mean()
test_metrics['std_final_reinvestment'] = dfend['Reinvestment'].std()
test_metrics['mean_final_deficit'] = dfend['InterestDeficit'].mean()
test_metrics['std_final_deficit'] = dfend['InterestDeficit'].std()

# Time series metrics
quarterly_data = df[df['Period'] % 4 == 0].copy()
test_metrics['quarterly_reinvestments'] = quarterly_data.groupby('Period')['Reinvestment'].mean().tolist()
test_metrics['quarterly_deficits'] = quarterly_data.groupby('Period')['InterestDeficit'].mean().tolist()

# Holiday statistics
test_metrics['total_holiday_quarters'] = df['Prob Holiday'].sum()
test_metrics['pct_quarters_on_holiday'] = df['Prob Holiday'].mean()

# Interest payments
test_metrics['total_interest_paid'] = df['InterestPaid'].sum()
test_metrics['mean_interest_per_path'] = df.groupby('Path')['InterestPaid'].sum().mean()

# Path-specific metrics
path_metrics = []
for path in range(total_paths):
    path_df = df[df['Path'] == path]
    path_final = path_df[path_df['Period'] == loan_duration * 4].iloc[0]
    path_metrics.append({
        'path': path,
        'final_reinvestment': path_final['Reinvestment'],
        'final_deficit': path_final['InterestDeficit'],
        'final_surplus': path_final['Surplus'],
        'total_interest_paid': path_df['InterestPaid'].sum(),
        'holiday_quarters': path_df['Prob Holiday'].sum()
    })

test_metrics['path_details'] = path_metrics

# Performance metrics
test_metrics['performance'] = {
    'path_generation_time': path_gen_time,
    'simulation_time': sim_time,
    'total_time': path_gen_time + sim_time,
    'paths_per_second': total_paths / sim_time
}

# Save test results
with open('montecarlo_optimized_test.json', 'w') as f:
    json.dump(test_metrics, f, indent=2, default=str)

print(f"\n=== MONTE CARLO OPTIMIZED TEST RESULTS ===")
print(f"Total paths: {total_paths}")
print(f"Mean final reinvestment: ${test_metrics['mean_final_reinvestment']:,.0f}")
print(f"Std final reinvestment: ${test_metrics['std_final_reinvestment']:,.0f}")
print(f"Mean final deficit: ${test_metrics['mean_final_deficit']:,.0f}")
print(f"Total holiday quarters: {test_metrics['total_holiday_quarters']:,.0f}")
print(f"Performance: {test_metrics['performance']['paths_per_second']:.1f} paths/second")
print(f"Test results saved to montecarlo_optimized_test.json")