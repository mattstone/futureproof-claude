#!/usr/bin/env python3
"""
Parameter Sensitivity Analysis for FutureProof EPM v14.

Runs the v14 Monte Carlo engine across different combinations of:
  - Eligible house value ($2M, $2.5M, $3M)
  - LVR (60%, 70%, 80%)
  - Annuity ($15K, $20K, $25K)

Uses 10,000 paths per scenario for speed (still good precision).
Outputs results as JSON for use in PDF reports.
"""

import numpy as np
import time
import json

# ============================================================
# FIXED PARAMETERS (same across all scenarios)
# ============================================================
TENURE_YEARS = 30
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

N_PATHS = 10_000
SEED = 42


def run_scenario(home_value, lvr, annuity_pa, seed=SEED):
    """Run Monte Carlo for a single parameter combination."""
    initial_loan = home_value * lvr
    rng = np.random.default_rng(seed)

    # Loan trajectory (deterministic)
    loan_from_funder = np.zeros(TENURE_YEARS + 1)
    loan_from_funder[0] = initial_loan
    for t in range(1, TENURE_YEARS + 1):
        if t <= ANNUITY_TERM_YEARS:
            loan_from_funder[t] = loan_from_funder[t - 1] + annuity_pa
        else:
            loan_from_funder[t] = loan_from_funder[t - 1]

    MAX_LOAN = np.max(loan_from_funder)
    upfront_LMI = MAX_LOAN * LMI_UPFRONT_PCT
    upfront_reinsurance = MAX_LOAN * REINSURANCE_UPFRONT_PCT

    holiday_entry_threshold = initial_loan * HOLIDAY_ENTRY_LEVEL
    holiday_exit_threshold = initial_loan * HOLIDAY_EXIT_LEVEL

    # Random numbers
    z1 = rng.standard_normal((N_PATHS, TENURE_YEARS))
    z2_raw = rng.standard_normal((N_PATHS, TENURE_YEARS))
    rho = CASH_RATE_EQUITY_CORR
    z2 = rho * z1 + np.sqrt(1 - rho**2) * z2_raw

    # Initialize
    investment = np.full(N_PATHS, initial_loan - upfront_LMI - upfront_reinsurance, dtype=np.float64)
    cash_rate = np.full(N_PATHS, CASH_RATE_INITIAL, dtype=np.float64)
    holiday_entry_flag = np.zeros(N_PATHS, dtype=bool)
    holiday_count = np.zeros(N_PATHS, dtype=np.float64)
    holiday_account = np.zeros(N_PATHS, dtype=np.float64)
    repayment_step = np.zeros(N_PATHS, dtype=np.float64)
    funder_interest_tot = np.zeros(N_PATHS, dtype=np.float64)
    interest_charged_tot = np.zeros(N_PATHS, dtype=np.float64)
    cumulative_profit_share = np.zeros(N_PATHS)

    yearly_surplus = np.zeros((N_PATHS, TENURE_YEARS + 1))
    interest_deficit = np.zeros(N_PATHS)
    yearly_surplus[:, 0] = investment - loan_from_funder[0] + interest_deficit

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
            cumulative_profit_share += profit_share

        if t == TENURE_YEARS:
            windup = np.maximum(surplus, 0)
            investment -= windup

        if t < TENURE_YEARS:
            investment *= (1 - collar_price)

        yearly_surplus[:, t] = surplus

    final_surplus = yearly_surplus[:, -1]
    pod_yr30 = np.mean(final_surplus < 0) * 100
    se_pod = np.sqrt(pod_yr30/100 * (1 - pod_yr30/100) / N_PATHS) * 100
    mean_surplus = float(np.mean(final_surplus))
    median_surplus = float(np.median(final_surplus))
    p10 = float(np.percentile(final_surplus, 10))
    p90 = float(np.percentile(final_surplus, 90))

    # PoD by year for PoC estimation
    pod_by_year = []
    for yr in range(1, TENURE_YEARS + 1):
        pod_by_year.append(float(np.mean(yearly_surplus[:, yr] < 0) * 100))

    # Annuity as % of initial loan (cost burden ratio)
    annuity_pct = annuity_pa / initial_loan * 100

    return {
        'home_value': home_value,
        'lvr': lvr,
        'initial_loan': initial_loan,
        'annuity_pa': annuity_pa,
        'annuity_pct_of_loan': round(annuity_pct, 2),
        'pod_yr30': round(pod_yr30, 2),
        'se_pod': round(se_pod, 2),
        'mean_surplus': round(mean_surplus),
        'median_surplus': round(median_surplus),
        'p10': round(p10),
        'p90': round(p90),
        'pod_yr15': round(pod_by_year[14], 2),
        'pod_yr20': round(pod_by_year[19], 2),
        'pod_yr25': round(pod_by_year[24], 2),
    }


