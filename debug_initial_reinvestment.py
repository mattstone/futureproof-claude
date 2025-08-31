#!/usr/bin/env python3

import pandas as pd
from statistics import geometric_mean

# Parameters exactly as used in the actual calculation
house_value = 1500000
loan_duration = 30
annuity_duration = 15
loan_to_value = 0.8
annual_income = 30000
insurer_profit_margin = 0.5
insurance_cost_pa = 0.02
start_year = 2000

# Derived values
total_loan = house_value * loan_to_value
reinvest_fraction = 1.0 - (annuity_duration * annual_income) / total_loan
insurance_profit_margin = 1.0 + insurer_profit_margin
insurance_cost = insurance_cost_pa * total_loan * loan_duration

print("=== DETAILED INITIAL REINVESTMENT CALCULATION ===")
print(f"house_value: ${house_value}")
print(f"loan_to_value: {loan_to_value}")
print(f"total_loan: ${total_loan}")
print(f"annuity_duration: {annuity_duration}")
print(f"annual_income: ${annual_income}")
print(f"reinvest_fraction: {reinvest_fraction:.6f}")
print(f"insurer_profit_margin: {insurer_profit_margin}")
print(f"insurance_cost_pa: {insurance_cost_pa}")
print(f"loan_duration: {loan_duration}")
print(f"insurance_cost: ${insurance_cost}")

# Load historical data to get actual interest rates used
fedfunds = pd.read_csv('/Users/zen/projects/futureproof/futureproof/python/FEDFUNDS2.csv')
all_interest_series = list(map(lambda x: x/100, fedfunds['FEDFUNDS'].values.tolist()))

# Calculate start offset exactly as Python does
start_offset = (start_year - 1988) * 12
required_months = loan_duration * 12
max_interest_months = len(all_interest_series)

if start_offset + required_months > max_interest_months:
    start_offset = max(0, max_interest_months - required_months)
start_offset = max(0, start_offset)

interest_series = all_interest_series[start_offset:start_offset+required_months]
print(f"start_offset: {start_offset}")
print(f"interest_series length: {len(interest_series)}")
print(f"First 5 interest rates: {[round(r, 6) for r in interest_series[:5]]}")

# Geometric mean calculation (exactly as Python does)
avg_cash_rate = geometric_mean([1 + r for r in interest_series]) - 1
print(f"avg_cash_rate (geometric mean): {avg_cash_rate:.8f}")

# Python's exact initial_reinvestment formula
print(f"\n=== INITIAL REINVESTMENT COMPONENTS ===")
component1 = total_loan * reinvest_fraction
print(f"total_loan * reinvest_fraction = ${total_loan} * {reinvest_fraction:.6f} = ${component1}")

component2_numerator = insurance_profit_margin * insurance_cost
print(f"insurance_profit_margin * insurance_cost = {insurance_profit_margin} * ${insurance_cost} = ${component2_numerator}")

component2_denominator = pow(1 + avg_cash_rate, loan_duration)
print(f"pow(1 + avg_cash_rate, loan_duration) = (1 + {avg_cash_rate:.8f})^{loan_duration} = {component2_denominator:.8f}")

component2 = component2_numerator / component2_denominator
print(f"Present value of insurance cost = ${component2_numerator} / {component2_denominator:.8f} = ${component2}")

initial_reinvestment = component1 - component2
print(f"\nFINAL: initial_reinvestment = ${component1} - ${component2} = ${initial_reinvestment}")

# Now check first row calculation
sp500df = pd.read_csv('/Users/zen/projects/futureproof/futureproof/python/sp500tr.csv', thousands=',')
sp_prices = sp500df['AdjClose'].values.tolist()
sp_prices.reverse()
price_path = sp_prices[start_offset:start_offset+required_months]
S0 = price_path[0]

print(f"\n=== FIRST ROW CALCULATION ===")
print(f"S0 (initial stock price): {S0}")

holdings = initial_reinvestment / S0
print(f"holdings = initial_reinvestment / S0 = ${initial_reinvestment} / {S0} = {holdings:.6f}")

holdings_s0 = holdings * S0
print(f"holdings_s0 (first row Reinvestment) = holdings * S0 = {holdings:.6f} * {S0} = ${holdings_s0}")

print(f"\n=== VERIFICATION ===")
print(f"Expected Python first row Reinvestment: ${holdings_s0:.0f}")
print(f"This should match -38577 from Python output")