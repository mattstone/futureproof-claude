import sys
import json
import math
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from statistics import geometric_mean

import pprint
import math
import numpy_financial as npf
from core_model import single_mortgage, gen_monte_carlo_paths
from utils import mean_sd, dollar, pcntdf, pcnt, secant

input = json.loads(sys.stdin.read())
output = {}

#house_value = input['house_value'] # 1500000  # @param {type:"slider", min:500000, max:5000000, step:10000}

loan_type = input['loan_type'] #"Interest only" # @param ["Interest only", "Principal+Interest", "Hybrid"]
loan_to_value = 0.8 #input['loan_to_value']/100 #0.8  # @param {type:"slider", min:0.1, max:0.80, step:0.01}


at_risk_captital_fraction = input['at_risk_captital_fraction']/100 #0 # @param {type:"slider", min:0, max:1, step:0.01}


#total_loan = house_value * loan_to_value

annual_income_pcnt = input['annual_income_pcnt']/100 #0.04 # @param {type:"slider", min:0.01, max:0.08, step:0.0025}

annual_house_price_appreciation = input['annual_house_price_appreciation']/100 #0.04 # @param {type:"slider", min:0.01, max:0.08, step:0.0025}

insurer_profit_margin = input['insurer_profit_margin']/100 #0.5 # @param {type:"slider", min:0.0, max:1.0, step:0.05}

insurance_profit_margin = 1.0+ insurer_profit_margin

#@markdown ## Loan parameters

wholesale_lending_margin = input['wholesale_lending_margin']/100 #0.02 # @param {type:"slider", min:0.00, max:0.04, step:0.0025}
# retail lending, FP loan margin. not premium
additional_loan_margins = input['additional_loan_margins']/100 #0.015 # @param {type:"slider", min:0.00, max:0.02, step:0.0025}
#interest_on_deferred = 0
### @param {type:"slider", min:0.00, max:0.09, step:0.0025}

holiday_enter_fraction = input['holiday_enter_fraction'] #1.35 # @param {type:"slider", min:0.5, max:3.5, step:0.05}
holiday_exit_fraction = input['holiday_exit_fraction'] #1.95 # @param {type:"slider", min:0.5, max:3.5, step:0.05}
superpay_start_factor = input['superpay_start_factor']
max_superpay_factor = input['max_superpay_factor']
#insurance_total_cost = 27700 # @param {type:"slider", min:0, max:100000, step:100}
subperform_loan_threshold_quarters = input['subperform_loan_threshold_quarters'] #6 # @param {type:"slider", min:4, max:20, step:1}
enable_pool = input['enable_pool']
np.random.seed(input['random_seed'])

#insurance_cost_pa = input['insurance_cost_pa']/100
year0 = input['year0'] # 1500000  # @param {type:"slider", min:500000, max:5000000, step:10000}

sp500df = pd.read_csv('sp500tr.csv', thousands=',')
fedfunds = pd.read_csv('FEDFUNDS2.csv')

all_interest_series = list(map(lambda x: x/100, fedfunds['FEDFUNDS'].values.tolist()))


sp_prices = sp500df['AdjClose'].values.tolist()
sp_prices.reverse()
 
dt = 1.0/12

funding_fractions = {
  15: input['fraction_15']/100,
  20: input['fraction_20']/100,
  25: input['fraction_25']/100,
  30: 1.0 - input['fraction_15']/100 - input['fraction_20']/100 - input['fraction_25']/100,
}

funding_per_year = input['funding_per_year']*1000000
mc_price_paths = gen_monte_carlo_paths(30, 0.0975, 0.15, 500, 100)

insurance_cost_per_duration = {}
expected_units_sold_per_duration = {}
mean_reinvestment_per_duration = {}
cash_rate = 0.0435

