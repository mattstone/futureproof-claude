import sys
import json
import math
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import pprint
import math
import numpy_financial as npf
from core_model import single_mortgage, gen_monte_carlo_paths, main_outputs_table, accounts_table
from utils import mean_sd, dollar, pcntdf, pcnt, secant

input = json.loads(sys.stdin.read())
output = {}


house_value = input['house_value'] # 1500000  # @param {type:"slider", min:500000, max:5000000, step:10000}

loan_duration = input['loan_duration'] # 30 # @param {type:"slider", min:5, max:30, step:1}
annuity_duration = input['annuity_duration'] #15 # @param {type:"slider", min:5, max:30, step:1}
loan_type = input['loan_type'] #"Interest only" # @param ["Interest only", "Principal+Interest", "Hybrid"]
loan_to_value = input['loan_to_value']/100 #0.8  # @param {type:"slider", min:0.1, max:0.80, step:0.01}


annual_income = input['annual_income'] #30000 # @param {type:"slider", min:5000, max:100000, step:500}
principal_repayment = input['principal_repayment']
at_risk_captital_fraction = input['at_risk_captital_fraction']/100 #0 # @param {type:"slider", min:0, max:1, step:0.01}

total_loan = house_value * loan_to_value

reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan

# param {type:"slider", min:0.1, max:0.80, step:0.01}

#annual_income = total_loan*(1-reinvest_fraction)/annuity_duration
#1-(annuity_duration*annual_income)/total_loan


#0.6# @param {type:"slider", min:0.4, max:0.8, step:0.01}


#@markdown ##Economic assumptions
# total return of S&P 500
equity_return = input['equity_return']/100 #0 # 0.0975 # @param {type:"slider", min:0.06, max:0.12, step:0.0025}
# annual standard deviation
volatility = input['volatility']/100 #0.15  # @param {type:"slider", min:0.1, max:0.30, step:0.01}
S0 = 100 # initial share price - can be anything

total_paths = input['total_paths'] #500 # @param {type:"slider", min:100, max:20000, step:100}

cash_rate = input['cash_rate']/100 #0.0435 # @param {type:"slider", min:0.02, max:0.06, step:0.0005}

annual_house_price_appreciation = input.get('annual_house_price_appreciation',4)/100 #0.04 # @param {type:"slider", min:0.01, max:0.08, step:0.0025}

insurer_profit_margin = input.get('insurer_profit_margin',50.0)/100 #0.5 # @param {type:"slider", min:0.0, max:1.0, step:0.05}

insurance_profit_margin = 1.0+ insurer_profit_margin

#@markdown ## Loan parameters

wholesale_lending_margin = input['wholesale_lending_margin']/100 #0.02 # @param {type:"slider", min:0.00, max:0.04, step:0.0025}
# retail lending, FP loan margin. not premium
additional_loan_margins = input['additional_loan_margins']/100 #0.015 # @param {type:"slider", min:0.00, max:0.02, step:0.0025}
#interest_on_deferred = 0
### @param {type:"slider", min:0.00, max:0.09, step:0.0025}
loan_interest_rate = cash_rate+wholesale_lending_margin+additional_loan_margins

holiday_enter_fraction = input['holiday_enter_fraction'] #1.35 # @param {type:"slider", min:0.5, max:3.5, step:0.05}
holiday_exit_fraction = input['holiday_exit_fraction'] #1.95 # @param {type:"slider", min:0.5, max:3.5, step:0.05}
#insurance_total_cost = 27700 # @param {type:"slider", min:0, max:100000, step:100}
subperform_loan_threshold_quarters = input['subperform_loan_threshold_quarters'] #6 # @param {type:"slider", min:4, max:20, step:1}
superpay_start_factor = input['superpay_start_factor']
max_superpay_factor = input['max_superpay_factor']
enable_pool = input['enable_pool']
hedged = input['hedged'] 
hedging_max_loss = input.get('hedging_max_loss', 10)/100
hedging_cap = input.get('hedging_cap', 20)/100
hedging_cost_pa = input.get('hedging_cost_pa', 1.4)/100

np.random.seed(input['random_seed'])

final_home_value = house_value * pow(1+annual_house_price_appreciation, loan_duration)

at_risk_capital = (final_home_value- house_value)*at_risk_captital_fraction



lender_profit_share = 0.5

borrower_profit_share = 0.3

#annual_income = total_loan * (1-reinvest_fraction) / loan_duration
repaymemt_amount_max = 0.0 if loan_type == "Principal+Interest"  else annual_income* annuity_duration
dt = 1.0/120

N = round(loan_duration/dt)


price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)

insured_units = 0
expected_mean_reinvestment = None
insurance_secant = None

def get_pool_parameters():
  global insurance_secant
  global expected_mean_reinvestment
  global insured_units
  def simulate_with_insurance1(insurance_cost):
    return single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                      insurance_profit_margin,insurance_cost,
                      cash_rate,wholesale_lending_margin,additional_loan_margins,
                      holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                      price_paths, S0, dt, 0, max_superpay_factor, superpay_start_factor, enable_pool, 0, None, principal_repayment)
    
  def insurance_deficit1(insurance_cost):
    df = simulate_with_insurance1(insurance_cost)
    dfend = df[df['Period']==loan_duration*4]
    insurance_payout = (total_loan + dfend['InterestDeficit'] - dfend["Reinvestment"] - repaymemt_amount_max - at_risk_capital).clip(0, None).mean()
    #print("insurance deficit", insurance_payout - insurance_cost)
    return insurance_payout - insurance_cost

  insurance_secant1 = secant(insurance_deficit1,10000,50000,250)


  df = simulate_with_insurance1(insurance_secant1)

  initial_units = df.at[0, 'Units'].mean()
  final_units = df.at[len(df.index)-1, 'Units'].mean()
  insured_units = final_units
  insurance_secant = insurance_secant1
  mean_reinvest = df.groupby('Period')['Reinvestment'].mean().iloc[:].values
  initial_reinvest = total_loan*reinvest_fraction - insurance_profit_margin*insurance_secant/ pow(1 + cash_rate, loan_duration)
  expected_mean_reinvestment = mean_reinvest/initial_reinvest

