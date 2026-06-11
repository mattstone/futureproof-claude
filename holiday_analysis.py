#!/usr/bin/env python3
"""
Extract holiday distribution statistics from the v14 Monte Carlo.
Re-runs the simulation specifically to get per-path total holiday counts
and their percentile distribution.
"""

import numpy as np
import json

# ============================================================
# v14 PARAMETERS (same as monte_carlo_v14.py)
# ============================================================
HOME_VALUE = 2_000_000
LVR = 0.80
INITIAL_LOAN = 1_350_000
TENURE_YEARS = 30
ANNUITY_PA = 25_000
ANNUITY_TERM_YEARS = 10

WHOLESALE_MARGIN = 0.02
RETAIL_MARGIN = 0.0075
HEDGING_FEE = 0.0025
FP_MARGIN = 0.0025
LMI_UPFRONT_PCT = 0.015
REINSURANCE_UPFRONT_PCT = 0.001

EQUITY_MEAN = 0.10
EQUITY_VOL = 0.10
BUFFER_CAP = 1.20
BUFFER_FLOOR = 0.80

CASH_RATE_INITIAL = 0.044
CASH_RATE_THETA = 0.044
CASH_RATE_KAPPA = 0.80
CASH_RATE_SIGMA = 0.015
CASH_RATE_EQUITY_CORR = 0.002

HOLIDAY_ENTRY_LEVEL = 0.9
HOLIDAY_EXIT_LEVEL = 1.458

PROFIT_SHARE_YEARS = 5
PROFIT_SHARE_PCT = 0.10

N_PATHS = 50_000
SEED = 42


