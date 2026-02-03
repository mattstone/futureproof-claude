"""
Parameter Sensitivity Analysis for Equity Preservation Mortgage

Goal: Identify what parameter changes can make the product viable for funders
Target: Achieve minimum 2-4% XIRR (above risk-free rate)

Current baseline (from profitability_sweep.py):
- LOAN_TO_VALUE = 0.8
- WHOLESALE_LENDING_MARGIN = 0.02
- ADDITIONAL_LOAN_MARGINS = 0.015
- ANNUAL_INCOME = 30,000
- INSURANCE_COST_PA = 0.02

This script will test various combinations to find viable scenarios.
"""

import pandas as pd
import numpy as np
import csv
from datetime import datetime
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths
import numpy_financial as npf

# Monte Carlo settings
MONTE_CARLO_PATHS = 100
OUTPUT_FILE = 'sensitivity_results.csv'

# Fixed scenario parameters (use simple case for speed)
HOUSE_VALUE = 2_000_000
LOAN_DURATION = 20
ANNUITY_DURATION = 20

# Annual income is now 1.5% of house value
ANNUAL_INCOME_PCT = 0.015

# Monte Carlo parameters
EQUITY_RETURN = 0.0975
VOLATILITY = 0.15
S0 = 100
CASH_RATE = 0.04
DT = 1.0/120
YEAR0 = 2000

# Fixed operational parameters
INSURER_PROFIT_MARGIN = 0.5
INSURANCE_PROFIT_MARGIN = 1.0 + INSURER_PROFIT_MARGIN
HOLIDAY_ENTER_FRACTION = 1.35
HOLIDAY_EXIT_FRACTION = 1.95
SUBPERFORM_LOAN_THRESHOLD_QUARTERS = 6
SUPERPAY_START_FACTOR = 1.0
MAX_SUPERPAY_FACTOR = 1.0
HEDGED = False
HEDGING_MAX_LOSS = 0.1
HEDGING_CAP = 0.2
HEDGING_COST_PA = 0.01

# Parameters to test
LTV_VALUES = [0.4, 0.5, 0.6, 0.7, 0.8]
LENDING_MARGIN_VALUES = [0.02, 0.03, 0.04, 0.05, 0.06]  # Wholesale margin
ADDITIONAL_MARGIN_VALUES = [0.01, 0.015, 0.02, 0.025]  # Additional margins (updated from single_real_data.py)
# Annual income is calculated as percentage of house value, not fixed dollar amounts
ANNUAL_INCOME_PCT_VALUES = [0.01, 0.015, 0.02, 0.025]  # 1%, 1.5%, 2%, 2.5% of home value
INSURANCE_COST_VALUES = [0.01, 0.015, 0.02, 0.025, 0.03]

np.random.seed(42)

def calculate_metrics(df, dfend, total_loan, reinvest_fraction, loan_duration, annual_income,
                     annuity_duration, insurance_profit_margin, insurance_cost, total_paths):
    """Extract key profitability metrics from simulation results"""

    # Funder metrics
    borrower_profit_share = 0.3
    lender_profit_share = 0.5

    lender_pool_profit = (dfend["CumUnitsToPool"].clip(0, None) * lender_profit_share) * dfend['SP500']
    lender_profit_share_amt = (lender_profit_share * (dfend["Reinvestment"] - total_loan - dfend['InterestDeficit']) + lender_pool_profit).clip(0, None)

    # CAGR calculation - what funder actually gets back vs initial investment
    initial_investment = total_loan * reinvest_fraction
    final_value = dfend['Reinvestment'].mean() + lender_profit_share_amt.mean()

    if initial_investment <= 0:
        mean_cagr = 0
    else:
        mean_cagr = pow(final_value / initial_investment, (1/loan_duration)) - 1

    # XIRR calculation
    means = df.groupby('Period').mean()
    npcf = (means['InterestPaidToFunder'] - means['AnnuityIncome']).iloc[:].values
    npcf[0] -= total_loan * reinvest_fraction + annual_income/4  # initial loan outlay
    # Final recovery: what funder actually gets back
    final_recovery = dfend['Reinvestment'].mean() + lender_profit_share_amt.mean()
    npcf[-1] += final_recovery
    try:
        xirr = npf.irr(npcf)
    except:
        xirr = None

    # Insurance metrics
    repayment_amount = annuity_duration * annual_income
    insurance_payout = (total_loan + dfend['InterestDeficit'] - dfend["Reinvestment"] - repayment_amount).clip(0, None)
    prob_insurance_payout = (dfend["Reinvestment"] + repayment_amount < (total_loan + dfend['InterestDeficit'])).mean()

    return {
        'mean_reinvestment': dfend['Reinvestment'].mean(),
        'mean_cagr': mean_cagr,
        'xirr': xirr,
        'prob_insurance_payout': prob_insurance_payout,
        'mean_funder_earned': dfend['FunderEarned'].mean(),
    }

