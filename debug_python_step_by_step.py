#!/usr/bin/env python3

import sys
import json
import math
import pandas as pd
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
import numpy as np
import pprint
import math
import numpy_financial as npf

# Add python directory to path
sys.path.append('/Users/zen/projects/futureproof/futureproof/python')

from core_model_advanced import single_mortgage, accounts_table
from utils import mean_sd, dollar, pcntdf, pcnt, secant

# Add debug prints to understand the calculation
def debug_single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin,insurance_cost,
                    cash_rate_series,wholesale_lending_margin,additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year_offset=0, max_superpay_factor = 1.0, 
                    superpay_start_factor = 1.0, enable_pool = False, insured_units = 0, 
                    expected_reinvestment_ratio = None, piProgressiveRepayment = False, hedged = False, 
                    hedging_max_loss = 0, hedging_cap = 1000, hedging_cost_pa=0):
  
  print("=== DEBUGGING SINGLE_MORTGAGE FUNCTION ===")
  print(f"total_loan: {total_loan}")
  print(f"reinvest_fraction: {reinvest_fraction}")
  print(f"loan_duration: {loan_duration}")
  print(f"insurance_profit_margin: {insurance_profit_margin}")
  print(f"insurance_cost: {insurance_cost}")
  print(f"S0: {S0}")
  
  # Pre-calculate constants
  is_cash_rate_list = isinstance(cash_rate_series, list)
  print(f"is_cash_rate_list: {is_cash_rate_list}")
  
  if is_cash_rate_list:
    from statistics import geometric_mean
    avg_cash_rate = geometric_mean([1 + r for r in cash_rate_series]) - 1
  else:
    avg_cash_rate = cash_rate_series
  
  print(f"avg_cash_rate: {avg_cash_rate:.8f}")
  
  initial_reinvestment = total_loan*reinvest_fraction - \
     insurance_profit_margin* insurance_cost/ pow(1 + avg_cash_rate, loan_duration)
  
  print(f"Calculation step by step:")
  print(f"  total_loan * reinvest_fraction = {total_loan} * {reinvest_fraction} = {total_loan*reinvest_fraction}")
  print(f"  insurance_profit_margin * insurance_cost = {insurance_profit_margin} * {insurance_cost} = {insurance_profit_margin * insurance_cost}")
  print(f"  pow(1 + avg_cash_rate, loan_duration) = pow({1 + avg_cash_rate:.8f}, {loan_duration}) = {pow(1 + avg_cash_rate, loan_duration):.8f}")
  print(f"  present_value_insurance = {insurance_profit_margin * insurance_cost} / {pow(1 + avg_cash_rate, loan_duration):.8f} = {insurance_profit_margin * insurance_cost / pow(1 + avg_cash_rate, loan_duration):.8f}")
  print(f"  initial_reinvestment = {total_loan*reinvest_fraction} - {insurance_profit_margin * insurance_cost / pow(1 + avg_cash_rate, loan_duration):.8f} = {initial_reinvestment:.8f}")
  
  expected_reinvestment = None
  if expected_reinvestment_ratio is not None:
    expected_reinvestment = expected_reinvestment_ratio * initial_reinvestment
  
  holiday_enter = initial_reinvestment * holiday_enter_fraction
  holiday_exit = initial_reinvestment * holiday_exit_fraction
  
  print(f"holiday_enter: {holiday_enter}")
  print(f"holiday_exit: {holiday_exit}")
  
  # Pre-calculate common constants
  quarter_div = 0.25
  dt_quarter_inv = 1.0/(dt*4)
  annual_income_quarter = annual_income * quarter_div
  annuity_duration_quarters = int(annuity_duration * 4)
  total_periods = int(4 * loan_duration + 1)
  
  print(f"quarter_div: {quarter_div}")
  print(f"annual_income_quarter: {annual_income_quarter}")
  print(f"annuity_duration_quarters: {annuity_duration_quarters}")
  print(f"total_periods: {total_periods}")
  
  # Just focus on the first path
  for (pathn, S) in price_paths:
    print(f"\nProcessing path {pathn}")
    
    # variables that change every year, initial values set here
    holdings = initial_reinvestment / S0
    cummlative_units_sold = 0.0
    init_units_to_principal = 0.0
    # includes Y1 income
    loan_size = total_loan * reinvest_fraction + annual_income_quarter
    
    print(f"holdings = initial_reinvestment / S0 = {initial_reinvestment:.8f} / {S0} = {holdings:.8f}")
    print(f"loan_size = total_loan * reinvest_fraction + annual_income_quarter = {total_loan} * {reinvest_fraction} + {annual_income_quarter} = {loan_size}")
    
    if piProgressiveRepayment:
      init_units_to_principal = annual_income_quarter / S0
      loan_size -= annual_income_quarter 
      holdings -= init_units_to_principal
      print(f"Progressive repayment: holdings adjusted to {holdings:.8f}")

    in_holiday = holiday_enter_fraction > 1
    holiday_quarters = 0
    cum_units_to_pool = 0.0
    cum_interest_paid = 0.0
    deferred = 0.0
    funder_earned = 0.0
    
    print(f"in_holiday (initial): {in_holiday}")

    # Initialize first row
    holdings_s0 = holdings * S0
    print(f"holdings_s0 (first row Reinvestment): {holdings_s0:.8f}")
    
    # This is the key - what goes into the first row
    first_row_reinvestment = round(holdings_s0)
    print(f"FIRST ROW REINVESTMENT (rounded): {first_row_reinvestment}")
    
    return first_row_reinvestment

# Parameters from Ruby form (EXACT match)
house_value = 1500000
loan_duration = 30
annuity_duration = 15
loan_type = "Interest only"
loan_to_value = 0.8
principal_repayment = False

annual_income = 30000
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
superpay_start_factor = 1.0
max_superpay_factor = 1.0

insurance_cost_pa = 0.02
year0 = 2000
hedged = False
hedging_max_loss = 0.1
hedging_cap = 0.2
hedging_cost_pa = 0.01

# Load historical data
sp500df = pd.read_csv('/Users/zen/projects/futureproof/futureproof/python/sp500tr.csv', thousands=',')
fedfunds = pd.read_csv('/Users/zen/projects/futureproof/futureproof/python/FEDFUNDS2.csv')

all_interest_series = list(map(lambda x: x/100, fedfunds['FEDFUNDS'].values.tolist()))

sp_prices = sp500df['AdjClose'].values.tolist()
sp_prices.reverse()

start_offset = (year0 - 1988)*12

# Ensure we have enough data
max_available_months = len(sp_prices)
max_interest_months = len(all_interest_series)
required_months = loan_duration * 12

if start_offset + required_months > max_available_months:
    start_offset = max(0, max_available_months - required_months)

if start_offset + required_months > max_interest_months:
    start_offset = max(0, max_interest_months - required_months)

start_offset = max(0, start_offset)

price_path = sp_prices[start_offset:start_offset+loan_duration*12]
price_paths=[(0,price_path)]
interest_series = all_interest_series[start_offset:start_offset+loan_duration*12]

# Handle case where we don't have enough data
if len(price_path) == 0:
    price_path = [100] * (loan_duration * 12)
if len(interest_series) == 0:
    interest_series = [0.04] * (loan_duration * 12)

dt = 1.0/12
S0=price_path[0]

insurance_cost = insurance_cost_pa*total_loan*loan_duration

# Call our debug function
debug_result = debug_single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin,insurance_cost,
                    interest_series,wholesale_lending_margin,additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss,hedging_cap, hedging_cost_pa)