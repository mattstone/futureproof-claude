import pandas as pd
import math
from statistics import geometric_mean
import numpy as np
import numpy_financial as npf
from utils import mean_sd, dollar, pcntdf, pcnt, secant


def gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0):
  dt = 1.0/120
  N = round(loan_duration/dt)
  price_paths = []

  for pathn in range(0,total_paths):
    # https://stackoverflow.com/a/13203189
    ts = np.linspace(0, loan_duration, N)
    W = np.random.standard_normal(size = N)
    W = np.cumsum(W)*np.sqrt(dt) ### standard brownian motion ###
    X = (equity_return-0.5*volatility**2)*ts + volatility*W
    S = S0*np.exp(X) ### geometric brownian motion ###
    price_paths.append((pathn,S))
  return price_paths


def single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin,insurance_cost,
                    cash_rate_series,wholesale_lending_margin,additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year_offset=0, max_superpay_factor = 1.0, 
                    superpay_start_factor = 1.0, enable_pool = False, insured_units = 0, 
                    expected_reinvestment_ratio = None, piProgressiveRepayment = False, hedged = False, 
                    hedging_max_loss = 0, hedging_cap = 1000, hedging_cost_pa=0):
  
  # Pre-calculate constants
  is_cash_rate_list = isinstance(cash_rate_series, list)  # isinstance is faster than type()
  avg_cash_rate = geometric_mean(cash_rate_series) if is_cash_rate_list else cash_rate_series
  initial_reinvestment = total_loan*reinvest_fraction - \
     insurance_profit_margin* insurance_cost/ pow(1 + avg_cash_rate, loan_duration)
  
  expected_reinvestment = None
  if expected_reinvestment_ratio is not None:
    expected_reinvestment = expected_reinvestment_ratio * initial_reinvestment
  
  holiday_enter = initial_reinvestment* holiday_enter_fraction
  holiday_exit = initial_reinvestment*holiday_exit_fraction
  
  # Pre-calculate common constants
  quarter_div = 0.25  # Slightly faster than 1.0/4
  dt_quarter_inv = 1.0/(dt*4)
  annual_income_quarter = annual_income * quarter_div
  annuity_duration_quarters = int(annuity_duration * 4)  # Use int for comparisons
  total_periods = int(4 * loan_duration + 1)
  
  # Pre-allocate arrays for better performance
  all_data = []
  
  for (pathn, S) in price_paths:
    # Pre-allocate result array instead of using append
    num_rows = total_periods
    data = np.zeros((num_rows, 29), dtype=object)  # 29 columns in the output
    
    # variables that change every year, initial values set here
    holdings = initial_reinvestment / S0
    cummlative_units_sold = 0.0
    init_units_to_principal = 0.0
    # includes Y1 income
    loan_size = total_loan * reinvest_fraction + annual_income_quarter
    if piProgressiveRepayment:
      init_units_to_principal = annual_income_quarter / S0
      loan_size -= annual_income_quarter 
      holdings -= init_units_to_principal

    in_holiday = holiday_enter_fraction > 1
    holiday_quarters = 0
    cum_units_to_pool = 0.0
    cum_interest_paid = 0.0
    deferred = 0.0
    funder_earned = 0.0

    # Initialize first row
    holdings_s0 = holdings * S0
    data[0] = [pathn, 0, year_offset, 0, S0, 0, round(total_loan * reinvest_fraction), holdings, round(holdings_s0),
               round(0), round(max(loan_size - holdings_s0, 0)), round(holdings_s0 - loan_size - deferred), 
               in_holiday, 0, annual_income_quarter, 0, False, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
               init_units_to_principal, 0, 0]

    last_yearly_hedge_price = S0
    last_5yearly_hedge_price = S0
    
    # Pre-calculate cash rates and prices for vectorized access
    if is_cash_rate_list:
        # Pre-calculate all indices at once
        price_indices = (np.arange(1, total_periods) * dt_quarter_inv - 1).astype(int)
        cash_rates = np.array([cash_rate_series[idx] for idx in price_indices])
        prices = np.array([S[idx] for idx in price_indices])
    else:
        cash_rates = np.full(total_periods-1, cash_rate_series)
        price_indices = (np.arange(1, total_periods) * dt_quarter_inv - 1).astype(int)
        prices = np.array([S[idx] for idx in price_indices])
    
    # Pre-calculate loan interest rates
    loan_interest_rates = cash_rates + wholesale_lending_margin + additional_loan_margins
    
    for i, t in enumerate(range(1, total_periods)):
      s = prices[i]
      cash_rate = cash_rates[i]
      loan_interest_rate = loan_interest_rates[i]
      interest_due = loan_size * loan_interest_rate * quarter_div
      
      # Initialize variables
      interest_paid = 0.0
      interest_paid_to_funder = 0.0
      deferred_delta = 0.0
      units_sold_now = 0.0
      units_to_pool = 0.0
      units_to_principal = 0.0
      
      # Pre-calculate common values
      interest_due_per_share = interest_due / s
      holdings_value = holdings * s  # Calculate once and reuse
      
      if in_holiday:
        if holdings_value > holiday_exit:
          in_holiday = False
          if enable_pool and holdings <= insured_units:
            units_to_pool -= interest_due_per_share
          else: 
            holdings -= interest_due_per_share
            units_sold_now += interest_due_per_share          
          interest_paid = interest_due
          interest_paid_to_funder = loan_size * (wholesale_lending_margin + cash_rate) * quarter_div
          holiday_quarters = 0
        else:
          if enable_pool and holdings <= insured_units:
            units_to_pool -= interest_due_per_share
          else: 
            holiday_quarters += 1
            deferred += interest_due
            deferred_delta += interest_due
      else:
        if holdings_value < holiday_enter:
          if enable_pool and holdings <= insured_units:
            units_to_pool -= interest_due_per_share            
          else: 
            deferred += interest_due
            deferred_delta += interest_due
            in_holiday = True
            holiday_quarters += 1
        else:
          holiday_quarters = 0
          if enable_pool and holdings <= insured_units:
            units_to_pool -= interest_due_per_share
          else: 
            holdings -= interest_due_per_share
            units_sold_now += interest_due_per_share
          interest_paid = interest_due
          interest_paid_to_funder = loan_size * (wholesale_lending_margin + cash_rate) * quarter_div
          if holdings_value > holiday_exit * superpay_start_factor and deferred > 0 and holdings > insured_units:
            surplus_pay = min(max_superpay_factor * interest_due, deferred)
            surplus_pay_per_share = surplus_pay / s
            holdings -= surplus_pay_per_share
            deferred -= surplus_pay
            deferred_delta -= surplus_pay
            units_sold_now += surplus_pay_per_share
            interest_paid += surplus_pay
            interest_paid_to_funder += surplus_pay * (wholesale_lending_margin + cash_rate) / loan_interest_rate
            
      if enable_pool and not in_holiday and deferred < 1 and expected_reinvestment is not None and holdings_value > expected_reinvestment[t] and holdings > insured_units:
        excess_units = (holdings_value - expected_reinvestment[t]) / s
        holdings -= excess_units
        units_to_pool = excess_units
        
      hedge_units_delta = 0.0
      if hedged:
        # Use modulo operations that are pre-calculated for common cases
        t_mod_4 = t & 3  # Bitwise AND is faster than modulo for powers of 2
        if t_mod_4 == 0:
          holdings -= holdings * hedging_cost_pa
          year_move = (s - last_yearly_hedge_price) / last_yearly_hedge_price 
          if year_move < -hedging_max_loss:
            buy_units = ((last_yearly_hedge_price / s) * (1 - hedging_max_loss) - 1) * holdings
            hedge_units_delta = buy_units
            holdings += buy_units            
          last_yearly_hedge_price = s
        if t % 20 == 0:  # 4*5 = 20
          year_move = (s - last_5yearly_hedge_price) / last_5yearly_hedge_price 
          adj_holds = holdings * (last_5yearly_hedge_price / s) * (1 + hedging_cap * 5)
          if holdings > adj_holds:
            sell_units = holdings - adj_holds
            hedge_units_delta -= sell_units
            holdings -= sell_units
          last_5yearly_hedge_price = s

      cum_units_to_pool += units_to_pool
      funder_earned += interest_paid_to_funder
      cummlative_units_sold += units_sold_now
      cum_interest_paid += interest_paid
      yearly_annuity_income = 0.0

      if t < annuity_duration_quarters:
        yearly_annuity_income += annual_income_quarter
        if piProgressiveRepayment:
          units_to_principal = annual_income_quarter / s

      subperform = holiday_quarters >= subperform_loan_threshold_quarters
      
      # Optimized year/quarter calculation using integer operations
      t_minus_1 = t - 1
      year = (t_minus_1 >> 2) + 1  # Bitwise right shift is faster than division by 4
      quarter = t - (year - 1) * 4
      
      # Update holdings value after all calculations
      holdings_value = holdings * s
      
      # Store results in pre-allocated array (avoid repeated rounding in hot path)
      data[t] = [pathn, t, year_offset+year, quarter, s, round(interest_due), round(loan_size), 
                holdings, round(holdings_value), deferred, round(max(loan_size - holdings_value, 0)), 
                round(holdings_value - loan_size - deferred + cum_units_to_pool * s), in_holiday, 
                funder_earned, yearly_annuity_income, holiday_quarters, subperform, interest_paid, 
                interest_paid_to_funder, loan_interest_rate, units_sold_now, cummlative_units_sold, 
                deferred_delta, units_to_pool, cum_units_to_pool, cum_interest_paid, units_to_principal, 
                units_sold_now+units_to_principal, hedge_units_delta]
      
      if t < annuity_duration_quarters:
        if piProgressiveRepayment:          
          holdings -= units_to_principal
        else:
          loan_size += annual_income_quarter
    
    # Append the completed path data
    all_data.extend(data.tolist())
      
  return pd.DataFrame(all_data, columns=["Path", "Period","Year", "Quarter", "SP500", "Interest", "Loan size",
                                     "Units", "Reinvestment", "InterestDeficit","CapitalDeficit", "Surplus",
                                     "Prob Holiday", "FunderEarned",
                                     "AnnuityIncome", "HolidayQuarters", "Prob Subperform", "InterestPaid", "InterestPaidToFunder", 
                                     "InterestRate", "UnitsSold", "CumUnitsSold", "InterestDeficitDelta", "UnitsToPool", "CumUnitsToPool","CumInterestPaid", "UnitsToPrincipal", "TotalUnitsSold","HedgeUnitsDelta"])