def simulate_with_insurance(insurance_cost):
  return single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin,insurance_cost,
                    cash_rate,wholesale_lending_margin,additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, 0, max_superpay_factor, superpay_start_factor, 
                    enable_pool,insured_units, expected_mean_reinvestment, principal_repayment, hedged, hedging_max_loss,hedging_cap, hedging_cost_pa )
  
def insurance_deficit(insurance_cost):
  df = simulate_with_insurance(insurance_cost)
  dfend = df[df['Period']==loan_duration*4]
  insurance_payout = (total_loan + dfend['InterestDeficit'] - dfend["Reinvestment"] - repaymemt_amount_max - at_risk_capital).clip(0, None).mean()
  #print("insurance deficit", insurance_payout - insurance_cost)
  return insurance_payout - insurance_cost
if hedged:
  insurance_secant = 0.0
  df = simulate_with_insurance(0.0)
else:
  if enable_pool:
    get_pool_parameters()
  else: 
    insurance_secant = secant(insurance_deficit,10000,50000,250)
  if insurance_secant is None:
    raise Exception("secant is none")
  df = simulate_with_insurance(insurance_secant)

dfend = df[df['Period']==loan_duration*4]
worse_pathn = dfend.sort_values('SP500').iloc[round(0.02*total_paths)]['Path']
bad_pathn = dfend.sort_values('SP500').iloc[round(0.25*total_paths)]['Path']
good_pathn = dfend.sort_values('SP500').iloc[round(0.75*total_paths)]['Path']
median_pathn = dfend.sort_values('SP500').iloc[round(0.50*total_paths)]['Path']
worse_end_ix = df[(df['Path']==worse_pathn) & (df['Period']==loan_duration*4)].index[0]
bad_end_ix = df[(df['Path']==bad_pathn) & (df['Period']==loan_duration*4)].index[0]
good_end_ix = df[(df['Path']==good_pathn) & (df['Period']==loan_duration*4)].index[0]
median_end_ix = df[(df['Path']==median_pathn) & (df['Period']==loan_duration*4)].index[0]

#'negative reinvestment account {0:.2f}'.format(initial_reinvest) if initial_reinvest<0 else outdf

outdf = main_outputs_table(df,total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin,insurance_secant, total_paths, loan_type, cash_rate,
                    at_risk_captital_fraction, house_value, final_home_value, hedged)

output["outdf"]  =outdf.to_dict('list')
periods_list = list(df.groupby('Period')['Period'].mean().iloc[:].values)
output["mean_period"] = periods_list
output["mean_units"] = list(df.groupby('Period')['Units'].mean().iloc[:].values)
output["mean_surplus"] = list(df.groupby('Period')['Surplus'].mean().iloc[:].values)
output["pool_units"] = list(df.groupby('Period')['CumUnitsToPool'].mean().iloc[:].values)
output["mean_hedged_units"] = list((df.groupby('Period')['Units'].mean()-insured_units).iloc[:].values)
output["mean_reinvest"] = list(df.groupby('Period')['Reinvestment'].mean().iloc[:].values)
output["mean_loan"] = list(df.groupby('Period')['Loan size'].mean().iloc[:].values)
output["mean_deficit"] = list(df.groupby('Period')['InterestDeficit'].mean().iloc[:].values)
output["mean_insured_units"] = list((df.groupby('Period')['Units'].mean()*0+insured_units).iloc[:].values)
output["mean_cumanninc"] = list(df.groupby('Period')['AnnuityIncome'].mean().cumsum().iloc[:].values)
output["mean_cumintraccr"] = list(df.groupby('Period')['Interest'].mean().cumsum().iloc[:].values)
output["mean_cumintpaid"] = list(df.groupby('Period')['InterestPaid'].mean().cumsum().iloc[:].values)

table_type = input["path_table_type"]

mc_prices = []
for pathn in range(0,100):
  mc_prices.append(list(df[df['Path']==pathn]['SP500'].values))
output["mc_prices"] = mc_prices

if table_type == "Mean":
  output["accounts_table"] = accounts_table(df.groupby('Period').mean()).to_dict('list')
  output["pathdf"]  = df.groupby('Period').mean().to_dict('list')
  #output["mean_units"] = list(df.groupby('Period')['Units'].mean().iloc[:].values)
  #output["mean_reinvest"] = list(df.groupby('Period')['Reinvestment'].mean().iloc[:].values)
  #output["mean_loan"] = list(df.groupby('Period')['Loan size'].mean().iloc[:].values)

else:
  percentile = 0.02 if table_type== "2% percentile" else \
               0.5 if table_type== "Median" else \
               0.25 if table_type== "25% percentile" else 0.75

  rankn = round(total_paths * percentile)
  pathn = dfend.sort_values('SP500').iloc[rankn]['Path']
  pathdf = df[df['Path']==pathn]
  output["accounts_table"] = accounts_table(pathdf).to_dict('list')
  output["pathdf"]= pathdf.to_dict('list')
  output["mean_units"] = (pathdf['Units'].iloc[:].values).tolist()
  output["mean_reinvest"] = (pathdf['Reinvestment'].iloc[:].values).tolist()
  output["mean_loan"] = (pathdf['Loan size'].iloc[:].values).tolist()

print(json.dumps(output))