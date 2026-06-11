#!/usr/bin/env python3
"""
Inflation-Indexed Annuity Analysis — FutureProof EPM v14a

Compares FLAT annuity ($25,000/year for 10 years) vs INFLATION-INDEXED annuity
(starting at $25,000, growing by assumed inflation rate each year).

Both scenarios use identical random paths (same seed) for clean comparison.
"""

import numpy as np
import time
import json

# ============================================================
# v14a PARAMETERS (from FutureProofCalculator_Pavel_v14a.xlsm)
# ============================================================
HOME_VALUE = 2_000_000
LVR = 0.80
INITIAL_LOAN = 1_350_000

TENURE_YEARS = 30
ANNUITY_PA = 25_000
ANNUITY_TERM_YEARS = 10

# Inflation scenarios to test
INFLATION_RATES = [0.02, 0.025, 0.03, 0.035, 0.04]

# Costs (v14a)
WHOLESALE_MARGIN = 0.02
RETAIL_MARGIN = 0.007
HEDGING_FEE = 0.0025
FP_MARGIN = 0.0025
LMI_UPFRONT_PCT = 0.016
REINSURANCE_UPFRONT_PCT = 0.001

# Investment (GBM annual + buffer)
EQUITY_MEAN = 0.10
EQUITY_VOL = 0.10
BUFFER_CAP = 1.20
BUFFER_FLOOR = 0.80

# Cash rate (Ornstein-Uhlenbeck)
CASH_RATE_INITIAL = 0.044
CASH_RATE_THETA = 0.044
CASH_RATE_KAPPA = 0.80
CASH_RATE_SIGMA = 0.015
CASH_RATE_EQUITY_CORR = 0.069

# Holiday mechanism
HOLIDAY_ENTRY_LEVEL = 0.9
HOLIDAY_EXIT_LEVEL = 1.458

# Profit share (v14a)
PROFIT_SHARE_YEARS = 5
PROFIT_SHARE_PCT = 0.25

# Simulation
N_PATHS = 50_000
SEED = 42


def compute_annuity_schedule(inflation_rate):
    """Compute annual annuity payments with inflation indexing."""
    payments = np.zeros(TENURE_YEARS + 1)
    for t in range(1, ANNUITY_TERM_YEARS + 1):
        if inflation_rate == 0:
            payments[t] = ANNUITY_PA
        else:
            payments[t] = ANNUITY_PA * (1 + inflation_rate) ** (t - 1)
    return payments


def compute_loan_trajectory(annuity_payments):
    """Compute loan trajectory from annuity schedule."""
    loan = np.zeros(TENURE_YEARS + 1)
    loan[0] = INITIAL_LOAN
    for t in range(1, TENURE_YEARS + 1):
        loan[t] = loan[t - 1] + annuity_payments[t]
    return loan


