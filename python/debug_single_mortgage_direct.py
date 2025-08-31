#!/usr/bin/env python3

import sys
import json
import math
import pandas as pd
import numpy as np
from statistics import geometric_mean
from core_model_advanced import single_mortgage, accounts_table
from utils import mean_sd, dollar, pcntdf, pcnt, secant

# Parameters EXACTLY as Ruby generates them
house_value = 1500000.0
loan_duration = 30
annuity_duration = 15
loan_type = "Interest only"
loan_to_value = 0.8
principal_repayment = False

annual_income = 30000.0
at_risk_capital_fraction = 0.0

total_loan = house_value * loan_to_value
reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan

annual_house_price_appreciation = 0.04
insurer_profit_margin = 0.5
insurance_profit_margin = 1.0 + insurer_profit_margin

wholesale_lending_margin = 0.02
additional_loan_margins = 0.015

holiday_enter_fraction = 1.35
holiday_exit_fraction = 1.95
subperform_loan_threshold_quarters = 6

insurance_cost_pa = 0.02
year0 = 2000
hedged = False
hedging_max_loss = 0.1
hedging_cap = 0.2
hedging_cost_pa = 0.01

# Load data
sp500df = pd.read_csv('sp500tr.csv', thousands=',')
fedfunds = pd.read_csv('FEDFUNDS2.csv')

all_interest_series = list(map(lambda x: x/100, fedfunds['FEDFUNDS'].values.tolist()))
sp_prices = sp500df['AdjClose'].values.tolist()
sp_prices.reverse()

start_offset = (year0 - 1988)*12
max_available_months = len(sp_prices)
max_interest_months = len(all_interest_series)
required_months = loan_duration * 12

if start_offset + required_months > max_available_months:
    start_offset = max(0, max_available_months - required_months)
if start_offset + required_months > max_interest_months:
    start_offset = max(0, max_interest_months - required_months)
start_offset = max(0, start_offset)

price_path = sp_prices[start_offset:start_offset+loan_duration*12]
price_paths = [(0, price_path)]
interest_series = all_interest_series[start_offset:start_offset+loan_duration*12]

if len(price_path) == 0:
    price_path = [100] * (loan_duration * 12)
if len(interest_series) == 0:
    interest_series = [0.04] * (loan_duration * 12)

dt = 1.0/12
S0 = price_path[0]
insurance_cost = insurance_cost_pa*total_loan*loan_duration

print("=== DIRECT PYTHON FUNCTION CALL DEBUG ===")
print(f"Parameters being passed to single_mortgage:")
print(f"  total_loan: {total_loan}")
print(f"  reinvest_fraction: {reinvest_fraction}")
print(f"  loan_duration: {loan_duration}")
print(f"  annual_income: {annual_income}")
print(f"  annuity_duration: {annuity_duration}")
print(f"  insurance_profit_margin: {insurance_profit_margin}")
print(f"  insurance_cost: {insurance_cost}")
print(f"  len(interest_series): {len(interest_series)}")
print(f"  wholesale_lending_margin: {wholesale_lending_margin}")
print(f"  additional_loan_margins: {additional_loan_margins}")
print(f"  holiday_enter_fraction: {holiday_enter_fraction}")
print(f"  holiday_exit_fraction: {holiday_exit_fraction}")
print(f"  subperform_loan_threshold_quarters: {subperform_loan_threshold_quarters}")
print(f"  S0: {S0}")
print(f"  dt: {dt}")
print(f"  year_offset: {year0-1}")
print(f"  principal_repayment: {principal_repayment}")
print(f"  hedged: {hedged}")
print(f"  hedging_max_loss: {hedging_max_loss}")
print(f"  hedging_cap: {hedging_cap}")
print(f"  hedging_cost_pa: {hedging_cost_pa}")

# Add debug to see what's happening inside single_mortgage
def debug_single_mortgage_calculations():
    # Replicate the exact calculations from single_mortgage
    is_cash_rate_list = isinstance(interest_series, list)
    avg_cash_rate = geometric_mean([1 + r for r in interest_series]) - 1 if is_cash_rate_list else interest_series
    
    print(f"\nInside single_mortgage calculations:")
    print(f"  is_cash_rate_list: {is_cash_rate_list}")
    print(f"  avg_cash_rate: {avg_cash_rate:.8f}")
    
    initial_reinvestment = total_loan*reinvest_fraction - \
       insurance_profit_margin* insurance_cost/ pow(1 + avg_cash_rate, loan_duration)
    
    print(f"  initial_reinvestment calculation:")
    print(f"    total_loan*reinvest_fraction: {total_loan*reinvest_fraction}")
    print(f"    insurance_profit_margin*insurance_cost: {insurance_profit_margin*insurance_cost}")
    print(f"    pow(1 + avg_cash_rate, loan_duration): {pow(1 + avg_cash_rate, loan_duration):.8f}")
    print(f"    present_value_insurance: {insurance_profit_margin*insurance_cost/pow(1 + avg_cash_rate, loan_duration):.8f}")
    print(f"    FINAL initial_reinvestment: {initial_reinvestment:.8f}")
    
    # Calculate holdings and first row value
    holdings = initial_reinvestment / S0
    holdings_s0 = holdings * S0
    
    print(f"  holdings = initial_reinvestment / S0: {holdings:.8f}")
    print(f"  holdings_s0 = holdings * S0: {holdings_s0:.8f}")
    print(f"  First row Reinvestment (rounded): {round(holdings_s0)}")
    
    return initial_reinvestment

debug_initial_reinvest = debug_single_mortgage_calculations()

print(f"\nCalling actual single_mortgage function...")

# Call the actual function
df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin,insurance_cost,
                    interest_series,wholesale_lending_margin,additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, 1.0, 1.0, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss,hedging_cap, hedging_cost_pa)

print(f"Actual function result:")
print(f"  First row Reinvestment: {df['Reinvestment'].iloc[0]}")
print(f"  First row Units: {df['Units'].iloc[0]}")
print(f"  Expected debug result: {round(debug_initial_reinvest)}")
print(f"  Match: {df['Reinvestment'].iloc[0] == round(debug_initial_reinvest)}")

if df['Reinvestment'].iloc[0] != round(debug_initial_reinvest):
    print(f"\n❌ MISMATCH! There's something different inside single_mortgage!")
    print(f"  Debug calculation: {round(debug_initial_reinvest)}")
    print(f"  Actual function result: {df['Reinvestment'].iloc[0]}")