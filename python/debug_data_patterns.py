#!/usr/bin/env python3

import sys
import json
import math
import pandas as pd
import numpy as np
import time
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths

# Set seed for reproducible results
np.random.seed(42)

# Standard parameters matching our web form defaults
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

# Monte Carlo parameters - smaller set for debugging
equity_return = 0.0975
volatility = 0.15
S0 = 100
cash_rate = 0.04
total_paths = 10

print(f"=== DATA PATTERN DEBUGGING ({total_paths} PATHS) ===")
print(f"House value: ${house_value:,}")
print(f"Total loan: ${total_loan:,}")
print(f"Annual income: ${annual_income:,}")
print(f"Loan duration: {loan_duration} years ({loan_duration*4} quarters)")
print(f"Reinvest fraction: {reinvest_fraction:.3f}")

# Generate Monte Carlo paths
price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)
insurance_cost = insurance_cost_pa * total_loan * loan_duration
dt = 1.0/120

# Run simulation
df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin, insurance_cost,
                    cash_rate, wholesale_lending_margin, additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)

print(f"\nDataFrame shape: {df.shape}")
print(f"Columns: {list(df.columns)}")

# Analyze first path data patterns
path_0 = df[df['Path'] == 0].copy()
print(f"\n=== PATH 0 DATA PATTERNS ===")
print(f"Path length: {len(path_0)} periods")
print(f"Period range: {path_0['Period'].min()} to {path_0['Period'].max()}")

# Check key metrics at different time points
checkpoints = [0, 40, 80, 119]  # Start, 10 years, 20 years, end
for period in checkpoints:
    row = path_0[path_0['Period'] == period]
    if not row.empty:
        r = row.iloc[0]
        print(f"\n--- Period {period} (Year {r['Year']:.1f}) ---")
        print(f"  S&P 500: ${r['SP500']:.2f}")
        print(f"  Loan size: ${r['Loan size']:,.0f}")
        print(f"  Reinvestment: ${r['Reinvestment']:,.0f}")
        print(f"  Interest Deficit: ${r['InterestDeficit']:,.0f}")
        print(f"  Units: {r['Units']:,.0f}")
        if 'CumInterestPaid' in r:
            print(f"  Cumulative Interest Paid: ${r['CumInterestPaid']:,.0f}")
        if 'CumUnitsToPool' in r:
            print(f"  Pooled Units: {r['CumUnitsToPool']:,.0f}")

# Check S&P 500 path patterns
print(f"\n=== S&P 500 PATTERNS ===")
sp500_values = path_0['SP500'].tolist()
print(f"S&P 500 starts at: ${sp500_values[0]:.2f}")
print(f"S&P 500 ends at: ${sp500_values[-1]:.2f}")
print(f"S&P 500 min: ${min(sp500_values):.2f}")
print(f"S&P 500 max: ${max(sp500_values):.2f}")
print(f"S&P 500 growth: {((sp500_values[-1]/sp500_values[0])-1)*100:.1f}%")

# Check reinvestment patterns
print(f"\n=== REINVESTMENT PATTERNS ===")
reinvest_values = path_0['Reinvestment'].tolist()
print(f"Reinvestment starts at: ${reinvest_values[0]:,.0f}")
print(f"Reinvestment ends at: ${reinvest_values[-1]:,.0f}")
print(f"Reinvestment min: ${min(reinvest_values):,.0f}")
print(f"Reinvestment max: ${max(reinvest_values):,.0f}")

# Check loan patterns
print(f"\n=== LOAN PATTERNS ===")
loan_values = path_0['Loan size'].tolist()
print(f"Loan starts at: ${loan_values[0]:,.0f}")
print(f"Loan ends at: ${loan_values[-1]:,.0f}")
print(f"Loan min: ${min(loan_values):,.0f}")
print(f"Loan max: ${max(loan_values):,.0f}")

# Check if there are negative values or strange patterns
print(f"\n=== DATA QUALITY CHECKS ===")
print(f"Any negative S&P 500: {any(v < 0 for v in sp500_values)}")
print(f"Any negative reinvestment: {any(v < 0 for v in reinvest_values)}")
print(f"Any negative loan: {any(v < 0 for v in loan_values)}")

# Check units patterns if available
if 'Units' in path_0.columns:
    units_values = path_0['Units'].tolist()
    print(f"Units start: {units_values[0]:,.0f}")
    print(f"Units end: {units_values[-1]:,.0f}")
    print(f"Any negative units: {any(v < 0 for v in units_values)}")