for loan_duration in [15, 20, 25, 30]:
  total_loan = 1200000
  house_value = total_loan/0.8
  annuity_duration=loan_duration/3.0
  annual_income = house_value* annual_income_pcnt
  reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan
  S0=100
  dt1 = 1.0/120
  repaymemt_amount_max = 0.0 if loan_type == "Principal+Interest"  else annual_income* annuity_duration
  final_home_value = house_value * pow(1+annual_house_price_appreciation, loan_duration)

  at_risk_capital = (final_home_value- house_value)*at_risk_captital_fraction


  
  def simulate_with_insurance(insurance_cost):
    return single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                      insurance_profit_margin,insurance_cost,
                      cash_rate,wholesale_lending_margin,additional_loan_margins,
                      holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                      mc_price_paths, S0, dt1, max_superpay_factor, superpay_start_factor)
  def insurance_deficit(insurance_cost):
    df = simulate_with_insurance(insurance_cost)
    dfend = df[df['Period']==loan_duration*4]
    insurance_payout = (total_loan + dfend['InterestDeficit'] - dfend["Reinvestment"] - repaymemt_amount_max - at_risk_capital).clip(0, None).mean()
    #print("insurance deficit", insurance_payout - insurance_cost)
    return insurance_payout - insurance_cost


  insurance_secant = secant(insurance_deficit,10000,50000,250)
  df = simulate_with_insurance(insurance_secant)
  
  initial_units = df.at[0, 'Units'].mean()
  final_units = df.at[len(df.index)-1, 'Units'].mean()
  expected_units_sold_per_duration[loan_duration] = 1-final_units/initial_units
  insurance_cost_per_duration[loan_duration] = insurance_secant/loan_duration/total_loan
  mean_reinvest = df.groupby('Period')['Reinvestment'].mean().iloc[:].values
  initial_reinvest = total_loan*reinvest_fraction - insurance_profit_margin*insurance_secant/ pow(1 + cash_rate, loan_duration)
  mean_reinvestment_per_duration[loan_duration] = mean_reinvest/initial_reinvest


# initialise df
bookdata = []
for year in range(year0,2024):
  for quarter_offset in [0, 0.25, 0.5, 0.75]:
    bookdata.append({
      'Year': year+quarter_offset,
      'Reinvestment': 0,
      'Loan': 0,
      'Units': 0,
      'Surplus': 0,
      'InterestDeficit': 0,
      'SchemeProfit':0,
      'Pool':0,
      'InsuranceClaims':0,
      'InsuranceProfit':0,
      'InsuranceGrossPremium':0,
      'SharedPoolUnits':0
      })

bookdf = pd.DataFrame(bookdata, columns=['Year', 'Reinvestment', 'Loan', 'InterestDeficit','Surplus','Units', 'SchemeProfit', 'Pool', 'InsuranceClaims', 'InsuranceProfit', 'InsuranceGrossPremium', 'SharedPoolUnits'])

output['debug_msgs'] = {
  "insurance_cost_per_duration":insurance_cost_per_duration, 
  "expected_units_sold_per_duration": expected_units_sold_per_duration,
  "MEAN_REINVEST15_2": mean_reinvestment_per_duration[loan_duration][3]
  }