def run_holiday_analysis():
    rng = np.random.default_rng(SEED)

    # Loan trajectory
    loan_from_funder = np.zeros(TENURE_YEARS + 1)
    loan_from_funder[0] = INITIAL_LOAN
    for t in range(1, TENURE_YEARS + 1):
        if t <= ANNUITY_TERM_YEARS:
            loan_from_funder[t] = loan_from_funder[t - 1] + ANNUITY_PA
        else:
            loan_from_funder[t] = loan_from_funder[t - 1]

    MAX_LOAN = np.max(loan_from_funder)
    upfront_LMI = MAX_LOAN * LMI_UPFRONT_PCT
    upfront_reinsurance = MAX_LOAN * REINSURANCE_UPFRONT_PCT

    holiday_entry_threshold = INITIAL_LOAN * HOLIDAY_ENTRY_LEVEL
    holiday_exit_threshold = INITIAL_LOAN * HOLIDAY_EXIT_LEVEL

    z1 = rng.standard_normal((N_PATHS, TENURE_YEARS))
    z2_raw = rng.standard_normal((N_PATHS, TENURE_YEARS))
    rho = CASH_RATE_EQUITY_CORR
    z2 = rho * z1 + np.sqrt(1 - rho**2) * z2_raw

    investment = np.full(N_PATHS, INITIAL_LOAN - upfront_LMI - upfront_reinsurance, dtype=np.float64)
    cash_rate = np.full(N_PATHS, CASH_RATE_INITIAL, dtype=np.float64)
    holiday_entry_flag = np.zeros(N_PATHS, dtype=bool)
    holiday_count = np.zeros(N_PATHS, dtype=np.float64)
    holiday_account = np.zeros(N_PATHS, dtype=np.float64)
    repayment_step = np.zeros(N_PATHS, dtype=np.float64)
    funder_interest_tot = np.zeros(N_PATHS, dtype=np.float64)
    interest_charged_tot = np.zeros(N_PATHS, dtype=np.float64)

    # Track per-path holiday years
    yearly_holidays = np.zeros((N_PATHS, TENURE_YEARS))
    interest_deficit = np.zeros(N_PATHS)

    collar_price = -0.004
    investment *= (1 - collar_price)

    for t in range(1, TENURE_YEARS + 1):
        year_idx = t - 1

        cash_rate = (cash_rate * np.exp(-CASH_RATE_KAPPA) +
                     CASH_RATE_THETA * (1 - np.exp(-CASH_RATE_KAPPA)) +
                     CASH_RATE_SIGMA * z2[:, year_idx])
        cash_rate = np.maximum(cash_rate, 0)

        raw_return = np.exp(EQUITY_MEAN + EQUITY_VOL * z1[:, year_idx]) - 1
        hedged_return = np.clip(raw_return, BUFFER_FLOOR - 1, BUFFER_CAP - 1)

        funder_funding_cost = WHOLESALE_MARGIN + cash_rate
        avg_loan = (loan_from_funder[t - 1] + loan_from_funder[t]) / 2
        funder_interest = -funder_funding_cost * avg_loan
        funder_interest_tot += funder_interest

        prev_holiday_flag = holiday_entry_flag.copy()
        prev_holiday_count = holiday_count.copy()

        entering = (~prev_holiday_flag) & (investment < holiday_entry_threshold)
        exiting = prev_holiday_flag & (investment > holiday_exit_threshold)
        staying = prev_holiday_flag & (~exiting)
        holiday_entry_flag = entering | staying
        holiday_count = np.where(holiday_entry_flag, prev_holiday_count + 1, 0)
        yearly_holidays[:, year_idx] = holiday_entry_flag.astype(float)

        repayment_flag = prev_holiday_flag & (~holiday_entry_flag)
        new_repayment_periods = np.where(repayment_flag & (repayment_step <= 0),
                                          prev_holiday_count, 0)
        repayment_step = np.where(new_repayment_periods > 0,
                                   new_repayment_periods,
                                   np.maximum(repayment_step - 1, 0))

        holiday_account_open = holiday_account.copy()
        interest_holiday = np.where(holiday_entry_flag, -funder_interest, 0)
        repayment_holiday = np.where(repayment_step > 0,
                                      -holiday_account_open / np.maximum(repayment_step, 1),
                                      0)
        holiday_account = holiday_account_open + interest_holiday + repayment_holiday

        interest_charged = funder_interest + interest_holiday + repayment_holiday
        interest_charged_tot += interest_charged
        interest_deficit = funder_interest_tot - interest_charged_tot

        retailer_nim = -RETAIL_MARGIN * avg_loan
        fp_margin_payment = -FP_MARGIN * investment
        hedging_fee_payment = -HEDGING_FEE * investment

        if t == TENURE_YEARS:
            retailer_nim = -RETAIL_MARGIN * loan_from_funder[t - 1] / 2
            interest_charged = -funder_funding_cost * loan_from_funder[t - 1] / 2

        investment_return = investment * hedged_return
        investment = (investment + investment_return + interest_charged +
                      retailer_nim + fp_margin_payment + hedging_fee_payment)

        surplus = investment - loan_from_funder[t] + interest_deficit

        if t < TENURE_YEARS and t % PROFIT_SHARE_YEARS == 0:
            profit_share = np.where(surplus > 0, surplus * PROFIT_SHARE_PCT, 0)
            investment -= profit_share

        if t == TENURE_YEARS:
            windup = np.maximum(surplus, 0)
            investment -= windup

        if t < TENURE_YEARS:
            investment *= (1 - collar_price)

    # ============================================================
    # HOLIDAY DISTRIBUTION ANALYSIS
    # ============================================================
    total_holidays_per_path = np.sum(yearly_holidays, axis=1)

    print("=" * 70)
    print("HOLIDAY DISTRIBUTION ANALYSIS — 50,000 paths")
    print("=" * 70)

    print(f"\n--- Total Holiday Count per Mortgage (across 30 years) ---")
    print(f"  Mean:   {np.mean(total_holidays_per_path):.2f}")
    print(f"  Median: {np.median(total_holidays_per_path):.0f}")
    print(f"  P75:    {np.percentile(total_holidays_per_path, 75):.0f}")
    print(f"  P90:    {np.percentile(total_holidays_per_path, 90):.0f}")
    print(f"  P95:    {np.percentile(total_holidays_per_path, 95):.0f}")
    print(f"  P99:    {np.percentile(total_holidays_per_path, 99):.0f}")
    print(f"  Max:    {np.max(total_holidays_per_path):.0f}")
    print(f"  Zero holidays: {np.mean(total_holidays_per_path == 0)*100:.1f}% of paths")

    # Distribution histogram
    print(f"\n--- Distribution of Total Holidays ---")
    for count in range(int(np.max(total_holidays_per_path)) + 1):
        n = np.sum(total_holidays_per_path == count)
        pct = n / N_PATHS * 100
        if pct >= 0.1:  # Only show if >= 0.1%
            bar = '#' * int(pct * 2)
            print(f"  {count:2d} holidays: {n:5d} paths ({pct:5.1f}%) {bar}")

    # Per-year breakdown at different percentiles
    print(f"\n--- Holidays by Year (Percentile View) ---")
    print(f"  {'Year':>4s}  {'Mean':>6s}  {'Median':>7s}  {'P90':>5s}  {'P99':>5s}")
    for yr in range(TENURE_YEARS):
        h = yearly_holidays[:, yr]
        print(f"  {yr+1:4d}  {np.mean(h):5.3f}  {np.median(h):6.0f}  "
              f"{np.percentile(h, 90):4.0f}  {np.percentile(h, 99):4.0f}")

    # Holiday account at maturity (outstanding deferred interest)
    print(f"\n--- Holiday Account at Maturity (Outstanding Deferred Interest) ---")
    print(f"  Mean:   ${np.mean(holiday_account):>12,.0f}")
    print(f"  Median: ${np.median(holiday_account):>12,.0f}")
    print(f"  P90:    ${np.percentile(holiday_account, 90):>12,.0f}")
    print(f"  P99:    ${np.percentile(holiday_account, 99):>12,.0f}")
    print(f"  Max:    ${np.max(holiday_account):>12,.0f}")
    print(f"  Zero outstanding: {np.mean(holiday_account == 0)*100:.1f}% of paths")

    # Save results
    results = {
        'total_holidays': {
            'mean': round(float(np.mean(total_holidays_per_path)), 2),
            'median': int(np.median(total_holidays_per_path)),
            'p75': int(np.percentile(total_holidays_per_path, 75)),
            'p90': int(np.percentile(total_holidays_per_path, 90)),
            'p95': int(np.percentile(total_holidays_per_path, 95)),
            'p99': int(np.percentile(total_holidays_per_path, 99)),
            'max': int(np.max(total_holidays_per_path)),
            'pct_zero': round(float(np.mean(total_holidays_per_path == 0) * 100), 1),
        },
        'holiday_account_at_maturity': {
            'mean': round(float(np.mean(holiday_account)), 0),
            'median': round(float(np.median(holiday_account)), 0),
            'p90': round(float(np.percentile(holiday_account, 90)), 0),
            'p99': round(float(np.percentile(holiday_account, 99)), 0),
        },
        'mean_holidays_per_year': [round(float(np.mean(yearly_holidays[:, yr])), 3) for yr in range(TENURE_YEARS)],
        'median_holidays_per_year': [int(np.median(yearly_holidays[:, yr])) for yr in range(TENURE_YEARS)],
        'p90_holidays_per_year': [int(np.percentile(yearly_holidays[:, yr], 90)) for yr in range(TENURE_YEARS)],
        'p99_holidays_per_year': [int(np.percentile(yearly_holidays[:, yr], 99)) for yr in range(TENURE_YEARS)],
        # Distribution of total holiday counts
        'holiday_count_distribution': {},
    }
    for count in range(int(np.max(total_holidays_per_path)) + 1):
        n = int(np.sum(total_holidays_per_path == count))
        if n > 0:
            results['holiday_count_distribution'][str(count)] = n

    with open('holiday_analysis_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to holiday_analysis_results.json")

    return results


if __name__ == '__main__':
    run_holiday_analysis()