def run_sensitivity_analysis():
    """Test various parameter combinations"""

    print("="*80)
    print("EQUITY PRESERVATION MORTGAGE - PARAMETER SENSITIVITY ANALYSIS")
    print("="*80)
    print(f"\nFixed scenario: ${HOUSE_VALUE:,} home, {LOAN_DURATION} year loan")
    print(f"Monte Carlo paths: {MONTE_CARLO_PATHS}")
    print("\nTesting parameters:")
    print(f"  LTV: {LTV_VALUES}")
    print(f"  Lending Margin: {LENDING_MARGIN_VALUES}")
    print(f"  Additional Margin: {ADDITIONAL_MARGIN_VALUES}")
    print(f"  Annual Income %: {ANNUAL_INCOME_PCT_VALUES} (of home value)")
    print(f"  Insurance Cost PA: {INSURANCE_COST_VALUES}")

    total_combinations = (len(LTV_VALUES) * len(LENDING_MARGIN_VALUES) *
                         len(ADDITIONAL_MARGIN_VALUES) * len(ANNUAL_INCOME_PCT_VALUES) *
                         len(INSURANCE_COST_VALUES))
    print(f"\nTotal combinations: {total_combinations}")
    print("="*80 + "\n")

    fieldnames = [
        'ltv', 'lending_margin', 'additional_margin', 'annual_income_pct', 'annual_income',
        'insurance_cost_pa', 'loan_amount', 'reinvest_fraction', 'total_cost_of_funds',
        'mean_reinvestment', 'mean_cagr', 'xirr', 'prob_insurance_payout', 'mean_funder_earned'
    ]

    with open(OUTPUT_FILE, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        completed = 0

        for ltv in LTV_VALUES:
            for lending_margin in LENDING_MARGIN_VALUES:
                for additional_margin in ADDITIONAL_MARGIN_VALUES:
                    for annual_income_pct in ANNUAL_INCOME_PCT_VALUES:
                        for insurance_cost_pa in INSURANCE_COST_VALUES:

                            completed += 1

                            # Calculate derived parameters
                            total_loan = HOUSE_VALUE * ltv
                            annual_income = HOUSE_VALUE * annual_income_pct  # Income as % of home value
                            reinvest_fraction = 1 - (ANNUITY_DURATION * annual_income) / total_loan
                            insurance_cost = insurance_cost_pa * total_loan * LOAN_DURATION

                            # Skip invalid scenarios (can't reinvest if annuity takes all loan)
                            if reinvest_fraction <= 0:
                                continue

                            # Calculate total cost of funds
                            total_cost_of_funds = CASH_RATE + lending_margin + additional_margin

                            # Generate Monte Carlo paths
                            price_paths = gen_monte_carlo_paths(LOAN_DURATION, EQUITY_RETURN, VOLATILITY,
                                                               MONTE_CARLO_PATHS, S0)

                            # Run simulation (Interest Only loan)
                            df = single_mortgage(
                                total_loan, reinvest_fraction, LOAN_DURATION, annual_income, ANNUITY_DURATION,
                                INSURANCE_PROFIT_MARGIN, insurance_cost,
                                CASH_RATE, lending_margin, additional_margin,
                                HOLIDAY_ENTER_FRACTION, HOLIDAY_EXIT_FRACTION, SUBPERFORM_LOAN_THRESHOLD_QUARTERS,
                                price_paths, S0, DT, YEAR0-1, MAX_SUPERPAY_FACTOR, SUPERPAY_START_FACTOR,
                                False, 0, None, False, HEDGED, HEDGING_MAX_LOSS,
                                HEDGING_CAP, HEDGING_COST_PA
                            )

                            # Extract end-of-term data
                            dfend = df[df['Period'] == LOAN_DURATION * 4]

                            # Calculate metrics
                            metrics = calculate_metrics(df, dfend, total_loan, reinvest_fraction, LOAN_DURATION,
                                                       annual_income, ANNUITY_DURATION, INSURANCE_PROFIT_MARGIN,
                                                       insurance_cost, MONTE_CARLO_PATHS)

                            # Write row to CSV
                            row = {
                                'ltv': ltv,
                                'lending_margin': lending_margin,
                                'additional_margin': additional_margin,
                                'annual_income_pct': annual_income_pct,
                                'annual_income': annual_income,
                                'insurance_cost_pa': insurance_cost_pa,
                                'loan_amount': total_loan,
                                'reinvest_fraction': reinvest_fraction,
                                'total_cost_of_funds': total_cost_of_funds,
                                **metrics
                            }
                            writer.writerow(row)
                            csvfile.flush()

                            # Progress logging
                            if completed % 25 == 0:
                                xirr_str = f"{metrics['xirr']:.4f}" if metrics['xirr'] is not None else 'N/A'
                                print(f"Progress: {completed}/{total_combinations} ({100*completed/total_combinations:.1f}%) | "
                                      f"Last: LTV={ltv:.1%} Margin={lending_margin:.2%}+{additional_margin:.2%} "
                                      f"Income={annual_income_pct:.1%} (${annual_income:,.0f}) XIRR={xirr_str}")

    print(f"\nCompleted! Results saved to: {OUTPUT_FILE}")

if __name__ == "__main__":
    run_sensitivity_analysis()
