#!/usr/bin/env python3

import sys
import json
import math
import pandas as pd
import numpy as np
from statistics import geometric_mean

# I need to create a modified version of single_mortgage with debug prints
# Let me copy the relevant parts and add debugging

def debug_single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin,insurance_cost,
                    cash_rate_series,wholesale_lending_margin,additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year_offset=0, max_superpay_factor = 1.0, 
                    superpay_start_factor = 1.0, enable_pool = False, insured_units = 0, 
                    expected_reinvestment_ratio = None, piProgressiveRepayment = False, hedged = False, 
                    hedging_max_loss = 0, hedging_cap = 1000, hedging_cost_pa=0):
  
  print("=== DEBUG SINGLE_MORTGAGE FUNCTION START ===")
  print(f"Received parameters:")
  print(f"  total_loan: {total_loan}")
  print(f"  reinvest_fraction: {reinvest_fraction}")
  print(f"  loan_duration: {loan_duration}")
  print(f"  annual_income: {annual_income}")
  print(f"  annuity_duration: {annuity_duration}")
  print(f"  insurance_profit_margin: {insurance_profit_margin}")
  print(f"  insurance_cost: {insurance_cost}")
  print(f"  S0: {S0}")
  print(f"  dt: {dt}")
  print(f"  year_offset: {year_offset}")
  print(f"  piProgressiveRepayment: {piProgressiveRepayment}")
  
  # Pre-calculate constants EXACTLY like Python
  is_cash_rate_list = isinstance(cash_rate_series, list)
  print(f"  is_cash_rate_list: {is_cash_rate_list}")
  
  if is_cash_rate_list:
    avg_cash_rate = geometric_mean([1 + r for r in cash_rate_series]) - 1
  else:
    avg_cash_rate = cash_rate_series
  
  print(f"  avg_cash_rate: {avg_cash_rate:.8f}")
  
  initial_reinvestment = total_loan*reinvest_fraction - \
     insurance_profit_margin* insurance_cost/ pow(1 + avg_cash_rate, loan_duration)
  
  print(f"  initial_reinvestment: {initial_reinvestment:.8f}")
  
  expected_reinvestment = None
  if expected_reinvestment_ratio is not None:
    expected_reinvestment = expected_reinvestment_ratio * initial_reinvestment
    print(f"  expected_reinvestment: {expected_reinvestment}")
  
  holiday_enter = initial_reinvestment* holiday_enter_fraction
  holiday_exit = initial_reinvestment*holiday_exit_fraction
  
  print(f"  holiday_enter: {holiday_enter:.8f}")
  print(f"  holiday_exit: {holiday_exit:.8f}")
  
  # Pre-calculate common constants
  quarter_div = 0.25  # Slightly faster than 1.0/4
  dt_quarter_inv = 1.0/(dt*4)
  annual_income_quarter = annual_income * quarter_div
  annuity_duration_quarters = int(annuity_duration * 4)  # Use int for comparisons
  total_periods = int(4 * loan_duration + 1)
  
  print(f"  quarter_div: {quarter_div}")
  print(f"  dt_quarter_inv: {dt_quarter_inv}")
  print(f"  annual_income_quarter: {annual_income_quarter}")
  print(f"  annuity_duration_quarters: {annuity_duration_quarters}")
  print(f"  total_periods: {total_periods}")
  
  # Process single path
  for (pathn, S) in price_paths:
    print(f"\nProcessing path {pathn}")
    print(f"  S (price path) length: {len(S)}")
    print(f"  S[0]: {S[0]}")
    
    # variables that change every year, initial values set here
    holdings = initial_reinvestment / S0
    cummlative_units_sold = 0.0
    init_units_to_principal = 0.0
    # includes Y1 income
    loan_size = total_loan * reinvest_fraction + annual_income_quarter
    
    print(f"  holdings = initial_reinvestment / S0 = {initial_reinvestment:.8f} / {S0} = {holdings:.8f}")
    print(f"  loan_size = {total_loan} * {reinvest_fraction} + {annual_income_quarter} = {loan_size}")
    
    if piProgressiveRepayment:
      init_units_to_principal = annual_income_quarter / S0
      loan_size -= annual_income_quarter 
      holdings -= init_units_to_principal
      print(f"  Progressive repayment adjustment:")
      print(f"    init_units_to_principal = {annual_income_quarter} / {S0} = {init_units_to_principal}")
      print(f"    loan_size after adjustment = {loan_size}")
      print(f"    holdings after adjustment = {holdings}")

    in_holiday = holiday_enter_fraction > 1
    holiday_quarters = 0
    cum_units_to_pool = 0.0
    cum_interest_paid = 0.0
    deferred = 0.0
    funder_earned = 0.0
    
    print(f"  in_holiday (initial): {in_holiday}")

    # Initialize first row
    holdings_s0 = holdings * S0
    
    print(f"  holdings_s0 (first row value) = {holdings} * {S0} = {holdings_s0:.8f}")
    print(f"  First row Reinvestment (rounded): {round(holdings_s0)}")
    
    return round(holdings_s0)

# Parameters
house_value = 1500000.0
loan_duration = 30
annuity_duration = 15
loan_type = "Interest only"
loan_to_value = 0.8
principal_repayment = False

annual_income = 30000.0
total_loan = house_value * loan_to_value
reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan

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

result = debug_single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin,insurance_cost,
                    interest_series,wholesale_lending_margin,additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, 1.0, 1.0, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss,hedging_cap, hedging_cost_pa)

print(f"\nDEBUG RESULT: {result}")

# Now compare with actual function
from core_model_advanced import single_mortgage
df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin,insurance_cost,
                    interest_series,wholesale_lending_margin,additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, 1.0, 1.0, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss,hedging_cap, hedging_cost_pa)

print(f"ACTUAL RESULT: {df['Reinvestment'].iloc[0]}")
print(f"MATCH: {result == df['Reinvestment'].iloc[0]}")