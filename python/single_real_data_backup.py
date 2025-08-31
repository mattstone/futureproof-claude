import sys
import json
import math
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import pprint
import math
import numpy_financial as npf
from core_model import single_mortgage, accounts_table
from utils import mean_sd, dollar, pcntdf, pcnt, secant

# Internal input variables (replacing JSON input)
output = {}

house_value = 1500000  # @param {type:"slider", min:500000, max:5000000, step:10000}

loan_duration = 30  # @param {type:"slider", min:5, max:30, step:1}
annuity_duration = 15  # @param {type:"slider", min:5, max:30, step:1}
loan_type = "Interest only"  # @param ["Interest only", "Principal+Interest", "Hybrid"]
loan_to_value = 0.8  # @param {type:"slider", min:0.1, max:0.80, step:0.01}

principal_repayment = False  # Default boolean value

annual_income = 30000  # @param {type:"slider", min:5000, max:100000, step:500}

at_risk_captital_fraction = 0.0  # @param {type:"slider", min:0, max:1, step:0.01}

total_loan = house_value * loan_to_value

reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan

annual_house_price_appreciation = 0.04  # @param {type:"slider", min:0.01, max:0.08, step:0.0025}

insurer_profit_margin = 0.5  # @param {type:"slider", min:0.0, max:1.0, step:0.05}

insurance_profit_margin = 1.0+ insurer_profit_margin

#@markdown ## Loan parameters

wholesale_lending_margin = 0.02  # @param {type:"slider", min:0.00, max:0.04, step:0.0025}
# retail lending, FP loan margin. not premium
additional_loan_margins = 0.015  # @param {type:"slider", min:0.00, max:0.02, step:0.0025}
#interest_on_deferred = 0
### @param {type:"slider", min:0.00, max:0.09, step:0.0025}

holiday_enter_fraction = 1.35  # @param {type:"slider", min:0.5, max:3.5, step:0.05}
holiday_exit_fraction = 1.95  # @param {type:"slider", min:0.5, max:3.5, step:0.05}
#insurance_total_cost = 27700 # @param {type:"slider", min:0, max:100000, step:100}
subperform_loan_threshold_quarters = 6  # @param {type:"slider", min:4, max:20, step:1}
superpay_start_factor = 1.0  # Default value
max_superpay_factor = 1.0  # Default value

insurance_cost_pa = 0.02  # Default 2% per annum
year0 = 2000  # Default start year
principal_repayment = False  # Default boolean value
sp500df = pd.read_csv('sp500tr.csv', thousands=',')
fedfunds = pd.read_csv('FEDFUNDS2.csv')
hedged = False  # Default no hedging
hedging_max_loss = 0.1  # Default 10% max loss
hedging_cap = 0.2  # Default 20% cap
hedging_cost_pa = 0.01  # Default 1% cost per annum

all_interest_series = list(map(lambda x: x/100, fedfunds['FEDFUNDS'].values.tolist()))

sp_prices = sp500df['AdjClose'].values.tolist()
sp_prices.reverse()
 
start_offset = (year0 - 1988)*12

# Ensure we have enough data, otherwise use the latest available data
max_available_months = len(sp_prices)
max_interest_months = len(all_interest_series)
required_months = loan_duration * 12

if start_offset + required_months > max_available_months:
    start_offset = max(0, max_available_months - required_months)
    
if start_offset + required_months > max_interest_months:
    start_offset = max(0, max_interest_months - required_months)

# Ensure we don't go negative
start_offset = max(0, start_offset)

price_path = sp_prices[start_offset:start_offset+loan_duration*12]
price_paths=[(0,price_path)]
interest_series = all_interest_series[start_offset:start_offset+loan_duration*12]

# Handle case where we don't have enough data
if len(price_path) == 0:
    price_path = [100] * (loan_duration * 12)  # Fallback to constant price
if len(interest_series) == 0:
    interest_series = [0.04] * (loan_duration * 12)  # Fallback to 4% interest rate

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
#output["loan_ts"] = df["Loan Size"].iloc[:].values


output['debug_msgs'] = {'insurance_cost':insurance_cost, "interest": interest_series }

print(json.dumps(output))