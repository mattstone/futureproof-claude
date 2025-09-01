#!/usr/bin/env python3

import sys
import json
import math
import pandas as pd
import numpy as np
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths

print("=== FINAL PARAMETER TEST: MATCHING REFERENCE SITE ===")

# These should be the EXACT parameters that match the reference site:
# If form sends percentages, they need to be converted to decimals

# Form values (percentages):
form_loan_to_value = 80
form_equity_return = 9.75  
form_volatility = 15
form_cash_rate = 4.0
form_insurer_profit_margin = 50

# Check if we need to convert these:
print("=== PARAMETER CONVERSION CHECK ===")
print("Option A: Form sends percentages, need conversion:")
print(f"  loan_to_value: {form_loan_to_value} -> {form_loan_to_value/100.0}")
print(f"  equity_return: {form_equity_return} -> {form_equity_return/100.0}")
print(f"  volatility: {form_volatility} -> {form_volatility/100.0}")

print(f"\nOption B: Form sends decimals, no conversion needed")
print(f"  loan_to_value: {form_loan_to_value} (would be 8000% LTV!)")

# The realistic interpretation is Option A - let's test it
house_value = 1500000
loan_duration = 30
annuity_duration = 15
loan_to_value = form_loan_to_value / 100.0  # Convert percentage
annual_income = 30000
equity_return = form_equity_return / 100.0  # Convert percentage
volatility = form_volatility / 100.0  # Convert percentage
cash_rate = form_cash_rate / 100.0  # Convert percentage
insurer_profit_margin = form_insurer_profit_margin / 100.0  # Convert percentage

total_loan = house_value * loan_to_value
reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan
insurance_profit_margin = 1.0 + insurer_profit_margin

print(f"\n=== CONVERTED PARAMETERS ===")
print(f"  total_loan: ${total_loan:,.0f}")
print(f"  loan_to_value: {loan_to_value:.3f}")
print(f"  equity_return: {equity_return:.4f}")
print(f"  volatility: {volatility:.3f}")
print(f"  cash_rate: {cash_rate:.3f}")
print(f"  reinvest_fraction: {reinvest_fraction:.3f}")

# Other standard parameters
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

# Use SEED 0 (form default)
random_seed = 0
total_paths = 100
S0 = 100
dt = 1.0/120

insurance_cost = insurance_cost_pa * total_loan * loan_duration

print(f"\n=== REFERENCE-MATCHING SIMULATION ===")
np.random.seed(random_seed)

price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)

df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin, insurance_cost,
                    cash_rate, wholesale_lending_margin, additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)

# Show mean path that should match reference charts
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
            'InterestDeficit': path_data.iloc[i]['InterestDeficit'],
            'Units': path_data.iloc[i]['Units']
        })

print(f"\nMEAN PATH DATA (should match reference site):")
key_periods = [0, 15, 30, 45, 60, 75, 90, 105, 119]
for period in key_periods:
    if period in periods_data:
        period_values = periods_data[period]
        mean_sp500 = np.mean([pv['SP500'] for pv in period_values])
        mean_reinvest = np.mean([pv['Reinvestment'] for pv in period_values])
        mean_loan = np.mean([pv['Loan size'] for pv in period_values])
        mean_deficit = np.mean([pv['InterestDeficit'] for pv in period_values])
        mean_units = np.mean([pv['Units'] for pv in period_values])
        
        year = 1999 + period/4.0
        print(f"  Period {period:2d} ({year:6.1f}): S&P ${mean_sp500:7.2f}, Reinvest ${mean_reinvest:9,.0f}, Loan ${mean_loan:9,.0f}, Deficit ${mean_deficit:7,.0f}, Units {mean_units:5.0f}")

print(f"\n=== CHART SCALE EXPECTATIONS ===")
print("With these parameters and seed 0, charts should show:")
print("1. S&P 500: Growth from $100 to ~$1,888 over 30 years")
print("2. Reinvestment: Growth from ~$417K to ~$1.08M")
print("3. More gradual, realistic growth curves")
print("4. These patterns should closely match the reference site")