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
from core_model_advanced import single_mortgage, accounts_table
from utils import mean_sd, dollar, pcntdf, pcnt, secant

# Parameters from Ruby form
output = {}

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
superpay_start_factor = 1.0
max_superpay_factor = 1.0

insurance_cost_pa = 0.02
year0 = 2000
hedged = False
hedging_max_loss = 0.1
hedging_cap = 0.2
hedging_cost_pa = 0.01

# Load historical data
sp500df = pd.read_csv('sp500tr.csv', thousands=',')
fedfunds = pd.read_csv('FEDFUNDS2.csv')

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

output['sp500df'] = sp500df.to_dict('list')
output['price_paths'] = price_paths

insurance_cost = insurance_cost_pa*total_loan*loan_duration

df= single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin,insurance_cost,
                    interest_series,wholesale_lending_margin,additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss,hedging_cap, hedging_cost_pa )
df["CumAnnuityIncome"] = df["AnnuityIncome"].cumsum()                    
df["CumInterestAccrued"] = df["Interest"].cumsum()                    
df["CumInterestPaid"] = df["InterestPaid"].cumsum()                    
output['pathdf'] = df.to_dict('list')
output["accounts_table"] = accounts_table(df).to_dict('list')

output['debug_msgs'] = {'insurance_cost':insurance_cost, "interest": interest_series }

print(json.dumps(output))
