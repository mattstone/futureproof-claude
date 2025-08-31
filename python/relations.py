import sys
import json
import math
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import pprint
import math
import numpy_financial as npf
from core_model import single_mortgage, gen_monte_carlo_paths
from utils import mean_sd, dollar, pcntdf, pcnt, secant

input = json.loads(sys.stdin.read())
output = {}


house_value = input['house_value'] # 1500000  # @param {type:"slider", min:500000, max:5000000, step:10000}

loan_duration = input['loan_duration'] # 30 # @param {type:"slider", min:5, max:30, step:1}
annuity_duration = input['annuity_duration'] #15 # @param {type:"slider", min:5, max:30, step:1}
loan_type = input['loan_type'] #"Interest only" # @param ["Interest only", "Principal+Interest", "Hybrid"]
loan_to_value = input['loan_to_value']/100 #0.8  # @param {type:"slider", min:0.1, max:0.80, step:0.01}


annual_income = input['annual_income'] #30000 # @param {type:"slider", min:5000, max:100000, step:500}

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

annual_house_price_appreciation = input['annual_house_price_appreciation']/100 #0.04 # @param {type:"slider", min:0.01, max:0.08, step:0.0025}

insurer_profit_margin = input['insurer_profit_margin']/100 #0.5 # @param {type:"slider", min:0.0, max:1.0, step:0.05}

insurance_profit_margin = 1.0+ insurer_profit_margin

#@markdown ## Loan parameters

wholesale_lending_margin = input['wholesale_lending_margin']/100 #0.02 # @param {type:"slider", min:0.00, max:0.04, step:0.0025}
# retail lending, FP loan margin. not premium
additional_loan_margins = input['additional_loan_margins']/100 #0.015 # @param {type:"slider", min:0.00, max:0.02, step:0.0025}
#interest_on_deferred = 0
### @param {type:"slider", min:0.00, max:0.09, step:0.0025}
loan_interest_rate = cash_rate+wholesale_lending_margin+additional_loan_margins

holiday_enter_fraction_from = input['holiday_enter_fraction_from'] #1.35 # @param {type:"slider", min:0.5, max:3.5, step:0.05}
holiday_enter_fraction_to = input['holiday_enter_fraction_to'] #1.35 # @param {type:"slider", min:0.5, max:3.5, step:0.05}
holiday_exit_fraction_delta_from = input['holiday_exit_fraction_delta_from'] #1.95 # @param {type:"slider", min:0.5, max:3.5, step:0.05}
holiday_exit_fraction_delta_to = input['holiday_exit_fraction_delta_to'] #1.95 # @param {type:"slider", min:0.5, max:3.5, step:0.05}
#insurance_total_cost = 27700 # @param {type:"slider", min:0, max:100000, step:100}
subperform_loan_threshold_quarters = input['subperform_loan_threshold_quarters'] #6 # @param {type:"slider", min:4, max:20, step:1}


final_home_value = house_value * pow(1+annual_house_price_appreciation, loan_duration)

at_risk_capital = (final_home_value- house_value)*at_risk_captital_fraction


lender_profit_share = 0.5

borrower_profit_share = 0.3

#annual_income = total_loan * (1-reinvest_fraction) / loan_duration
repaymemt_amount_max = 0.0 if loan_type == "Principal+Interest"  else annual_income* annuity_duration
dt = 1.0/120

N = round(loan_duration/dt)


price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)

def get_df_for_hol_params(holiday_enter_fraction, holiday_exit_fraction):

  def simulate_with_insurance(insurance_cost):
    return single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                      insurance_profit_margin,insurance_cost,
                      cash_rate,wholesale_lending_margin,additional_loan_margins,
                      holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                      price_paths, S0, dt)
    
  def insurance_deficit(insurance_cost):
    df = simulate_with_insurance(insurance_cost)
    dfend = df[df['Period']==loan_duration*4]
    insurance_payout = (total_loan + dfend['InterestDeficit'] - dfend["Reinvestment"] - repaymemt_amount_max - at_risk_capital).clip(0, None).mean()
    #print("insurance deficit", insurance_payout - insurance_cost)
    return insurance_payout - insurance_cost

  insurance_secant = secant(insurance_deficit,50000,100000,500)

  df = simulate_with_insurance(insurance_secant)
  return (df, insurance_secant)

df_data = [] 

for enter in np.linspace(holiday_enter_fraction_from, holiday_enter_fraction_to, 5):
  for exitdelta in np.linspace(holiday_exit_fraction_delta_from, holiday_exit_fraction_delta_to, 5):
    try:
      (df, insurance) = get_df_for_hol_params(enter, enter+exitdelta)
      dfend = df[df['Period']==loan_duration*4]
      lender_profit_share_amt = (lender_profit_share*(dfend["Reinvestment"] - total_loan - dfend['InterestDeficit'])).clip(0, None)
      roi = 100*(dfend['FunderEarned'].mean()+lender_profit_share_amt.mean() +dfend['InterestDeficit'].mean())/total_loan

      df_data.append({
        "enter": enter,
        "exitdelta": exitdelta,
        "frac": 100*df['Prob Holiday'].mean(),
        "insurance": insurance,
        "roi": roi,
        "deficit": dfend['InterestDeficit'].mean(),
        "surplus": dfend['Surplus'].mean(),
        "profit_share": lender_profit_share_amt.mean(),
      })
    except:
      pass

output['df'] = pd.DataFrame(df_data).to_dict('list')

print(json.dumps(output))