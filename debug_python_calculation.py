#!/usr/bin/env python3

import sys
import os
sys.path.append('/Users/zen/projects/futureproof/futureproof/python')

import pandas as pd
from statistics import geometric_mean

# Parameters
house_value = 1500000
loan_duration = 30
annuity_duration = 15
loan_to_value = 0.8
annual_income = 30000
insurer_profit_margin = 0.5
wholesale_lending_margin = 0.02
additional_loan_margins = 0.015
holiday_enter_fraction = 1.35
holiday_exit_fraction = 1.95
insurance_cost_pa = 0.02
start_year = 2000

# Calculated values
total_loan = house_value * loan_to_value
reinvest_fraction = 1.0 - (annuity_duration * annual_income) / total_loan
insurance_profit_margin = 1.0 + insurer_profit_margin
insurance_cost = insurance_cost_pa * total_loan * loan_duration

print("=== PYTHON INITIAL CALCULATION DEBUG ===")
print(f"Total loan: ${total_loan}")
print(f"Reinvest fraction: {reinvest_fraction}")
print(f"Insurance profit margin: {insurance_profit_margin}")
print(f"Insurance cost: ${insurance_cost}")

# Load historical data
fedfunds = pd.read_csv('/Users/zen/projects/futureproof/futureproof/python/FEDFUNDS2.csv')
sp500df = pd.read_csv('/Users/zen/projects/futureproof/futureproof/python/sp500tr.csv', thousands=',')

all_interest_series = list(map(lambda x: x/100, fedfunds['FEDFUNDS'].values.tolist()))
sp_prices = sp500df['AdjClose'].values.tolist()
sp_prices.reverse()

start_offset = (start_year - 1988)*12
required_months = loan_duration * 12

# Ensure we have enough data
max_available_months = len(sp_prices)
max_interest_months = len(all_interest_series)

if start_offset + required_months > max_available_months:
    start_offset = max(0, max_available_months - required_months)

if start_offset + required_months > max_interest_months:
    start_offset = max(0, max_interest_months - required_months)

start_offset = max(0, start_offset)

interest_series = all_interest_series[start_offset:start_offset+required_months]
price_path = sp_prices[start_offset:start_offset+required_months]

print(f"Start offset: {start_offset}")
print(f"Interest series length: {len(interest_series)}")
print(f"First 5 interest rates: {[round(r, 6) for r in interest_series[:5]]}")

# Calculate geometric mean
avg_cash_rate = geometric_mean([1 + r for r in interest_series]) - 1
print(f"Geometric mean cash rate: {avg_cash_rate:.8f}")

# Initial reinvestment calculation (Python's exact formula)
initial_reinvestment = total_loan * reinvest_fraction - \
    insurance_profit_margin * insurance_cost / pow(1 + avg_cash_rate, loan_duration)

print(f"Initial reinvestment: ${initial_reinvestment:.2f}")

# Check if this matches expected negative value
S0 = price_path[0]
holdings = initial_reinvestment / S0
holdings_s0 = holdings * S0

print(f"S0 (initial price): {S0}")
print(f"Holdings (units): {holdings:.6f}")
print(f"Holdings * S0 (should match reinvestment): ${holdings_s0:.2f}")

# Holiday thresholds
holiday_enter = initial_reinvestment * holiday_enter_fraction
holiday_exit = initial_reinvestment * holiday_exit_fraction

print(f"Holiday enter threshold: ${holiday_enter:.2f}")
print(f"Holiday exit threshold: ${holiday_exit:.2f}")

# Initial holiday state
in_holiday = holiday_enter_fraction > 1
print(f"Initial holiday state: {in_holiday}")

# Loan size calculation
quarter_div = 0.25
annual_income_quarter = annual_income * quarter_div
loan_size = total_loan * reinvest_fraction + annual_income_quarter

print(f"Annual income quarter: ${annual_income_quarter}")
print(f"Initial loan size: ${loan_size:.2f}")

print("\n=== COMPARISON WITH EXPECTED VALUES ===")
print(f"Expected first row reinvestment: ${holdings_s0:.2f}")
print(f"This should match the Python output of: $-38577")