#!/usr/bin/env python3

import sys
import json
import math
import pandas as pd
import numpy as np
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths

print("=== DEBUGGING RAILS PARAMETER PROCESSING ===")

# These are the EXACT default values from our Rails form:
form_defaults = {
    'house_value': 1500000,
    'loan_duration': 30,
    'annuity_duration': 15,
    'loan_to_value': 80,  # Note: this is 80, not 0.8
    'annual_income': 30000,
    'equity_return': 9.75,  # Note: this is 9.75, not 0.0975
    'volatility': 15,  # Note: this is 15, not 0.15
    'cash_rate': 4.0,  # Note: this is 4.0, not 0.04
    'total_paths': 1000,
    'insurer_profit_margin': 50,  # Note: this is 50, not 0.5
    'random_seed': 0,
    'principal_repayment': False,
    'hedged': False,
    'hedging_max_loss': 0.1,
    'hedging_cap': 0.2,
    'hedging_cost_pa': 0.01
}

print("Form defaults:")
for key, value in form_defaults.items():
    print(f"  {key}: {value}")

# Convert exactly as our Rails service does
house_value = form_defaults['house_value']
loan_duration = form_defaults['loan_duration'] 
annuity_duration = form_defaults['annuity_duration']
loan_to_value = form_defaults['loan_to_value'] / 100.0  # Convert percentage
annual_income = form_defaults['annual_income']
equity_return = form_defaults['equity_return'] / 100.0  # Convert percentage  
volatility = form_defaults['volatility'] / 100.0  # Convert percentage
cash_rate = form_defaults['cash_rate'] / 100.0  # Convert percentage
total_paths = form_defaults['total_paths']
insurer_profit_margin = form_defaults['insurer_profit_margin'] / 100.0  # Convert percentage
random_seed = form_defaults['random_seed']

# Calculate derived values exactly as Rails does
total_loan = house_value * loan_to_value
reinvest_fraction = 1 - (annuity_duration * annual_income) / total_loan
insurance_profit_margin = 1.0 + insurer_profit_margin

print(f"\nConverted parameters:")
print(f"  total_loan: ${total_loan:,.0f}")
print(f"  loan_to_value: {loan_to_value}")
print(f"  equity_return: {equity_return}")
print(f"  volatility: {volatility}")
print(f"  cash_rate: {cash_rate}")
print(f"  insurer_profit_margin: {insurer_profit_margin}")
print(f"  reinvest_fraction: {reinvest_fraction}")

# Other parameters (matching our Rails service)
wholesale_lending_margin = 0.02
additional_loan_margins = 0.015
holiday_enter_fraction = 1.35
holiday_exit_fraction = 1.95
subperform_loan_threshold_quarters = 6
superpay_start_factor = 1.0
max_superpay_factor = 1.0
insurance_cost_pa = 0.02
year0 = 2000
hedged = form_defaults['hedged']
hedging_max_loss = form_defaults['hedging_max_loss']
hedging_cap = form_defaults['hedging_cap'] 
hedging_cost_pa = form_defaults['hedging_cost_pa']
principal_repayment = form_defaults['principal_repayment']

# Calculate insurance cost
insurance_cost = insurance_cost_pa * total_loan * loan_duration

print(f"\nFixed parameters:")
print(f"  insurance_cost: ${insurance_cost:,.0f}")
print(f"  wholesale_lending_margin: {wholesale_lending_margin}")
print(f"  holiday_enter_fraction: {holiday_enter_fraction}")
print(f"  holiday_exit_fraction: {holiday_exit_fraction}")

# Set seed and run with small sample
np.random.seed(random_seed if random_seed > 0 else 42)
sample_paths = 10
S0 = 100
dt = 1.0/120

print(f"\n=== RUNNING SIMULATION ===")
price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, sample_paths, S0)
print(f"Generated {sample_paths} price paths")

df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin, insurance_cost,
                    cash_rate, wholesale_lending_margin, additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)

print(f"Simulation complete - DataFrame shape: {df.shape}")

# Analyze first path results  
path_0 = df[df['Path'] == 0].copy()
print(f"\n=== PATH 0 ANALYSIS (Rails parameters) ===")

checkpoints = [0, 30, 60, 90, 119]  # Various time points
for period in checkpoints:
    row = path_0[path_0['Period'] == period]
    if not row.empty:
        r = row.iloc[0]
        print(f"\nPeriod {period} (Year {r['Year']:.1f}):")
        print(f"  S&P 500: ${r['SP500']:.2f}")
        print(f"  Loan size: ${r['Loan size']:,.0f}")
        print(f"  Reinvestment: ${r['Reinvestment']:,.0f}")
        print(f"  Interest Deficit: ${r['InterestDeficit']:,.0f}")
        print(f"  Units: {r['Units']:,.0f}")
        print(f"  Cumulative Interest Paid: ${r['CumInterestPaid']:,.0f}")
        if 'AnnuityIncome' in r.index:
            print(f"  Annuity Income: ${r['AnnuityIncome']:,.0f}")

# Show final results summary
final_period = 119
final_rows = df[df['Period'] == final_period]
if len(final_rows) > 0:
    final_reinvestments = final_rows['Reinvestment'].tolist()
    final_deficits = final_rows['InterestDeficit'].tolist()
    
    print(f"\n=== FINAL RESULTS SUMMARY ===")
    print(f"Mean final reinvestment: ${np.mean(final_reinvestments):,.0f}")
    print(f"Std final reinvestment: ${np.std(final_reinvestments):,.0f}")
    print(f"Mean final deficit: ${np.mean(final_deficits):,.0f}")
    print(f"Min final reinvestment: ${min(final_reinvestments):,.0f}")
    print(f"Max final reinvestment: ${max(final_reinvestments):,.0f}")

# Check for any obvious issues
print(f"\n=== DATA QUALITY CHECKS ===")
all_sp500 = df['SP500'].tolist()
all_reinvest = df['Reinvestment'].tolist()
print(f"S&P 500 range: ${min(all_sp500):.2f} to ${max(all_sp500):.2f}")
print(f"Reinvestment range: ${min(all_reinvest):,.0f} to ${max(all_reinvest):,.0f}")
print(f"Any negative S&P 500: {any(v < 0 for v in all_sp500)}")
print(f"Any negative reinvestment: {any(v < 0 for v in all_reinvest)}")

print(f"\n=== POTENTIAL ISSUES TO CHECK ===")
print("1. Are these results similar to what the reference site shows?")
print("2. Are the parameter conversions (% to decimal) correct?")
print("3. Are we using the right random seed behavior?")
print("4. Are mean path calculations aggregating correctly?")