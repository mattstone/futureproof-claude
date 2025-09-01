#!/usr/bin/env python3

import sys
import json
import math
import pandas as pd
import numpy as np
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths

print("=== DEBUGGING SEED AND SAMPLING BEHAVIOR ===")

# Test different seeds and see if patterns change dramatically
house_value = 1500000
loan_duration = 30
annuity_duration = 15
loan_to_value = 0.8
annual_income = 30000
total_loan = house_value * loan_to_value
reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan
insurance_profit_margin = 1.5
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

equity_return = 0.0975
volatility = 0.15
S0 = 100
cash_rate = 0.04
total_paths = 10

insurance_cost = insurance_cost_pa * total_loan * loan_duration
dt = 1.0/120

# Test different seeds
seeds_to_test = [0, 42, 123, 1000]

for seed in seeds_to_test:
    print(f"\n=== TESTING SEED {seed} ===")
    np.random.seed(seed)
    
    price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)
    
    df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                        insurance_profit_margin, insurance_cost,
                        cash_rate, wholesale_lending_margin, additional_loan_margins,
                        holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                        price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                        0, None, principal_repayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)
    
    # Check final results for all paths
    final_period = 119
    final_rows = df[df['Period'] == final_period]
    
    if len(final_rows) > 0:
        final_reinvestments = final_rows['Reinvestment'].tolist()
        final_sp500 = final_rows['SP500'].tolist()
        
        print(f"  Final reinvestment range: ${min(final_reinvestments):,.0f} to ${max(final_reinvestments):,.0f}")
        print(f"  Final S&P 500 range: ${min(final_sp500):.2f} to ${max(final_sp500):.2f}")
        print(f"  Mean final reinvestment: ${np.mean(final_reinvestments):,.0f}")
        
        # Check path 0 specifically
        path_0_final = df[(df['Path'] == 0) & (df['Period'] == final_period)]
        if not path_0_final.empty:
            r = path_0_final.iloc[0]
            print(f"  Path 0 final: S&P ${r['SP500']:.2f}, Reinvest ${r['Reinvestment']:,.0f}")

# Test how mean calculations work
print(f"\n=== TESTING MEAN CALCULATION METHODS ===")
np.random.seed(42)  # Fixed seed for comparison

price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, 20, S0)

df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin, insurance_cost,
                    cash_rate, wholesale_lending_margin, additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)

# Test different mean calculation approaches
test_periods = [0, 30, 60, 119]
for period in test_periods:
    period_data = df[df['Period'] == period]
    if not period_data.empty:
        reinvestments = period_data['Reinvestment'].tolist()
        sp500_values = period_data['SP500'].tolist()
        
        # Different mean calculation methods
        arithmetic_mean_reinvest = np.mean(reinvestments)
        median_reinvest = np.median(reinvestments) 
        
        print(f"\nPeriod {period}:")
        print(f"  Arithmetic mean reinvestment: ${arithmetic_mean_reinvest:,.0f}")
        print(f"  Median reinvestment: ${median_reinvest:,.0f}")
        print(f"  Min-Max range: ${min(reinvestments):,.0f} to ${max(reinvestments):,.0f}")
        print(f"  S&P 500 mean: ${np.mean(sp500_values):.2f}")

print(f"\n=== POTENTIAL ISSUES TO INVESTIGATE ===")
print("1. Is the reference site using a different default seed?")
print("2. Are we showing mean paths vs individual paths differently?") 
print("3. Is there a different time indexing or period calculation?")
print("4. Are there different portfolio rebalancing rules?")