import sys
import json
import math
import pandas as pd
import numpy as np
import time
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths

# Set seed for reproducible results
np.random.seed(42)

# Same parameters but with 1000 paths to test "quite a few" Monte Carlo simulations
house_value = 1500000
loan_duration = 30
annuity_duration = 15
loan_to_value = 0.8
annual_income = 30000
total_loan = house_value * loan_to_value
reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan
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

# Monte Carlo parameters - TEST WITH 1000 PATHS
equity_return = 0.0975
volatility = 0.15
S0 = 100
cash_rate = 0.04
total_paths = 1000

print(f"=== MONTE CARLO OPTIMIZATION TEST: {total_paths} PATHS ===")

# Test vectorized path generation performance
print("Generating Monte Carlo paths (vectorized)...")
start_time = time.time()
price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)
path_gen_time = time.time() - start_time
print(f"Path generation time: {path_gen_time:.3f}s")
print(f"Path generation rate: {total_paths/path_gen_time:.1f} paths/second")

# Test optimized simulation performance
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
total_time = path_gen_time + sim_time

print(f"Simulation time: {sim_time:.3f}s")
print(f"Total time: {total_time:.3f}s")
print(f"Simulation rate: {total_paths/sim_time:.1f} paths/second")
print(f"Total rate: {total_paths/total_time:.1f} paths/second")

# Quick results summary
dfend = df[df['Period'] == loan_duration * 4]
mean_reinvestment = dfend['Reinvestment'].mean()
std_reinvestment = dfend['Reinvestment'].std()
mean_deficit = dfend['InterestDeficit'].mean()
total_holiday_quarters = df['Prob Holiday'].sum()

print(f"\n=== RESULTS SUMMARY ({total_paths} paths) ===")
print(f"Mean final reinvestment: ${mean_reinvestment:,.0f}")
print(f"Std final reinvestment: ${std_reinvestment:,.0f}")
print(f"Mean final deficit: ${mean_deficit:,.0f}")
print(f"Total holiday quarters: {total_holiday_quarters:,.0f}")
print(f"Average holiday rate: {total_holiday_quarters/(total_paths*loan_duration*4)*100:.1f}%")

# Performance comparison with 100-path baseline
baseline_rate = 1032.5  # From baseline test
performance_improvement = (total_paths/sim_time) / baseline_rate
print(f"\n=== PERFORMANCE vs BASELINE ===")
print(f"Baseline performance: {baseline_rate:.1f} paths/second (100 paths)")
print(f"Optimized performance: {total_paths/sim_time:.1f} paths/second ({total_paths} paths)")
print(f"Performance ratio: {performance_improvement:.2f}x")
print(f"Estimated time for {total_paths} paths with baseline: {total_paths/baseline_rate:.1f}s")
print(f"Actual time with optimizations: {sim_time:.1f}s")
print(f"Time saved: {total_paths/baseline_rate - sim_time:.1f}s ({((total_paths/baseline_rate - sim_time)/(total_paths/baseline_rate))*100:.1f}% faster)")