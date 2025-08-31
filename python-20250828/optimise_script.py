import sys
import json
import math
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import pprint
import math
import numpy_financial as npf
from scipy.optimize import minimize
from core_model import single_mortgage, gen_monte_carlo_paths, main_outputs_table
from utils import mean_sd, dollar, pcntdf, pcnt, secant
import random

outfnm = "optim_out.csv"

#write the header once
with open(outfnm,'w') as f:
  f.write('loan_duration, annuity_duration, loan_type, annual_income, total_income, roi, pcnt_hol, insurance_pa, holiday_enter, holiday_exit, repay_amount_factor, repay_start_factor, funder_profit_share, surplus, interest_deficit, funder_earned, cum_interest_paid \n')

# append a line to the output
def write(o):
  total = annual_income*annuity_duration
  print("writing", o)
  with open(outfnm, "a") as myfile:
    myfile.write("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13},{14},{15},{16}\n".format(
      o['loan_duration'],
      o['annuity_duration'],
      o['loan_type'],
      round(o['annual_income']),
      round(total),
      round(o['roi']*100),
      round(o['pcnt_hol']*1000)/10,
      round(o['insurance_pa']*10000)/100,
      round(o['holiday_enter']*100)/100,
      round(o['holiday_exit']*100)/100,
      round(o['max_superpay_factor']*100)/100,
      round(o['superpay_start_factor']*100)/100,
      round(o['funder_profit_share'].item()),
      round(o['surplus'].item()),
      round(o['interest_deficit'].item()),
      round(o['funder_earned'].item()),
      round(o['cum_interest_paid'].item())
     ))

house_value = 1500000

loan_to_value = 0.8


annual_income_from = 500
annual_income_to = 30000

at_risk_captital_fraction = 0

total_loan = house_value * loan_to_value

equity_return = 0.0975

volatility = 0.15
S0 = 100 

total_paths = 200

cash_rate = 0.0435 

annual_house_price_appreciation = 0.04

insurer_profit_margin = 0.50

insurance_profit_margin = 1.0+ insurer_profit_margin


wholesale_lending_margin = 0.02
# retail lending, FP loan margin. not premium
additional_loan_margins = 0.0125
#interest_on_deferred = 0
### @param {type:"slider", min:0.00, max:0.09, step:0.0025}
loan_interest_rate = cash_rate+wholesale_lending_margin+additional_loan_margins




holiday_enter_fraction_from = 0.8
holiday_enter_fraction_to = 1.1
holiday_exit_fraction_delta_from = 0.15
holiday_exit_fraction_delta_to = 0.7

subperform_loan_threshold_quarters = 12
superpay_start_factor_from = 1.0
superpay_start_factor_to = 1.5

max_superpay_factor_from = 0.5
max_superpay_factor_to = 1.5
np.random.seed(0)

price_paths = gen_monte_carlo_paths(30, equity_return, volatility, total_paths, S0)

dt = 1.0/120

maxfev = 250

roi_lower_limit = 2.5
holiday_upper_limit = 0.25
insurance_upper_limit = 0.075

