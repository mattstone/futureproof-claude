import pandas as pd
import math
from statistics import geometric_mean
import numpy as np
import numpy_financial as npf
from utils import mean_sd, dollar, pcntdf, pcnt, secant
from multiprocessing import Pool, cpu_count
import warnings
warnings.filterwarnings('ignore')


def gen_monte_carlo_paths_vectorized(loan_duration, equity_return, volatility, total_paths, S0):
    """
    Vectorized Monte Carlo path generation - processes all paths simultaneously
    """
    dt = 1.0/120
    N = round(loan_duration/dt)
    
    # Generate all random numbers at once
    random_matrix = np.random.standard_normal((total_paths, N))
    
    # Vectorized path generation
    ts = np.linspace(0, loan_duration, N)
    W = np.cumsum(random_matrix, axis=1) * np.sqrt(dt)  # Brownian motion for all paths
    
    # Broadcast ts across all paths
    ts_broadcast = np.broadcast_to(ts, (total_paths, N))
    X = (equity_return - 0.5 * volatility**2) * ts_broadcast + volatility * W
    S_all = S0 * np.exp(X)  # All paths at once
    
    # Convert to original format for compatibility
    price_paths = [(i, S_all[i]) for i in range(total_paths)]
    return price_paths


def single_mortgage_batch(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                         insurance_profit_margin, insurance_cost, cash_rate_series, wholesale_lending_margin, 
                         additional_loan_margins, holiday_enter_fraction, holiday_exit_fraction, 
                         subperform_loan_threshold_quarters, price_paths, S0, dt, year_offset=0, 
                         max_superpay_factor=1.0, superpay_start_factor=1.0, enable_pool=False, 
                         insured_units=0, expected_reinvestment_ratio=None, piProgressiveRepayment=False, 
                         hedged=False, hedging_max_loss=0, hedging_cap=1000, hedging_cost_pa=0):
    """
    Optimized batch processing of multiple Monte Carlo paths
    """
    # Always use optimized single-threaded version for now
    # Multiprocessing is disabled to avoid recursion issues
    return single_mortgage_optimized(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                                    insurance_profit_margin, insurance_cost, cash_rate_series, wholesale_lending_margin,
                                    additional_loan_margins, holiday_enter_fraction, holiday_exit_fraction,
                                    subperform_loan_threshold_quarters, price_paths, S0, dt, year_offset,
                                    max_superpay_factor, superpay_start_factor, enable_pool, insured_units,
                                    expected_reinvestment_ratio, piProgressiveRepayment, hedged, hedging_max_loss,
                                    hedging_cap, hedging_cost_pa)


def process_single_path(args):
    """
    Worker function for parallel processing of individual paths
    """
    (path_data, total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
     insurance_profit_margin, insurance_cost, cash_rate_series, wholesale_lending_margin,
     additional_loan_margins, holiday_enter_fraction, holiday_exit_fraction,
     subperform_loan_threshold_quarters, S0, dt, year_offset, max_superpay_factor,
     superpay_start_factor, enable_pool, insured_units, expected_reinvestment_ratio,
     piProgressiveRepayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa) = args
    
    # Process single path using optimized single-threaded function
    result = single_mortgage_optimized(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                                      insurance_profit_margin, insurance_cost, cash_rate_series, wholesale_lending_margin,
                                      additional_loan_margins, holiday_enter_fraction, holiday_exit_fraction,
                                      subperform_loan_threshold_quarters, [path_data], S0, dt, year_offset,
                                      max_superpay_factor, superpay_start_factor, enable_pool, insured_units,
                                      expected_reinvestment_ratio, piProgressiveRepayment, hedged, hedging_max_loss,
                                      hedging_cap, hedging_cost_pa)
    return result


