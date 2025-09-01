#!/usr/bin/env python3

import sys
import json
import math
import pandas as pd
import numpy as np
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths

# Set seed for reproducible results
np.random.seed(42)

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
insurance_cost = 0.02 * total_loan * loan_duration
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
total_paths = 3

# Generate paths
price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)
dt = 1.0/120

# Run simulation
df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin, insurance_cost,
                    cash_rate, wholesale_lending_margin, additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)

# Check path 0 data for cumulative fields
path_0 = df[df['Path'] == 0].copy()

print("=== AVAILABLE COLUMNS ===")
for col in sorted(df.columns):
    print(f"  {col}")

print(f"\n=== CUMULATIVE FIELD ANALYSIS (Path 0) ===")

# Check AnnuityIncome vs cumulative calculations
periods_to_check = [0, 10, 20, 40, 80, 119]
for period in periods_to_check:
    row = path_0[path_0['Period'] == period]
    if not row.empty:
        r = row.iloc[0]
        print(f"\n--- Period {period} ---")
        if 'AnnuityIncome' in r:
            print(f"  AnnuityIncome: ${r['AnnuityIncome']:,.0f}")
        
        # Calculate manual cumulative from start to this period
        annuity_to_period = path_0[path_0['Period'] <= period]['AnnuityIncome'].sum()
        print(f"  Manual cumulative annuity: ${annuity_to_period:,.0f}")
        
        # Check if there are already cumulative fields
        cumulative_fields = [col for col in r.index if 'Cum' in col or 'cumulative' in col.lower()]
        for field in cumulative_fields:
            print(f"  {field}: {r[field]:,.0f}")

print(f"\n=== COMPARISON: cumsum() vs Manual vs Existing Fields ===")
annuity_values = path_0['AnnuityIncome'].tolist()
cumsum_values = path_0['AnnuityIncome'].cumsum().tolist()

print(f"First 10 AnnuityIncome values: {[f'{v:,.0f}' for v in annuity_values[:10]]}")
print(f"First 10 cumsum() values: {[f'{v:,.0f}' for v in cumsum_values[:10]]}")

if 'CumInterestPaid' in path_0.columns:
    existing_cum_values = path_0['CumInterestPaid'].tolist()
    print(f"First 10 CumInterestPaid values: {[f'{v:,.0f}' for v in existing_cum_values[:10]]}")

# Check if there's a mismatch in what we should be using
print(f"\n=== POTENTIAL ISSUES ===")
print(f"Are we double-cumulating already cumulative fields?")

# Check for zero or constant values that might indicate problems
zero_fields = []
constant_fields = []
for col in df.columns:
    if col not in ['Path', 'Period', 'Year', 'Quarter']:
        col_values = path_0[col].tolist()
        if all(v == 0 for v in col_values):
            zero_fields.append(col)
        elif len(set(col_values)) == 1:
            constant_fields.append(col)

print(f"Fields that are always zero: {zero_fields}")
print(f"Fields that are constant: {constant_fields}")