for loan_duration in [30,25,20, 15]:
  for annuity_duration in [10, 15, 20, 25, 30]:
    for loan_type in ["Interest only","Principal+Interest"]:
      if annuity_duration > loan_duration:
        continue

      output = {
        'loan_duration': loan_duration,
        'annuity_duration': annuity_duration,
        'loan_type': loan_type
      }
      print(output)


      final_home_value = house_value * pow(1+annual_house_price_appreciation, loan_duration)

      at_risk_capital = (final_home_value- house_value)*at_risk_captital_fraction


      lender_profit_share = 0.5

      borrower_profit_share = 0.3


      N = round(loan_duration/dt)




      def get_df_for_hol_params(holiday_enter_fraction, holiday_exit_fraction, max_superpay_factor, superpay_start_factor, annual_income):
        reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan
        repaymemt_amount_max = 0.0 if loan_type == "Principal+Interest"  else annual_income* annuity_duration
        def simulate_with_insurance(insurance_cost):
          return single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                            insurance_profit_margin,insurance_cost,
                            cash_rate,wholesale_lending_margin,additional_loan_margins,
                            holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                            price_paths, S0, dt, 0, max_superpay_factor, superpay_start_factor )

        def insurance_deficit(insurance_cost):
          df = simulate_with_insurance(insurance_cost)
          dfend = df[df['Period']==loan_duration*4]
          insurance_payout = (total_loan + dfend['InterestDeficit'] - dfend["Reinvestment"] - repaymemt_amount_max - at_risk_capital).clip(0, None).mean()
          #print("insurance deficit", insurance_payout - insurance_cost)
          return insurance_payout - insurance_cost

        insurance_secant = secant(insurance_deficit,50000,100000,1000)

        df = simulate_with_insurance(insurance_secant)
        return (df, insurance_secant)

 
      def eprint(*args, **kwargs):
          print(*args, file=sys.stderr, **kwargs)

      def objective_function(hols):
        eprint("Eval objective with hols", hols[0], hols[1], hols[4])
        try:
          (df, insurance) = get_df_for_hol_params(hols[0], hols[0]+hols[1], hols[2], hols[3], hols[4])
          eprint("Got insurance", insurance)

          dfend = df[df['Period']==loan_duration*4]
          lender_profit_share_amt = (lender_profit_share*(dfend["Reinvestment"] - total_loan - dfend['InterestDeficit'])).clip(0, None)
          roi = (dfend['FunderEarned'].mean()+lender_profit_share_amt.mean() +dfend['InterestDeficit'].mean())/total_loan
          pcnt_hol = df['Prob Holiday'].mean()
          insurance_pa = insurance/total_loan / loan_duration
          penalty = 0

          if roi < roi_lower_limit:
            penalty +=  (roi_lower_limit - roi)/10
          if pcnt_hol >holiday_upper_limit:
            penalty += (pcnt_hol - holiday_upper_limit)*10
          if insurance_pa > insurance_upper_limit:
            penalty += (insurance_pa - insurance_upper_limit)*100

          penalty = penalty * 1000
          
          eprint("Obj value=", penalty - hols[4]/1000, "penalty=", penalty, "optval=", hols[4]/1000, "roi=", roi, "hol=", pcnt_hol, "ins=", insurance_pa)
          return penalty - hols[4]/1000

        except ValueError:
          eprint("Exception!")
          return 1000

      bounds = [
        (holiday_enter_fraction_from, holiday_enter_fraction_to),
        (holiday_exit_fraction_delta_from, holiday_exit_fraction_delta_to), 
        (max_superpay_factor_from, max_superpay_factor_to),
        (superpay_start_factor_from, superpay_start_factor_to),
        (annual_income_from, annual_income_to),
      ]

      try:
        ini_f = 1000
        while ini_f > 999:
          midbounds = [random.uniform(lo,hi) for (lo,hi) in bounds]
          ini_f = objective_function(midbounds)
          print("finding initial", midbounds, ini_f)

        result = minimize(objective_function, midbounds, method='nelder-mead', bounds=bounds, options={
            'maxfev':maxfev,
            #'initial_simplex': [[1.3, 0.4], [1.4, 0.4], [1.3, 0.5]],    
          })

        
        output['annual_income']=result['x'][4]

        (optimdf, insurance_cost) = get_df_for_hol_params(result['x'][0], result['x'][0]+result['x'][1], result['x'][2], result['x'][3], result['x'][4])
        annual_income = result['x'][4]
        reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan
        repaymemt_amount_max = 0.0 if loan_type == "Principal+Interest"  else annual_income* annuity_duration
        outdf = main_outputs_table(optimdf,total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                            insurance_profit_margin,insurance_cost, total_paths, loan_type, cash_rate,
                            at_risk_captital_fraction, house_value, final_home_value)
        df = optimdf
        dfend = df[df['Period']==loan_duration*4]
        lender_profit_share_amt = (lender_profit_share*(dfend["Reinvestment"] - total_loan - dfend['InterestDeficit'])).clip(0, None)
        roi = (dfend['FunderEarned'].mean()+lender_profit_share_amt.mean() +dfend['InterestDeficit'].mean())/total_loan
        pcnt_hol = df['Prob Holiday'].mean()
        insurance_pa = insurance_cost/total_loan / loan_duration
        output["roi"] = roi
        output["pcnt_hol"] = pcnt_hol
        output["insurance_pa"] = insurance_pa
        output["holiday_enter"] = result['x'][0]
        output["holiday_exit"] = result['x'][0]+result['x'][1]
        output["max_superpay_factor"] =result['x'][2]
        output["superpay_start_factor"] =result['x'][3]
        output["funder_profit_share"] =lender_profit_share_amt.mean()
        output["surplus"] =dfend['Surplus'].mean()
        output["interest_deficit"] =dfend['InterestDeficit'].mean()
        output["funder_earned"] =dfend['FunderEarned'].mean() #
        output["cum_interest_paid"] = dfend["CumInterestPaid"].mean()

#        print("writing prfshare", lender_profit_share_amt, type(lender_profit_share_amt))
        

        write(output)
      except ValueError as e:
        eprint("Conditions not found", e)
        

#output['result'] = objective_function([1.0,0.2])
#output['df'] = pd.DataFrame(df_data).to_dict('list')

def default(obj):
    if type(obj).__module__ == np.__name__:
        if isinstance(obj, np.ndarray):
            return obj.tolist()
        else:
            return obj.item()
    raise TypeError('Unknown type:', type(obj))