def main_outputs_table(df,total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin,insurance_cost, total_paths, loan_type, cash_rate, 
                    at_risk_captital_fraction,house_value, final_home_value, hedged=False):
  dfend = df[df['Period']==loan_duration*4]
  borrower_profit_share = 0.3
  lender_profit_share = 0.5
  at_risk_capital = (final_home_value- house_value)*at_risk_captital_fraction


  worse_pathn = dfend.sort_values('SP500').iloc[round(0.02*total_paths)]['Path']
  bad_pathn = dfend.sort_values('SP500').iloc[round(0.25*total_paths)]['Path']
  good_pathn = dfend.sort_values('SP500').iloc[round(0.75*total_paths)]['Path']
  median_pathn = dfend.sort_values('SP500').iloc[round(0.50*total_paths)]['Path']
  worse_end_ix = df[(df['Path']==worse_pathn) & (df['Period']==loan_duration*4)].index[0]
  bad_end_ix = df[(df['Path']==bad_pathn) & (df['Period']==loan_duration*4)].index[0]
  good_end_ix = df[(df['Path']==good_pathn) & (df['Period']==loan_duration*4)].index[0]
  median_end_ix = df[(df['Path']==median_pathn) & (df['Period']==loan_duration*4)].index[0]

  scheme_profit = (dfend['Reinvestment'] - total_loan - dfend['InterestDeficit'] ).clip(0,None)
  scheme_profit_to_borrower = scheme_profit*borrower_profit_share
  repay_hybrid = (annuity_duration*annual_income - scheme_profit_to_borrower).clip(0,None) if loan_type == "Hybrid" else 0.0
  repayment_amount =  dfend['Reinvestment'].map(lambda x: annuity_duration*annual_income) \
      if loan_type == "Interest only" \
      else repay_hybrid if loan_type == "Hybrid" \
      else dfend['Reinvestment'].map(lambda x: 0.0)

  def mean_dollar(dfv):
    worse_v = dfv.loc[worse_end_ix]
    bad_v = dfv.loc[bad_end_ix]
    good_v = dfv.loc[good_end_ix]
    median_v = dfv.loc[median_end_ix]
    return [f'${round(dfv.mean()):,}',
            #f'${round(dfv.quantile(0.25)):,}-${round(dfv.quantile(0.75)):,}',
            f'${round(worse_v):,}',
            f'${round(bad_v):,}',
            f'${round(median_v):,}',
            f'${round(good_v):,}', ]
  def mean_units(dfv):
    worse_v = dfv.loc[worse_end_ix]
    bad_v = dfv.loc[bad_end_ix]
    good_v = dfv.loc[good_end_ix]
    median_v = dfv.loc[median_end_ix]
    return [f'{round(dfv.mean()):,}',
            #f'${round(dfv.quantile(0.25)):,}-${round(dfv.quantile(0.75)):,}',
            f'{round(worse_v):,}',
            f'{round(bad_v):,}',
            f'{round(median_v):,}',
            f'{round(good_v):,}', ]
  lender_pool_profit = (dfend["CumUnitsToPool"].clip(0, None)*lender_profit_share) * dfend['SP500']
  lender_profit_share_amt = (lender_profit_share*(dfend["Reinvestment"] - total_loan - dfend['InterestDeficit']) + lender_pool_profit).clip(0, None)


  net_fund_pos=dfend['FunderEarned'] + lender_profit_share_amt
  initial_reinvest = total_loan*reinvest_fraction - insurance_profit_margin*insurance_cost/ pow(1 + cash_rate, loan_duration)

  nholidays = df['Prob Holiday'].sum()
  nholidays_good_path = df[(df['Path']==good_pathn)]['Prob Holiday'].sum()
  nholidays_bad_path = df[(df['Path']==bad_pathn)]['Prob Holiday'].sum()
  nholidays_worse_path = df[(df['Path']==worse_pathn)]['Prob Holiday'].sum()
  nholidays_median_path = df[(df['Path']==median_pathn)]['Prob Holiday'].sum()

  discount_lender_profit_share = lender_profit_share_amt /pow(1 + cash_rate, loan_duration)
  net_fund_pos_val = net_fund_pos.mean()
  avg_loan_size = (total_loan + total_loan * reinvest_fraction + annual_income/4)/2

  means = df.groupby('Period').mean()
  npcf = (means['InterestPaidToFunder']-means['AnnuityIncome']).iloc[:].values
  npcf[0] -= total_loan * reinvest_fraction + annual_income/4 # initial loan
  npcf[-1] += lender_profit_share_amt.mean()+total_loan+dfend['InterestDeficit'].mean()
  irr = npf.irr(npcf)

  outdfs = []
  outdfs.append(["Reinvestment fraction", "", pcnt(reinvest_fraction), "", "", "", ""])
  outdfs.append(["At Risk Capital", "ARC", dollar(at_risk_capital), "", "", "", ""])
  outdfs.append(["Initial reinvestment", "R0", dollar(initial_reinvest), "", "", "", ""])
  outdfs.append(["Total Income", "TI", dollar(annual_income*annuity_duration), "", "", "", ""])
  outdfs.append(["Outstanding", "L+D", *mean_dollar(total_loan + dfend['InterestDeficit'])])
  outdfs.append(["Reinvestment value", "R",  *mean_dollar(dfend["Reinvestment"])])
  outdfs.append(["Repayment amount", "C",  *mean_dollar(repayment_amount)])
  outdfs.append(["Balance liquid assets", "R+C-(L+D)", *mean_dollar(dfend["Reinvestment"] + repayment_amount - total_loan - dfend['InterestDeficit'])])
  outdfs.append(["Prob not covered", "P(R+C<(L+D))", pcntdf(dfend["Reinvestment"] +repayment_amount< (total_loan + dfend['InterestDeficit'])), "", "", "", ""])
  if at_risk_capital>1:
    outdfs.append(["Balance available assets", "R+C+ARC-(L+D)",*mean_dollar(dfend["Reinvestment"] +repayment_amount+at_risk_capital - total_loan - dfend['InterestDeficit']) ])
    outdfs.append(["Prob insurance payout", "P(R+C+ARC<(L+D))", pcntdf(dfend["Reinvestment"] + repayment_amount+at_risk_capital < (total_loan + dfend['InterestDeficit'])), "", "", "", ""])
  outdfs.append(["Shared Pool Unit Contribution", "",  *mean_units(dfend["CumUnitsToPool"])])
  if not hedged: 
    outdfs.append(["Insurance payout End of Term", "Max(L+D-(R+C+ARC),0)", *mean_dollar((total_loan + dfend['InterestDeficit'] - dfend["Reinvestment"] - repayment_amount - at_risk_capital).clip(0, None))])
    outdfs.append(["Insurance payout NPV", "Max(L+D-(R+C+ARC),0)",dollar(((total_loan + dfend['InterestDeficit'] - dfend["Reinvestment"] - repayment_amount - at_risk_capital).clip(0, None)).mean()/pow(1 + cash_rate, loan_duration)), "", "", "", ""])
    outdfs.append(["Pure risk pricing p.a.", "Max(L+D-(R+C+ARC),0)/(T*L)",  pcntdf((total_loan + dfend['InterestDeficit'] - dfend["Reinvestment"] -repayment_amount- at_risk_capital).clip(0, None)/loan_duration/total_loan), "","", "", ""])
    outdfs.append(["Insurance premium", "", dollar((insurance_profit_margin*(total_loan + dfend['InterestDeficit'] - dfend["Reinvestment"] - repayment_amount - at_risk_capital).clip(0, None)).mean()/pow(1 + cash_rate, loan_duration)), "", "", "", ""])
    outdfs.append(["Insurer profit", "", dollar(((insurance_profit_margin-1)*(total_loan + dfend['InterestDeficit'] - dfend["Reinvestment"] - repayment_amount - at_risk_capital).clip(0, None)).mean()/pow(1 + cash_rate, loan_duration)), "","","", ""])
    #outdfs.append(["Opportunity cost", "", *mean_dollar(dfend["OpportunityCost"])])
  outdfs.append(["Net funder position", "", *mean_dollar(net_fund_pos )])
  outdfs.append(["Funder interest earned", "", *mean_dollar(dfend['FunderEarned'])])
  outdfs.append(["Funder profit share", "", *mean_dollar(lender_profit_share_amt )])
  outdfs.append(["Funder Simple ROI", "", pcntdf((dfend['FunderEarned']+lender_profit_share_amt +dfend['InterestDeficit'])/total_loan), "", "", "", ""])
  outdfs.append(["Funder CAGR", "", pcntdf(pow(((dfend['FunderEarned']+lender_profit_share_amt+total_loan+dfend['InterestDeficit'])/total_loan).mean(), (1/loan_duration))-1), "", "", "", ""])
  outdfs.append(["Funder XIRR", "", pcnt(irr), "", "", "", ""])
  #outdfs.append(["Funder IRR", "", pcntdf(irr), "", "", "",""])
  outdfs.append(["Number of Holidays", "", round(nholidays/total_paths), nholidays_worse_path, nholidays_bad_path, nholidays_median_path, nholidays_good_path])
  outdfs.append(["%Quarters on Holiday", "",pcnt(df['Prob Holiday'].mean()), "", "", "", ""])

  outdf = pd.DataFrame(outdfs, columns = ["Quantity", "Formula", "Expected value", "Worse path value", "Bad path value", "Median path value", "Good path value"])
  return outdf

def accounts_table(df):
  adf = df[['Quarter', 'Year']].copy()  # Use .copy() to avoid SettingWithCopyWarning
  adf['Loan Opening'] = df['Loan size']
  adf['Annuity Payments'] = df['AnnuityIncome']
  adf['Loan Closing'] = df['Loan size'] + df['AnnuityIncome']
  adf['Interest rate qtr'] = df['InterestRate']/4
  adf['Interest Expense'] = df['Interest']
  adf['SP Units Opening'] = df['Units'] + df['UnitsSold']
  adf['SP Units Sold for Interest'] = df['UnitsSold']
  adf['SP Units Sold for Principal'] = df['UnitsToPrincipal']
  adf['SP Units Closing'] = df['Units'] - df['UnitsToPrincipal']
  adf['SP500 Index'] = df['SP500']
  adf['Reinvestment Balance'] = df['Reinvestment']
  adf['Interest Deficit Opem'] = df['InterestDeficit'] - df['InterestDeficitDelta']
  adf['Interest Deficit Change'] = df['InterestDeficitDelta']
  adf['Interest Deficit Close'] = df['InterestDeficit']

  return adf