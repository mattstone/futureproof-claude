import sys
import json
import math
import pandas as pd
import numpy as np
import time
import csv
from datetime import datetime
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths
import numpy_financial as npf

# Configuration - SMALL TEST SET
MONTE_CARLO_PATHS = 10  # Very small for quick test
OUTPUT_FILE = 'profitability_results_test.csv'
PROGRESS_LOG = 'profitability_progress_test.log'

# Parameter ranges - SMALL TEST SET
HOUSE_VALUES = [1_000_000, 2_000_000, 5_000_000]  # Just 3 values
LOAN_DURATIONS = [10, 20, 30]  # Just 3 values
ANNUITY_DURATIONS = [10, 20, 30]  # Just 3 values

# Fixed parameters (from single_real_data.py)
LOAN_TO_VALUE = 0.8
ANNUAL_INCOME = 30_000
INSURER_PROFIT_MARGIN = 0.5
INSURANCE_PROFIT_MARGIN = 1.0 + INSURER_PROFIT_MARGIN
WHOLESALE_LENDING_MARGIN = 0.02
ADDITIONAL_LOAN_MARGINS = 0.015
HOLIDAY_ENTER_FRACTION = 1.35
HOLIDAY_EXIT_FRACTION = 1.95
SUBPERFORM_LOAN_THRESHOLD_QUARTERS = 6
SUPERPAY_START_FACTOR = 1.0
MAX_SUPERPAY_FACTOR = 1.0
INSURANCE_COST_PA = 0.02
YEAR0 = 2000
PRINCIPAL_REPAYMENT = False
HEDGED = False
HEDGING_MAX_LOSS = 0.1
HEDGING_CAP = 0.2
HEDGING_COST_PA = 0.01

# Monte Carlo parameters
EQUITY_RETURN = 0.0975
VOLATILITY = 0.15
S0 = 100
CASH_RATE = 0.04
DT = 1.0/120

# Set seed for reproducibility
np.random.seed(42)

def calculate_metrics(df, dfend, total_loan, reinvest_fraction, loan_duration, annual_income,
                     annuity_duration, insurance_profit_margin, insurance_cost, total_paths):
    """Extract key profitability metrics from simulation results"""

    # Basic statistics
    mean_reinvestment = dfend['Reinvestment'].mean()
    std_reinvestment = dfend['Reinvestment'].std()
    mean_deficit = dfend['InterestDeficit'].mean()

    # Holiday statistics
    total_holiday_quarters = df['Prob Holiday'].sum()
    pct_quarters_holiday = df['Prob Holiday'].mean()

    # Funder metrics
    borrower_profit_share = 0.3
    lender_profit_share = 0.5

    lender_pool_profit = (dfend["CumUnitsToPool"].clip(0, None) * lender_profit_share) * dfend['SP500']
    lender_profit_share_amt = (lender_profit_share * (dfend["Reinvestment"] - total_loan - dfend['InterestDeficit']) + lender_pool_profit).clip(0, None)

    mean_funder_earned = dfend['FunderEarned'].mean()
    mean_funder_profit_share = lender_profit_share_amt.mean()
    mean_net_position = (dfend['FunderEarned'] + lender_profit_share_amt).mean()

    # CAGR calculation
    mean_cagr = pow(((dfend['FunderEarned'] + lender_profit_share_amt + total_loan + dfend['InterestDeficit']) / total_loan).mean(),
                    (1/loan_duration)) - 1

    # XIRR calculation
    means = df.groupby('Period').mean()
    npcf = (means['InterestPaidToFunder'] - means['AnnuityIncome']).iloc[:].values
    npcf[0] -= total_loan * reinvest_fraction + annual_income/4  # initial loan
    npcf[-1] += lender_profit_share_amt.mean() + total_loan + dfend['InterestDeficit'].mean()
    try:
        xirr = npf.irr(npcf)
    except:
        xirr = None

    # Insurance metrics
    repayment_amount = annuity_duration * annual_income  # Interest only loan
    insurance_payout = (total_loan + dfend['InterestDeficit'] - dfend["Reinvestment"] - repayment_amount).clip(0, None)
    prob_insurance_payout = (dfend["Reinvestment"] + repayment_amount < (total_loan + dfend['InterestDeficit'])).mean()
    mean_insurance_payout_npv = insurance_payout.mean() / pow(1 + CASH_RATE, loan_duration)

    # Percentile metrics
    p10_reinvestment = dfend['Reinvestment'].quantile(0.10)
    p25_reinvestment = dfend['Reinvestment'].quantile(0.25)
    p50_reinvestment = dfend['Reinvestment'].quantile(0.50)
    p75_reinvestment = dfend['Reinvestment'].quantile(0.75)
    p90_reinvestment = dfend['Reinvestment'].quantile(0.90)

    return {
        'mean_reinvestment': mean_reinvestment,
        'std_reinvestment': std_reinvestment,
        'p10_reinvestment': p10_reinvestment,
        'p25_reinvestment': p25_reinvestment,
        'p50_reinvestment': p50_reinvestment,
        'p75_reinvestment': p75_reinvestment,
        'p90_reinvestment': p90_reinvestment,
        'mean_deficit': mean_deficit,
        'total_holiday_quarters': total_holiday_quarters,
        'pct_quarters_holiday': pct_quarters_holiday,
        'mean_funder_earned': mean_funder_earned,
        'mean_funder_profit_share': mean_funder_profit_share,
        'mean_net_position': mean_net_position,
        'mean_cagr': mean_cagr,
        'xirr': xirr,
        'prob_insurance_payout': prob_insurance_payout,
        'mean_insurance_payout_npv': mean_insurance_payout_npv,
    }