#for year in range(year0,2024):
for year in range(year0,2025):
  # write new mortgages
  for loan_duration in [15, 20, 25, 30]:
    #if loan_duration + year > 2024:
    #  continue
    for quarter_offset in [0, 0.25, 0.5, 0.75]:

      terminates=loan_duration + year + quarter_offset
      sim_loan_duration = math.floor(min(loan_duration,loan_duration- (terminates-2024)))
      annuity_duration = float(loan_duration)/2.0
      start_offset = round((year +quarter_offset - 1988)*12)
     
      price_path = sp_prices[start_offset:start_offset+loan_duration*12]
      price_paths=[(0,price_path)]
      interest_series = all_interest_series[start_offset:start_offset+loan_duration*12]
      if len(price_path) == 0:
        continue
      S0=price_path[0]

      total_loan = funding_per_year*funding_fractions[loan_duration]/4 #div by 4 bec quarterly
      insurance_cost = insurance_cost_per_duration[loan_duration]*total_loan*loan_duration
      annual_income = total_loan * annual_income_pcnt/loan_to_value
      reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan
      initial_reinvestment = total_loan*reinvest_fraction - \
         insurance_profit_margin* insurance_cost/ pow(1 + cash_rate, loan_duration)
      initial_units = initial_reinvestment/S0
      insured_units = initial_units * (1.0-expected_units_sold_per_duration[loan_duration])
      #output['debug_msgs'].append((year, loan_duration, start_offset, len(interest_series)))

      
      df= single_mortgage(total_loan, reinvest_fraction, sim_loan_duration, annual_income, annuity_duration,
                          insurance_profit_margin,insurance_cost,
                          interest_series,wholesale_lending_margin,additional_loan_margins,
                          holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                          price_paths, S0, dt, year-1, max_superpay_factor, superpay_start_factor, enable_pool, insured_units,
                          mean_reinvestment_per_duration[loan_duration])
      for loan_year in range(0, sim_loan_duration):
        for qtr in [0,1,2,3]:
          dfix = loan_year*4+qtr
          bookix = (year+quarter_offset-year0)*4 + loan_year*4 + qtr
          bookdf.at[bookix, 'Reinvestment'] += df.at[dfix, 'Reinvestment']
          bookdf.at[bookix, 'Loan'] +=df.at[dfix, 'Loan size']
          bookdf.at[bookix, 'Units'] +=df.at[dfix, 'Units']
          bookdf.at[bookix, 'Surplus'] +=df.at[dfix, 'Surplus']
          bookdf.at[bookix, 'InterestDeficit'] +=df.at[dfix, 'InterestDeficit']
          bookdf.at[bookix, 'SharedPoolUnits'] +=df.at[dfix, 'CumUnitsToPool']
          bookdf.at[bookix, 'Pool'] += min(insured_units, df.at[dfix, 'Units']) #df.at[dfix, 'Units'] * (1-expected_units_sold_per_duration[loan_duration])
      nrows = df.shape[0]
      repayment = 0 if loan_type =="Principal+Interest" else annual_income*annuity_duration

      balance = df.at[nrows-1, 'Reinvestment'] +repayment - df.at[nrows-1, 'Loan size'] \
         - df.at[nrows-1, 'InterestDeficit'] 
      profit = max(balance, 0)
      insurance_claim = -min(balance, 0)
      insurance_profit =  insurance_profit_margin*insurance_cost - insurance_claim
      avg_cash_rate = geometric_mean(all_interest_series)
      insurance_premium =  insurance_profit_margin*insurance_cost/ pow(1 + avg_cash_rate, loan_duration)
      fromIx = round((year+quarter_offset-year0)*4) +loan_duration*4
      if fromIx < (2024-year0)*4:
        bookdf.at[fromIx, 'InsuranceClaims']+=insurance_claim
        bookdf.at[fromIx, 'InsuranceProfit']+=insurance_profit

      loanStartIx = round((year+quarter_offset-year0)*4) 
      if loanStartIx <  bookdf.shape[0]-1:
        bookdf.at[loanStartIx, 'InsuranceGrossPremium']+=insurance_premium

      for bookix in range(fromIx, bookdf.shape[0]-1):
        bookdf.at[bookix, 'SchemeProfit'] += balance
        bookdf.at[bookix, 'SharedPoolUnits'] += df.at[nrows-1, 'CumUnitsToPool']/2 #lender takes 50%
        
bookdf = bookdf.drop(bookdf[bookdf.Year >2023].index)
  # transact terminating mortgages
bookdf['CumInsuranceClaims'] =bookdf['InsuranceClaims'].cumsum()
bookdf['CumInsuranceProfit'] =bookdf['InsuranceProfit'].cumsum()
bookdf['CumInsuranceGrossPremium'] =bookdf['InsuranceGrossPremium'].cumsum()
bookdf['HedgedUnits'] =bookdf['Units'] - bookdf['Pool']
output['bookdf'] = bookdf.to_dict('list')

#output['debug_msgs'] = #{'insurance_cost':insurance_cost, "interest": interest_series }

print(json.dumps(output))