def single_mortgage_parallel(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                            insurance_profit_margin, insurance_cost, cash_rate_series, wholesale_lending_margin,
                            additional_loan_margins, holiday_enter_fraction, holiday_exit_fraction,
                            subperform_loan_threshold_quarters, price_paths, S0, dt, year_offset=0,
                            max_superpay_factor=1.0, superpay_start_factor=1.0, enable_pool=False,
                            insured_units=0, expected_reinvestment_ratio=None, piProgressiveRepayment=False,
                            hedged=False, hedging_max_loss=0, hedging_cap=1000, hedging_cost_pa=0):
    """
    Parallel processing version using multiprocessing
    """
    # Prepare arguments for each path
    path_args = []
    for path_data in price_paths:
        args = (path_data, total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                insurance_profit_margin, insurance_cost, cash_rate_series, wholesale_lending_margin,
                additional_loan_margins, holiday_enter_fraction, holiday_exit_fraction,
                subperform_loan_threshold_quarters, S0, dt, year_offset, max_superpay_factor,
                superpay_start_factor, enable_pool, insured_units, expected_reinvestment_ratio,
                piProgressiveRepayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)
        path_args.append(args)
    
    # Use multiprocessing to process paths in parallel
    num_processes = min(cpu_count(), len(price_paths))
    with Pool(processes=num_processes) as pool:
        results = pool.map(process_single_path, path_args)
    
    # Combine results
    all_data = []
    for result_df in results:
        all_data.extend(result_df.values.tolist())
    
    return pd.DataFrame(all_data, columns=["Path", "Period","Year", "Quarter", "SP500", "Interest", "Loan size",
                                          "Units", "Reinvestment", "InterestDeficit","CapitalDeficit", "Surplus",
                                          "Prob Holiday", "FunderEarned", "AnnuityIncome", "HolidayQuarters", 
                                          "Prob Subperform", "InterestPaid", "InterestPaidToFunder", "InterestRate", 
                                          "UnitsSold", "CumUnitsSold", "InterestDeficitDelta", "UnitsToPool", 
                                          "CumUnitsToPool","CumInterestPaid", "UnitsToPrincipal", "TotalUnitsSold",
                                          "HedgeUnitsDelta"])