def log_progress(message):
    """Log progress to both console and file"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_message = f"[{timestamp}] {message}"
    print(log_message)
    with open(PROGRESS_LOG, 'a') as f:
        f.write(log_message + '\n')

def run_profitability_sweep():
    """Main function to run parameter sweep"""

    start_time = time.time()

    # Calculate total combinations
    total_combinations = sum(1 for hv in HOUSE_VALUES
                            for ld in LOAN_DURATIONS
                            for ad in ANNUITY_DURATIONS
                            if ad >= ld)

    log_progress(f"Starting TEST profitability sweep with {MONTE_CARLO_PATHS} Monte Carlo paths")
    log_progress(f"Total combinations to test: {total_combinations}")

    # Prepare CSV output
    fieldnames = [
        'house_value', 'loan_duration', 'annuity_duration', 'loan_amount', 'reinvest_fraction',
        'mean_reinvestment', 'std_reinvestment',
        'p10_reinvestment', 'p25_reinvestment', 'p50_reinvestment', 'p75_reinvestment', 'p90_reinvestment',
        'mean_deficit', 'total_holiday_quarters', 'pct_quarters_holiday',
        'mean_funder_earned', 'mean_funder_profit_share', 'mean_net_position',
        'mean_cagr', 'xirr', 'prob_insurance_payout', 'mean_insurance_payout_npv',
        'simulation_time_sec'
    ]

    with open(OUTPUT_FILE, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        completed = 0

        for house_value in HOUSE_VALUES:
            for loan_duration in LOAN_DURATIONS:
                for annuity_duration in ANNUITY_DURATIONS:

                    # Skip invalid combinations (annuity must be >= loan duration)
                    if annuity_duration < loan_duration:
                        continue

                    completed += 1
                    sim_start = time.time()

                    # Calculate derived parameters
                    total_loan = house_value * LOAN_TO_VALUE
                    reinvest_fraction = 1 - (annuity_duration * ANNUAL_INCOME) / total_loan
                    insurance_cost = INSURANCE_COST_PA * total_loan * loan_duration

                    log_progress(f"Running {completed}/{total_combinations}: HV=${house_value:,} LD={loan_duration}y AD={annuity_duration}y")

                    # Generate Monte Carlo paths
                    price_paths = gen_monte_carlo_paths(loan_duration, EQUITY_RETURN, VOLATILITY,
                                                       MONTE_CARLO_PATHS, S0)

                    # Run simulation
                    df = single_mortgage(
                        total_loan, reinvest_fraction, loan_duration, ANNUAL_INCOME, annuity_duration,
                        INSURANCE_PROFIT_MARGIN, insurance_cost,
                        CASH_RATE, WHOLESALE_LENDING_MARGIN, ADDITIONAL_LOAN_MARGINS,
                        HOLIDAY_ENTER_FRACTION, HOLIDAY_EXIT_FRACTION, SUBPERFORM_LOAN_THRESHOLD_QUARTERS,
                        price_paths, S0, DT, YEAR0-1, MAX_SUPERPAY_FACTOR, SUPERPAY_START_FACTOR,
                        False, 0, None, PRINCIPAL_REPAYMENT, HEDGED, HEDGING_MAX_LOSS,
                        HEDGING_CAP, HEDGING_COST_PA
                    )

                    # Extract end-of-term data
                    dfend = df[df['Period'] == loan_duration * 4]

                    # Calculate metrics
                    metrics = calculate_metrics(df, dfend, total_loan, reinvest_fraction, loan_duration,
                                               ANNUAL_INCOME, annuity_duration, INSURANCE_PROFIT_MARGIN,
                                               insurance_cost, MONTE_CARLO_PATHS)

                    sim_time = time.time() - sim_start

                    # Write row to CSV
                    row = {
                        'house_value': house_value,
                        'loan_duration': loan_duration,
                        'annuity_duration': annuity_duration,
                        'loan_amount': total_loan,
                        'reinvest_fraction': reinvest_fraction,
                        'simulation_time_sec': sim_time,
                        **metrics
                    }
                    writer.writerow(row)
                    csvfile.flush()  # Ensure data is written immediately

                    xirr_str = f"{metrics['xirr']:.4f}" if metrics['xirr'] is not None else 'N/A'
                    log_progress(f"  -> XIRR={xirr_str} "
                               f"CAGR={metrics['mean_cagr']:.4f} "
                               f"ProbPayout={metrics['prob_insurance_payout']:.2%} "
                               f"({sim_time:.2f}s)")

    total_time = time.time() - start_time
    log_progress(f"Completed! Total time: {total_time:.1f} seconds")
    log_progress(f"Results saved to: {OUTPUT_FILE}")
    log_progress(f"Average time per simulation: {total_time/total_combinations:.2f} seconds")

if __name__ == "__main__":
    # Clear previous log
    with open(PROGRESS_LOG, 'w') as f:
        f.write(f"Profitability Sweep TEST Started: {datetime.now()}\n")
        f.write(f"Parameters: {MONTE_CARLO_PATHS} paths (TEST MODE)\n")
        f.write("="*80 + "\n\n")

    run_profitability_sweep()