def estimate_portfolio_poc(pod_yr30):
    """
    Estimate portfolio PoC from individual PoD using the waterfall reduction ratio.
    Based on the v14 baseline: PoD 12.89% -> PoC 0.5% (ratio ~0.039).
    The ratio improves slightly for lower PoD (more surplus loans available).
    """
    if pod_yr30 <= 0:
        return 0.0
    # Use a conservative non-linear mapping:
    # At PoD=12.89, PoC=0.50 (baseline)
    # At PoD=5, PoC~0.15
    # At PoD=25, PoC~1.5
    baseline_ratio = 0.5 / 12.89
    # Scale slightly: lower PoD = slightly better ratio
    adjusted_ratio = baseline_ratio * (pod_yr30 / 12.89) ** 0.3
    poc = pod_yr30 * adjusted_ratio
    return round(poc, 2)


if __name__ == '__main__':
    print("=" * 70)
    print("FUTUREPROOF EPM v14 — PARAMETER SENSITIVITY ANALYSIS")
    print(f"10,000 paths per scenario | Seed: {SEED}")
    print("=" * 70)

    # Scenarios
    house_values = [2_000_000, 2_500_000, 3_000_000]
    lvrs = [0.60, 0.70, 0.80]
    annuities = [15_000, 20_000, 25_000]

    results = []
    total = len(house_values) * len(lvrs) * len(annuities)
    count = 0

    start = time.time()

    for hv in house_values:
        for lvr in lvrs:
            for ann in annuities:
                count += 1
                label = f"HV=${hv/1e6:.1f}M, LVR={lvr*100:.0f}%, Ann=${ann/1000:.0f}K"
                print(f"\n[{count}/{total}] {label}")

                r = run_scenario(hv, lvr, ann)
                r['poc_yr30_est'] = estimate_portfolio_poc(r['pod_yr30'])
                results.append(r)

                print(f"  Loan=${r['initial_loan']:,.0f}, Ann/Loan={r['annuity_pct_of_loan']:.2f}%")
                print(f"  PoD(30)={r['pod_yr30']:.2f}% (SE: {r['se_pod']:.2f}%)")
                print(f"  PoC(30)≈{r['poc_yr30_est']:.2f}% (portfolio est.)")
                print(f"  Mean surplus=${r['mean_surplus']:,.0f}, Median=${r['median_surplus']:,.0f}")

    elapsed = time.time() - start

    # Save results
    with open('sensitivity_v14_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\n{'='*70}")
    print(f"Completed {total} scenarios in {elapsed:.1f} seconds")
    print(f"Results saved to sensitivity_v14_results.json")

    # Summary table
    print(f"\n{'='*70}")
    print("SUMMARY TABLE — PoD and Estimated Portfolio PoC at Year 30")
    print(f"{'='*70}")
    print(f"{'House Value':>12s}  {'LVR':>5s}  {'Loan':>12s}  {'Annuity':>8s}  {'Ann/Loan':>9s}  {'PoD(30)':>8s}  {'PoC(30)':>8s}  {'Mean Surplus':>13s}")
    print("-" * 90)

    # Sort by PoC
    sorted_results = sorted(results, key=lambda x: x['poc_yr30_est'])
    for r in sorted_results:
        print(f"${r['home_value']/1e6:.1f}M  "
              f"{r['lvr']*100:4.0f}%  "
              f"${r['initial_loan']:>11,.0f}  "
              f"${r['annuity_pa']/1000:.0f}K  "
              f"{r['annuity_pct_of_loan']:7.2f}%  "
              f"{r['pod_yr30']:6.2f}%  "
              f"{r['poc_yr30_est']:6.2f}%  "
              f"${r['mean_surplus']:>12,.0f}")

    # Highlight best scenarios
    print(f"\n{'='*70}")
    print("TOP 5 SCENARIOS BY LOWEST PoC:")
    for i, r in enumerate(sorted_results[:5]):
        print(f"  {i+1}. HV=${r['home_value']/1e6:.1f}M, LVR={r['lvr']*100:.0f}%, "
              f"Ann=${r['annuity_pa']/1000:.0f}K → PoD={r['pod_yr30']:.2f}%, "
              f"PoC≈{r['poc_yr30_est']:.2f}%, Surplus=${r['mean_surplus']:,.0f}")

    print(f"\nOPTIMISATION INSIGHT:")
    print(f"  The annuity as % of loan (cost burden ratio) is the key driver.")
    print(f"  Higher house value with same annuity → lower cost burden → lower PoD/PoC.")
    print(f"  Lower LVR with same annuity → smaller loan → BUT annuity/loan ratio increases.")
    print(f"  Sweet spot: balance house value and LVR to minimise annuity/loan ratio.")