def single_mortgage_optimized(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                             insurance_profit_margin, insurance_cost, cash_rate_series, wholesale_lending_margin,
                             additional_loan_margins, holiday_enter_fraction, holiday_exit_fraction,
                             subperform_loan_threshold_quarters, price_paths, S0, dt, year_offset=0,
                             max_superpay_factor=1.0, superpay_start_factor=1.0, enable_pool=False,
                             insured_units=0, expected_reinvestment_ratio=None, piProgressiveRepayment=False,
                             hedged=False, hedging_max_loss=0, hedging_cap=1000, hedging_cost_pa=0):
    """
    Highly optimized single-threaded version with memory pre-allocation and vectorization
    """
    # Pre-calculate constants
    is_cash_rate_list = isinstance(cash_rate_series, list)
    avg_cash_rate = geometric_mean(cash_rate_series) if is_cash_rate_list else cash_rate_series
    initial_reinvestment = total_loan*reinvest_fraction - \
       insurance_profit_margin* insurance_cost/ pow(1 + avg_cash_rate, loan_duration)
    
    expected_reinvestment = None
    if expected_reinvestment_ratio is not None:
      expected_reinvestment = expected_reinvestment_ratio * initial_reinvestment
    
    holiday_enter = initial_reinvestment* holiday_enter_fraction
    holiday_exit = initial_reinvestment*holiday_exit_fraction
    
    # Pre-calculate common constants
    quarter_div = 0.25
    dt_quarter_inv = 1.0/(dt*4)
    annual_income_quarter = annual_income * quarter_div
    annuity_duration_quarters = int(annuity_duration * 4)
    total_periods = int(4 * loan_duration + 1)
    
    # Pre-allocate massive result array for all paths
    num_paths = len(price_paths)
    total_rows = num_paths * total_periods
    all_data = np.zeros((total_rows, 29), dtype=object)
    row_idx = 0
    
    for (pathn, S) in price_paths:
        # Initialize path variables
        holdings = initial_reinvestment / S0
        cummlative_units_sold = 0.0
        init_units_to_principal = 0.0
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
        all_data[row_idx] = [pathn, 0, year_offset, 0, S0, 0, round(total_loan * reinvest_fraction), holdings, round(holdings_s0),
                            round(0), round(max(loan_size - holdings_s0, 0)), round(holdings_s0 - loan_size - deferred), 
                            in_holiday, 0, annual_income_quarter, 0, False, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
                            init_units_to_principal, 0, 0]
        row_idx += 1

        last_yearly_hedge_price = S0
        last_5yearly_hedge_price = S0
        
        # Pre-calculate all prices and rates for this path
        if is_cash_rate_list:
            price_indices = (np.arange(1, total_periods) * dt_quarter_inv - 1).astype(int)
            # Vectorized array access
            cash_rates = np.take(cash_rate_series, price_indices)
            prices = np.take(S, price_indices)
        else:
            cash_rates = np.full(total_periods-1, cash_rate_series)
            price_indices = (np.arange(1, total_periods) * dt_quarter_inv - 1).astype(int)
            prices = np.take(S, price_indices)
        
        # Pre-calculate loan interest rates
        loan_interest_rates = cash_rates + wholesale_lending_margin + additional_loan_margins
        
        # Vectorized main loop
        for i in range(total_periods - 1):
            t = i + 1
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
            holdings_value = holdings * s
            
            # Core logic (same as before but optimized)
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
                t_mod_4 = t & 3
                if t_mod_4 == 0:
                    holdings -= holdings * hedging_cost_pa
                    year_move = (s - last_yearly_hedge_price) / last_yearly_hedge_price 
                    if year_move < -hedging_max_loss:
                        buy_units = ((last_yearly_hedge_price / s) * (1 - hedging_max_loss) - 1) * holdings
                        hedge_units_delta = buy_units
                        holdings += buy_units            
                    last_yearly_hedge_price = s
                if t % 20 == 0:
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
            
            # Optimized year/quarter calculation
            t_minus_1 = t - 1
            year = (t_minus_1 >> 2) + 1
            quarter = t - ((year - 1) << 2)  # Use bit shift instead of multiplication
            
            # Update holdings value after calculations
            holdings_value = holdings * s
            
            # Store in pre-allocated array
            all_data[row_idx] = [pathn, t, year_offset+year, quarter, s, round(interest_due), round(loan_size), 
                                holdings, round(holdings_value), deferred, round(max(loan_size - holdings_value, 0)), 
                                round(holdings_value - loan_size - deferred + cum_units_to_pool * s), in_holiday, 
                                funder_earned, yearly_annuity_income, holiday_quarters, subperform, interest_paid, 
                                interest_paid_to_funder, loan_interest_rate, units_sold_now, cummlative_units_sold, 
                                deferred_delta, units_to_pool, cum_units_to_pool, cum_interest_paid, units_to_principal, 
                                units_sold_now+units_to_principal, hedge_units_delta]
            row_idx += 1
            
            if t < annuity_duration_quarters:
                if piProgressiveRepayment:          
                    holdings -= units_to_principal
                else:
                    loan_size += annual_income_quarter
    
    return pd.DataFrame(all_data, columns=["Path", "Period","Year", "Quarter", "SP500", "Interest", "Loan size",
                                          "Units", "Reinvestment", "InterestDeficit","CapitalDeficit", "Surplus",
                                          "Prob Holiday", "FunderEarned", "AnnuityIncome", "HolidayQuarters", 
                                          "Prob Subperform", "InterestPaid", "InterestPaidToFunder", "InterestRate", 
                                          "UnitsSold", "CumUnitsSold", "InterestDeficitDelta", "UnitsToPool", 
                                          "CumUnitsToPool","CumInterestPaid", "UnitsToPrincipal", "TotalUnitsSold",
                                          "HedgeUnitsDelta"])


# Alias for backward compatibility
single_mortgage = single_mortgage_batch
gen_monte_carlo_paths = gen_monte_carlo_paths_vectorized


# Import other functions from advanced model
from core_model_advanced import main_outputs_table, accounts_table