#!/usr/bin/env python3

import sys
import json
import math
import pandas as pd
import numpy as np
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths

print("=== TESTING SEED 0 vs DEFAULT BEHAVIOR ===")

# Standard parameters
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
total_paths = 100

insurance_cost = insurance_cost_pa * total_loan * loan_duration
dt = 1.0/120

# Test seed 0 (form default)
print("\n=== FORM DEFAULT: SEED 0 ===")
np.random.seed(0)

price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)

df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin, insurance_cost,
                    cash_rate, wholesale_lending_margin, additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)

# Analyze results like we do in Rails
final_period = 119
final_rows = df[df['Period'] == final_period]
final_reinvestments = final_rows['Reinvestment'].tolist()
final_sp500 = final_rows['SP500'].tolist()

print(f"Final reinvestment stats:")
print(f"  Mean: ${np.mean(final_reinvestments):,.0f}")
print(f"  Median: ${np.median(final_reinvestments):,.0f}")
print(f"  Std: ${np.std(final_reinvestments):,.0f}")
print(f"  Range: ${min(final_reinvestments):,.0f} to ${max(final_reinvestments):,.0f}")

print(f"Final S&P 500 stats:")
print(f"  Mean: ${np.mean(final_sp500):.2f}")
print(f"  Range: ${min(final_sp500):.2f} to ${max(final_sp500):.2f}")

# Calculate mean paths for charting (like our Rails service does)
periods_data = {}
for path_id in range(total_paths):
    path_data = df[df['Path'] == path_id]
    for i, period in enumerate(path_data['Period']):
        if period not in periods_data:
            periods_data[period] = []
        periods_data[period].append({
            'Period': period,
            'SP500': path_data.iloc[i]['SP500'],
            'Reinvestment': path_data.iloc[i]['Reinvestment'],
            'Loan size': path_data.iloc[i]['Loan size'],
        })

# Calculate mean values for key periods
key_periods = [0, 30, 60, 90, 119]
print(f"\nMean path data (seed 0):")
for period in key_periods:
    if period in periods_data:
        period_values = periods_data[period]
        mean_sp500 = np.mean([pv['SP500'] for pv in period_values])
        mean_reinvest = np.mean([pv['Reinvestment'] for pv in period_values])
        mean_loan = np.mean([pv['Loan size'] for pv in period_values])
        
        print(f"  Period {period}: S&P ${mean_sp500:.2f}, Reinvest ${mean_reinvest:,.0f}, Loan ${mean_loan:,.0f}")

print(f"\n=== COMPARISON WITH REFERENCE SITE EXPECTATIONS ===")
print("If the reference site uses seed 0, we should expect:")
print("1. More conservative S&P 500 growth (not reaching $4000+)")
print("2. Lower reinvestment values")
print("3. More predictable/stable patterns")
print("4. Less extreme outliers in the distribution")

print(f"\n=== CONCLUSION ===")
print("The major differences in chart patterns could be due to:")
print("1. Random seed differences (0 vs 42 vs truly random)")
print("2. Different mean vs median path calculations")
print("3. Different path sampling or aggregation methods")
print("4. These results with seed 0 should be closer to reference site")