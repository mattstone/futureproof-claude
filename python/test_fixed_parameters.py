#!/usr/bin/env python3

import sys
import json
import math
import pandas as pd
import numpy as np
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths

print("=== TESTING FIXED PARAMETER CONVERSION ===")

# These are the values that should now be sent from Rails after the fix:
# Form sends: 80 -> Rails converts to: 80/100 = 0.8
# Form sends: 9.75 -> Rails converts to: 9.75/100 = 0.0975
# etc.

house_value = 1500000
loan_duration = 30
annuity_duration = 15
loan_to_value = 80 / 100.0  # Now properly converted
annual_income = 30000
equity_return = 9.75 / 100.0  # Now properly converted
volatility = 15 / 100.0  # Now properly converted
cash_rate = 4.0 / 100.0  # Now properly converted
insurer_profit_margin = 50 / 100.0  # Now properly converted
total_paths = 10  # Small test

print(f"Fixed parameters:")
print(f"  loan_to_value: {loan_to_value} (was using raw 80)")
print(f"  equity_return: {equity_return} (was using raw 9.75)")
print(f"  volatility: {volatility} (was using raw 15)")
print(f"  cash_rate: {cash_rate} (was using raw 4.0)")
print(f"  insurer_profit_margin: {insurer_profit_margin} (was using raw 50)")

# Calculate derived values
total_loan = house_value * loan_to_value
reinvest_fraction = 1 - (annuity_duration * annual_income) / total_loan
insurance_profit_margin = 1.0 + insurer_profit_margin

print(f"\nDerived values:")
print(f"  total_loan: ${total_loan:,.0f}")
print(f"  reinvest_fraction: {reinvest_fraction:.3f}")
print(f"  insurance_profit_margin: {insurance_profit_margin:.3f}")

# Other parameters
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
principal_repayment = False

# Calculate insurance cost
insurance_cost = insurance_cost_pa * total_loan * loan_duration

# Run simulation
np.random.seed(42)
S0 = 100
dt = 1.0/120

print(f"\n=== RUNNING FIXED SIMULATION ===")
price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)

df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin, insurance_cost,
                    cash_rate, wholesale_lending_margin, additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)

# Compare with previous run
path_0 = df[df['Path'] == 0].copy()
print(f"\n=== COMPARISON WITH PREVIOUS RUN ===")

checkpoints = [0, 30, 60, 90, 119]
for period in checkpoints:
    row = path_0[path_0['Period'] == period]
    if not row.empty:
        r = row.iloc[0]
        print(f"\nPeriod {period}:")
        print(f"  S&P 500: ${r['SP500']:.2f}")
        print(f"  Reinvestment: ${r['Reinvestment']:,.0f}")
        print(f"  Loan size: ${r['Loan size']:,.0f}")

# Check final results
final_period = 119
final_rows = df[df['Period'] == final_period]
if len(final_rows) > 0:
    final_reinvestments = final_rows['Reinvestment'].tolist()
    print(f"\n=== FINAL RESULTS COMPARISON ===")
    print(f"Mean final reinvestment: ${np.mean(final_reinvestments):,.0f}")
    print(f"Range: ${min(final_reinvestments):,.0f} to ${max(final_reinvestments):,.0f}")
    
print(f"\n=== EXPECTED DIFFERENCES ===")
print("With proper parameter conversion, we should see:")
print("1. More reasonable S&P 500 growth (not 4000%+)")
print("2. Different loan and reinvestment patterns")
print("3. Values closer to reference site patterns")