def run_scenario(inflation_rate, z1, z2, label):
    """Run simulation for a given inflation rate."""
    annuity_payments = compute_annuity_schedule(inflation_rate)
    loan_from_funder = compute_loan_trajectory(annuity_payments)

    total_annuity = sum(annuity_payments)
    MAX_LOAN = np.max(loan_from_funder)
    upfront_LMI = MAX_LOAN * LMI_UPFRONT_PCT
    upfront_reinsurance = MAX_LOAN * REINSURANCE_UPFRONT_PCT

    # Holiday thresholds (constant, based on initial loan)
    holiday_entry_threshold = INITIAL_LOAN * HOLIDAY_ENTRY_LEVEL
    holiday_exit_threshold = INITIAL_LOAN * HOLIDAY_EXIT_LEVEL

    print(f"\n{'='*70}")
    print(f"SCENARIO: {label}")
    print(f"{'='*70}")
    print(f"  Inflation rate: {inflation_rate*100:.1f}%")
    print(f"  Annuity Year 1: ${annuity_payments[1]:,.0f}")
    if inflation_rate > 0:
        print(f"  Annuity Year 5: ${annuity_payments[5]:,.0f}")
        print(f"  Annuity Year 10: ${annuity_payments[10]:,.0f}")
    print(f"  Total annuity paid: ${total_annuity:,.0f}")
    print(f"  Max loan: ${MAX_LOAN:,.0f}")
    print(f"  Upfront LMI: ${upfront_LMI:,.0f}")
    print(f"  Initial investment: ${INITIAL_LOAN - upfront_LMI - upfront_reinsurance:,.0f}")

    # Initialize arrays
    investment = np.full(N_PATHS, INITIAL_LOAN - upfront_LMI - upfront_reinsurance, dtype=np.float64)
    cash_rate = np.full(N_PATHS, CASH_RATE_INITIAL, dtype=np.float64)

    holiday_entry_flag = np.zeros(N_PATHS, dtype=bool)
    holiday_count = np.zeros(N_PATHS, dtype=np.float64)
    holiday_account = np.zeros(N_PATHS, dtype=np.float64)
    repayment_step = np.zeros(N_PATHS, dtype=np.float64)
    funder_interest_tot = np.zeros(N_PATHS, dtype=np.float64)
    interest_charged_tot = np.zeros(N_PATHS, dtype=np.float64)

    yearly_surplus = np.zeros((N_PATHS, TENURE_YEARS + 1))
    yearly_investment = np.zeros((N_PATHS, TENURE_YEARS + 1))
    yearly_holidays = np.zeros((N_PATHS, TENURE_YEARS))
    cumulative_profit_share = np.zeros(N_PATHS)
    profit_share_by_period = np.zeros((N_PATHS, 6))

    interest_deficit = np.zeros(N_PATHS)
    yearly_surplus[:, 0] = investment - loan_from_funder[0] + interest_deficit
    yearly_investment[:, 0] = investment.copy()

    collar_price = -0.003972
    investment *= (1 - collar_price)

    for t in range(1, TENURE_YEARS + 1):
        year_idx = t - 1

        # Cash rate: Ornstein-Uhlenbeck
        cash_rate = (cash_rate * np.exp(-CASH_RATE_KAPPA) +
                     CASH_RATE_THETA * (1 - np.exp(-CASH_RATE_KAPPA)) +
                     CASH_RATE_SIGMA * z2[:, year_idx])
        cash_rate = np.maximum(cash_rate, 0)

        # Investment returns with buffer
        raw_return = np.exp(EQUITY_MEAN + EQUITY_VOL * z1[:, year_idx]) - 1
        hedged_return = np.clip(raw_return, BUFFER_FLOOR - 1, BUFFER_CAP - 1)

        # Funder interest
        funder_funding_cost = WHOLESALE_MARGIN + cash_rate
        avg_loan = (loan_from_funder[t - 1] + loan_from_funder[t]) / 2
        funder_interest = -funder_funding_cost * avg_loan
        funder_interest_tot += funder_interest

        # Holiday mechanism
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

        # Net interest
        interest_charged = funder_interest + interest_holiday + repayment_holiday
        interest_charged_tot += interest_charged
        interest_deficit = funder_interest_tot - interest_charged_tot

        # Other costs
        retailer_nim = -RETAIL_MARGIN * avg_loan
        fp_margin_payment = -FP_MARGIN * investment
        hedging_fee_payment = -HEDGING_FEE * investment

        if t == TENURE_YEARS:
            retailer_nim = -RETAIL_MARGIN * loan_from_funder[t - 1] / 2
            interest_charged = -funder_funding_cost * loan_from_funder[t - 1] / 2

        # Investment return
        investment_return = investment * hedged_return

        # Update investment
        investment = (investment + investment_return + interest_charged +
                      retailer_nim + fp_margin_payment + hedging_fee_payment)

        # Surplus
        surplus = investment - loan_from_funder[t] + interest_deficit

        # Profit share
        if t < TENURE_YEARS and t % PROFIT_SHARE_YEARS == 0:
            profit_share = np.where(surplus > 0, surplus * PROFIT_SHARE_PCT, 0)
            investment -= profit_share
            cumulative_profit_share += profit_share
            period_idx = (t // PROFIT_SHARE_YEARS) - 1
            if period_idx < 6:
                profit_share_by_period[:, period_idx] = profit_share

        if t == TENURE_YEARS:
            windup = np.maximum(surplus, 0)
            investment -= windup

        if t < TENURE_YEARS:
            investment *= (1 - collar_price)

        yearly_surplus[:, t] = surplus
        yearly_investment[:, t] = investment

    # Compute results
    final_surplus = yearly_surplus[:, -1]
    final_deficit_prob = np.mean(final_surplus < 0) * 100
    se_deficit = np.sqrt(final_deficit_prob / 100 * (1 - final_deficit_prob / 100) / N_PATHS) * 100

    deficit_by_year = []
    for yr in range(1, TENURE_YEARS + 1):
        deficit_by_year.append(float(np.mean(yearly_surplus[:, yr] < 0) * 100))

    # Insurance pricing
    discount = np.exp(-CASH_RATE_THETA * TENURE_YEARS)
    deficit_mask = final_surplus < 0
    n_deficit = int(np.sum(deficit_mask))
    if n_deficit > 0:
        discounted_claims = discount * final_surplus[deficit_mask]
        fair_premium = -np.mean(discounted_claims) * (final_deficit_prob / 100)
        cond_expected_deficit = float(np.mean(final_surplus[deficit_mask]))
    else:
        cond_expected_deficit = 0.0
        fair_premium = 0.0

    fair_premium_loaded = fair_premium * 1.5

    # Print key results
    print(f"\n  --- Key Results ---")
    print(f"  Final PoC (Year 30): {final_deficit_prob:.2f}% (SE: {se_deficit:.2f}%)")
    print(f"  Mean surplus:   ${np.mean(final_surplus):>14,.0f}")
    print(f"  Median surplus: ${np.median(final_surplus):>14,.0f}")
    print(f"  P1:  ${np.percentile(final_surplus, 1):>14,.0f}")
    print(f"  P5:  ${np.percentile(final_surplus, 5):>14,.0f}")
    print(f"  P10: ${np.percentile(final_surplus, 10):>14,.0f}")
    print(f"  P25: ${np.percentile(final_surplus, 25):>14,.0f}")
    print(f"  P75: ${np.percentile(final_surplus, 75):>14,.0f}")
    print(f"  P90: ${np.percentile(final_surplus, 90):>14,.0f}")
    print(f"  P95: ${np.percentile(final_surplus, 95):>14,.0f}")
    print(f"  P99: ${np.percentile(final_surplus, 99):>14,.0f}")

    print(f"\n  Insurance pricing:")
    print(f"  Fair premium (PV): ${fair_premium:>12,.0f}")
    print(f"  Fair + 50% loading: ${fair_premium_loaded:>12,.0f}")
    print(f"  As % of max loan: {100 * fair_premium_loaded / MAX_LOAN:.3f}%")

    print(f"\n  Profit share (total mean): ${np.mean(cumulative_profit_share):>12,.0f}")

    # Holiday stats
    mean_holidays = np.mean(yearly_holidays, axis=0)

    # PoC by year table
    print(f"\n  --- PoC by Year ---")
    print(f"  {'Year':>4s}  {'PoC%':>8s}  {'P1':>12s}  {'P10':>12s}  {'Median':>12s}  {'P90':>12s}  {'P99':>12s}")
    for yr in [1, 5, 10, 15, 20, 25, 30]:
        s = yearly_surplus[:, yr]
        dp = np.mean(s < 0) * 100
        print(f"  {yr:4d}  {dp:7.2f}%  ${np.percentile(s, 1):>11,.0f}  ${np.percentile(s, 10):>11,.0f}  "
              f"${np.median(s):>11,.0f}  ${np.percentile(s, 90):>11,.0f}  ${np.percentile(s, 99):>11,.0f}")

    return {
        'inflation_rate': inflation_rate,
        'label': label,
        'total_annuity': round(float(total_annuity), 0),
        'max_loan': round(float(MAX_LOAN), 0),
        'annuity_schedule': [round(float(annuity_payments[t]), 0) for t in range(TENURE_YEARS + 1)],
        'deficit_prob': round(final_deficit_prob, 2),
        'deficit_se': round(se_deficit, 2),
        'mean_surplus': round(float(np.mean(final_surplus)), 0),
        'median_surplus': round(float(np.median(final_surplus)), 0),
        'p1': round(float(np.percentile(final_surplus, 1)), 0),
        'p5': round(float(np.percentile(final_surplus, 5)), 0),
        'p10': round(float(np.percentile(final_surplus, 10)), 0),
        'p25': round(float(np.percentile(final_surplus, 25)), 0),
        'p75': round(float(np.percentile(final_surplus, 75)), 0),
        'p90': round(float(np.percentile(final_surplus, 90)), 0),
        'p95': round(float(np.percentile(final_surplus, 95)), 0),
        'p99': round(float(np.percentile(final_surplus, 99)), 0),
        'fair_premium': round(float(fair_premium), 0),
        'fair_premium_loaded': round(float(fair_premium_loaded), 0),
        'cond_expected_deficit': round(float(cond_expected_deficit), 0),
        'n_deficit': n_deficit,
        'mean_profit_share': round(float(np.mean(cumulative_profit_share)), 0),
        'deficit_by_year': [round(d, 2) for d in deficit_by_year],
        'mean_holidays_per_year': [round(float(h), 3) for h in mean_holidays],
        'surplus_percentiles_by_year': {},
    }


def main():
    print(f"Running inflation-indexed annuity analysis — {N_PATHS:,} paths")
    start = time.time()

    rng = np.random.default_rng(SEED)

    # Generate random numbers ONCE — shared across all scenarios
    z1 = rng.standard_normal((N_PATHS, TENURE_YEARS))
    z2_raw = rng.standard_normal((N_PATHS, TENURE_YEARS))
    rho = CASH_RATE_EQUITY_CORR
    z2 = rho * z1 + np.sqrt(1 - rho ** 2) * z2_raw

    # Run baseline (flat)
    baseline = run_scenario(0, z1, z2, "BASELINE — Flat $25,000/year")

    # Run inflation-indexed scenarios
    indexed_results = []
    for rate in INFLATION_RATES:
        result = run_scenario(rate, z1, z2, f"Inflation-Indexed at {rate*100:.1f}%")
        indexed_results.append(result)

    elapsed = time.time() - start

    # ============================================================
    # COMPARISON TABLE
    # ============================================================
    print(f"\n\n{'='*90}")
    print("COMPARISON: FLAT vs INFLATION-INDEXED ANNUITY PAYOUTS")
    print(f"{'='*90}")

    all_scenarios = [baseline] + indexed_results

    # Annuity schedule comparison
    print(f"\n--- Annual Annuity Payments ---")
    print(f"  {'Year':>4s}", end="")
    for s in all_scenarios:
        print(f"  {s['label'][:16]:>16s}", end="")
    print()
    for yr in [1, 2, 3, 5, 7, 10]:
        print(f"  {yr:4d}", end="")
        for s in all_scenarios:
            print(f"  ${s['annuity_schedule'][yr]:>14,.0f}", end="")
        print()

    print(f"\n  {'Total':>4s}", end="")
    for s in all_scenarios:
        print(f"  ${s['total_annuity']:>14,.0f}", end="")
    print()

    print(f"  {'Max Loan':>8s}", end="")
    for s in all_scenarios:
        print(f"  ${s['max_loan']:>14,.0f}", end="")
    print()

    # Key metrics comparison
    print(f"\n--- Key Risk Metrics ---")
    print(f"  {'Metric':<30s}", end="")
    for s in all_scenarios:
        print(f"  {s['label'][:16]:>16s}", end="")
    print()

    metrics = [
        ('PoC (Year 30)', 'deficit_prob', '%'),
        ('Mean Surplus', 'mean_surplus', '$'),
        ('Median Surplus', 'median_surplus', '$'),
        ('P1 Surplus', 'p1', '$'),
        ('P5 Surplus', 'p5', '$'),
        ('P10 Surplus', 'p10', '$'),
        ('Fair Premium (PV)', 'fair_premium', '$'),
        ('Premium + 50% Load', 'fair_premium_loaded', '$'),
        ('Cond. Expected Deficit', 'cond_expected_deficit', '$'),
        ('Paths in Deficit', 'n_deficit', '#'),
        ('Mean Profit Share', 'mean_profit_share', '$'),
    ]

    for label, key, fmt in metrics:
        print(f"  {label:<30s}", end="")
        for s in all_scenarios:
            val = s[key]
            if fmt == '%':
                print(f"  {val:>15.2f}%", end="")
            elif fmt == '$':
                print(f"  ${val:>14,.0f}", end="")
            elif fmt == '#':
                print(f"  {val:>16,d}", end="")
        print()

    # PoC by year comparison
    print(f"\n--- PoC by Year (Flat vs Inflation-Indexed) ---")
    print(f"  {'Year':>4s}", end="")
    for s in all_scenarios:
        print(f"  {s['label'][:16]:>16s}", end="")
    print()
    for yr_idx, yr in enumerate([0, 4, 9, 14, 19, 24, 29]):
        print(f"  {yr+1:4d}", end="")
        for s in all_scenarios:
            print(f"  {s['deficit_by_year'][yr]:>15.2f}%", end="")
        print()

    # Impact summary
    print(f"\n--- Impact of Inflation Indexing (vs Flat Baseline) ---")
    print(f"  {'Inflation':>10s}  {'PoC Change':>12s}  {'Total Annuity':>14s}  {'Extra Payout':>14s}  {'Mean Surplus Δ':>16s}  {'P5 Surplus Δ':>14s}")
    for s in indexed_results:
        poc_delta = s['deficit_prob'] - baseline['deficit_prob']
        annuity_delta = s['total_annuity'] - baseline['total_annuity']
        surplus_delta = s['mean_surplus'] - baseline['mean_surplus']
        p5_delta = s['p5'] - baseline['p5']
        print(f"  {s['inflation_rate']*100:>9.1f}%  {poc_delta:>+11.2f}pp  ${s['total_annuity']:>13,.0f}  ${annuity_delta:>13,.0f}  ${surplus_delta:>15,.0f}  ${p5_delta:>13,.0f}")

    print(f"\nCompleted in {elapsed:.1f} seconds")

    # Save results
    output = {
        'analysis': 'Inflation-Indexed Annuity Impact Analysis',
        'model_version': 'v14a',
        'n_paths': N_PATHS,
        'baseline': baseline,
        'inflation_scenarios': indexed_results,
        'comparison': {
            'baseline_total_annuity': baseline['total_annuity'],
            'baseline_poc': baseline['deficit_prob'],
            'baseline_mean_surplus': baseline['mean_surplus'],
        }
    }

    with open('inflation_analysis_results.json', 'w') as f:
        json.dump(output, f, indent=2)
    print(f"Results saved to inflation_analysis_results.json")


if __name__ == '__main__':
    main()
