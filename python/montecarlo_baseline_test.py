import sys
import json
import math
import pandas as pd
import numpy as np
import time
from core_model import single_mortgage, gen_monte_carlo_paths
from utils import mean_sd, dollar, pcntdf, pcnt, secant

# Set seed for reproducible results in testing
np.random.seed(42)

# Internal input variables for Monte Carlo testing
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
total_paths = 100  # Test with 100 paths for comprehensive baseline

# Generate Monte Carlo paths
print("Generating Monte Carlo paths...")
start_time = time.time()
price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)
path_gen_time = time.time() - start_time
print(f"Path generation time: {path_gen_time:.3f}s")

# Run simulation
print("Running Monte Carlo simulation...")
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

# Create comprehensive baseline metrics
baseline_metrics = {}

# Per-path final metrics
dfend = df[df['Period'] == loan_duration * 4]
baseline_metrics['final_reinvestments'] = dfend['Reinvestment'].tolist()
baseline_metrics['final_deficits'] = dfend['InterestDeficit'].tolist() 
baseline_metrics['final_surpluses'] = dfend['Surplus'].tolist()
baseline_metrics['total_paths'] = len(dfend)

# Aggregate metrics
baseline_metrics['mean_final_reinvestment'] = dfend['Reinvestment'].mean()
baseline_metrics['std_final_reinvestment'] = dfend['Reinvestment'].std()
baseline_metrics['mean_final_deficit'] = dfend['InterestDeficit'].mean()
baseline_metrics['std_final_deficit'] = dfend['InterestDeficit'].std()

# Time series metrics (sample every 4th period for quarterly data)
quarterly_data = df[df['Period'] % 4 == 0].copy()
baseline_metrics['quarterly_reinvestments'] = quarterly_data.groupby('Period')['Reinvestment'].mean().tolist()
baseline_metrics['quarterly_deficits'] = quarterly_data.groupby('Period')['InterestDeficit'].mean().tolist()

# Holiday statistics
baseline_metrics['total_holiday_quarters'] = df['Prob Holiday'].sum()
baseline_metrics['pct_quarters_on_holiday'] = df['Prob Holiday'].mean()

# Interest payments
baseline_metrics['total_interest_paid'] = df['InterestPaid'].sum()
baseline_metrics['mean_interest_per_path'] = df.groupby('Path')['InterestPaid'].sum().mean()

# Path-specific metrics for detailed comparison
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

baseline_metrics['path_details'] = path_metrics

# Performance metrics
baseline_metrics['performance'] = {
    'path_generation_time': path_gen_time,
    'simulation_time': sim_time,
    'total_time': path_gen_time + sim_time,
    'paths_per_second': total_paths / sim_time
}

# Save comprehensive baseline
with open('montecarlo_baseline.json', 'w') as f:
    json.dump(baseline_metrics, f, indent=2, default=str)

print(f"\n=== MONTE CARLO BASELINE ESTABLISHED ===")
print(f"Total paths: {total_paths}")
print(f"Mean final reinvestment: ${baseline_metrics['mean_final_reinvestment']:,.0f}")
print(f"Std final reinvestment: ${baseline_metrics['std_final_reinvestment']:,.0f}")
print(f"Mean final deficit: ${baseline_metrics['mean_final_deficit']:,.0f}")
print(f"Total holiday quarters: {baseline_metrics['total_holiday_quarters']:,.0f}")
print(f"Performance: {baseline_metrics['performance']['paths_per_second']:.1f} paths/second")
print(f"Baseline saved to montecarlo_baseline.json")