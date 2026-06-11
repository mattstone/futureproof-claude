#!/usr/bin/env python3
"""
Comprehensive Actuarial Analysis — FutureProof EPM v14c

50,000-path Monte Carlo with:
  1. Base case (v14c parameters)
  2. Sensitivity analysis: Equity return (7-11%), Volatility (12-25%)
  3. Stress tests: Correlation regime shifts (-0.3 to +0.6)
  4. Combined stress: low return + high vol + adverse correlation

Parameters from FutureProofCalculator_Pavel_v14c.xlsm and
Pavel Shevchenko's MLE estimation paper (3 April 2026).
"""

import numpy as np
import time
import json
import sys
from itertools import product as cartesian

# ============================================================
# v14c PARAMETERS (from spreadsheet)
# ============================================================
HOME_VALUE = 2_000_000
LVR = 0.80
MAX_LOAN_GROSS = HOME_VALUE * LVR  # 1,600,000
INITIAL_LOAN = 1_280_000
LOAN_TYPE = "PI"

TENURE_YEARS = 30
ANNUITY_PA = 32_000
ANNUITY_TERM_YEARS = 10

# Costs
WHOLESALE_MARGIN = 0.03
RETAIL_MARGIN = 0.007
HEDGING_FEE = 0.0025
FP_MARGIN = 0.005
LMI_UPFRONT_PCT = 0.02
TAIL_RISK_REINSURANCE = 0.002  # 0.2%

# Investment (GBM)
EQUITY_MEAN = 0.094
EQUITY_VOL = 0.175
BUFFER_CAP = 1.30
BUFFER_FLOOR = 0.80

# Cash rate (Ornstein-Uhlenbeck) — from Shevchenko MLE paper
CASH_RATE_INITIAL = 0.0421
CASH_RATE_THETA = 0.0213    # long-run mean (gamma in paper)
CASH_RATE_KAPPA = 0.24      # mean reversion speed (theta in paper)
CASH_RATE_SIGMA = 0.0122    # volatility (sigma in paper)
CASH_RATE_EQUITY_CORR = 0.30

# Holiday mechanism
HOLIDAY_ENTRY_LEVEL = 0.90
HOLIDAY_EXIT_LEVEL = 1.458

# Profit share
PROFIT_SHARE_YEARS = 5
PROFIT_SHARE_PCT = 0.10

# Top cover
TOP_COVER_QUANTILE = 0.20   # 20th percentile of deficit distribution

# Collar price (from spreadsheet: -0.005359)
COLLAR_PRICE = -0.005359

# Simulation defaults
N_PATHS = 50_000
SEED = 42


# ============================================================
# LOAN TRAJECTORY
# ============================================================
def compute_loan_trajectory(initial_loan=INITIAL_LOAN, annuity_pa=ANNUITY_PA,
                            annuity_term=ANNUITY_TERM_YEARS, tenure=TENURE_YEARS,
                            loan_type="PI"):
    loan = np.zeros(tenure + 1)
    loan[0] = initial_loan
    for t in range(1, tenure + 1):
        if t <= annuity_term:
            loan[t] = loan[t - 1] + annuity_pa
        else:
            loan[t] = loan[t - 1]

    if loan_type == "PI":
        peak = loan[annuity_term]
        remaining = tenure - annuity_term
        if remaining > 0:
            annual_principal = peak / remaining
            for t in range(annuity_term + 1, tenure + 1):
                loan[t] = max(loan[t - 1] - annual_principal, 0)
    return loan


# ============================================================
# CORE SIMULATION ENGINE
# ============================================================
def run_single_simulation(
    n_paths=N_PATHS,
    seed=SEED,
    equity_mean=EQUITY_MEAN,
    equity_vol=EQUITY_VOL,
    cash_rate_initial=CASH_RATE_INITIAL,
    cash_rate_theta=CASH_RATE_THETA,
    cash_rate_kappa=CASH_RATE_KAPPA,
    cash_rate_sigma=CASH_RATE_SIGMA,
    correlation=CASH_RATE_EQUITY_CORR,
    buffer_cap=BUFFER_CAP,
    buffer_floor=BUFFER_FLOOR,
    wholesale_margin=WHOLESALE_MARGIN,
    retail_margin=RETAIL_MARGIN,
    hedging_fee=HEDGING_FEE,
    fp_margin=FP_MARGIN,
    lmi_upfront_pct=LMI_UPFRONT_PCT,
    tail_risk_pct=TAIL_RISK_REINSURANCE,
    holiday_entry=HOLIDAY_ENTRY_LEVEL,
    holiday_exit=HOLIDAY_EXIT_LEVEL,
    profit_share_pct=PROFIT_SHARE_PCT,
    profit_share_years=PROFIT_SHARE_YEARS,
    collar_price=COLLAR_PRICE,
    initial_loan=INITIAL_LOAN,
    annuity_pa=ANNUITY_PA,
    annuity_term=ANNUITY_TERM_YEARS,
    tenure=TENURE_YEARS,
    loan_type=LOAN_TYPE,
    top_cover_quantile=TOP_COVER_QUANTILE,
    verbose=False,
):
    rng = np.random.default_rng(seed)

    loan_from_funder = compute_loan_trajectory(initial_loan, annuity_pa, annuity_term, tenure, loan_type)
    MAX_LOAN = np.max(loan_from_funder)

    upfront_LMI = MAX_LOAN * lmi_upfront_pct
    holiday_entry_threshold = initial_loan * holiday_entry
    holiday_exit_threshold = initial_loan * holiday_exit
    initial_investment = initial_loan - upfront_LMI

    # Exact OU discretisation (from Shevchenko paper eqs 5-9)
    w_ou = np.exp(-cash_rate_kappa * 1.0)  # dt = 1 year
    v_ou = np.sqrt((cash_rate_sigma**2 / (2 * cash_rate_kappa)) * (1 - w_ou**2))

    # Generate random numbers
    z1 = rng.standard_normal((n_paths, tenure))
    z2_raw = rng.standard_normal((n_paths, tenure))
    rho = correlation
    z2 = rho * z1 + np.sqrt(1 - rho**2) * z2_raw

    # Initialize
    investment = np.full(n_paths, initial_investment, dtype=np.float64)
    cash_rate = np.full(n_paths, cash_rate_initial, dtype=np.float64)

    # Holiday state
    holiday_entry_flag = np.zeros(n_paths, dtype=bool)
    holiday_count = np.zeros(n_paths, dtype=np.float64)
    holiday_account = np.zeros(n_paths, dtype=np.float64)
    repayment_step = np.zeros(n_paths, dtype=np.float64)
    funder_interest_tot = np.zeros(n_paths, dtype=np.float64)
    interest_charged_tot = np.zeros(n_paths, dtype=np.float64)

    # Tracking
    yearly_surplus = np.zeros((n_paths, tenure + 1))
    yearly_investment = np.zeros((n_paths, tenure + 1))
    yearly_holidays = np.zeros((n_paths, tenure))
    cumulative_profit_share = np.zeros(n_paths)

    yearly_funder_received = np.zeros((n_paths, tenure))
    yearly_lender_nim = np.zeros((n_paths, tenure))
    yearly_fp_margin_received = np.zeros((n_paths, tenure))

    interest_deficit = np.zeros(n_paths)
    yearly_surplus[:, 0] = investment - loan_from_funder[0] + interest_deficit
    yearly_investment[:, 0] = investment.copy()

    investment *= (1 - collar_price)

    for t in range(1, tenure + 1):
        year_idx = t - 1

        # 1. Cash rate: exact OU discretisation (Shevchenko paper)
        cash_rate = cash_rate * w_ou + cash_rate_theta * (1 - w_ou) + v_ou * z2[:, year_idx]
        cash_rate = np.maximum(cash_rate, 0)

        # 2. Investment returns with collar
        # Note: spreadsheet convention — mu is the arithmetic expected return parameter
        # (no Ito correction), consistent with v14b Python MC which was validated against SS
        raw_return = np.exp(equity_mean + equity_vol * z1[:, year_idx]) - 1
        hedged_return = np.clip(raw_return, buffer_floor - 1, buffer_cap - 1)

        # 3. Funder interest charged
        funder_funding_cost = wholesale_margin + cash_rate
        avg_loan = (loan_from_funder[t - 1] + loan_from_funder[t]) / 2
        funder_interest = -funder_funding_cost * avg_loan
        funder_interest_tot += funder_interest

        # 4. Holiday mechanism
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

        # 5. Net interest charged
        interest_charged = funder_interest + interest_holiday + repayment_holiday
        interest_charged_tot += interest_charged
        interest_deficit = funder_interest_tot - interest_charged_tot

        # 6. Other costs
        retailer_nim = -retail_margin * avg_loan
        fp_margin_payment = -fp_margin * investment
        hedging_fee_payment = -hedging_fee * investment
        tail_risk_premium = -tail_risk_pct * investment

        yearly_funder_received[:, year_idx] = -interest_charged
        yearly_lender_nim[:, year_idx] = -retailer_nim
        yearly_fp_margin_received[:, year_idx] = -fp_margin_payment

        if t == tenure:
            retailer_nim = -retail_margin * loan_from_funder[t - 1] / 2
            interest_charged = -funder_funding_cost * loan_from_funder[t - 1] / 2

        # 7. Investment return
        investment_return = investment * hedged_return

        # 8. Principal repayment
        principal_repayment = 0
        if t > annuity_term and loan_type == "PI":
            principal_repayment = -(loan_from_funder[t - 1] - loan_from_funder[t])

        # 9. Update investment
        investment = (investment + investment_return + interest_charged +
                      retailer_nim + fp_margin_payment + hedging_fee_payment +
                      tail_risk_premium + principal_repayment)

        # 10. Balance surplus
        surplus = investment - loan_from_funder[t] + interest_deficit

        # 11. Profit share
        if t < tenure and t % profit_share_years == 0:
            profit_share = np.where(surplus > 0, surplus * profit_share_pct, 0)
            investment -= profit_share
            cumulative_profit_share += profit_share

        if t == tenure:
            windup = np.maximum(surplus, 0)
            investment -= windup

        if t < tenure:
            investment *= (1 - collar_price)

        yearly_surplus[:, t] = surplus
        yearly_investment[:, t] = investment

    # ============================================================
    # COMPUTE RESULTS
    # ============================================================
    final_surplus = yearly_surplus[:, -1]
    deficit_mask = final_surplus < 0
    n_deficit = np.sum(deficit_mask)
    final_deficit_prob = np.mean(deficit_mask) * 100
    se_deficit = np.sqrt(final_deficit_prob / 100 * (1 - final_deficit_prob / 100) / n_paths) * 100

    # Insurance
    discount = np.exp(-cash_rate_theta * tenure)
    deficit_values = final_surplus[deficit_mask]

    if n_deficit > 0:
        top_cover_limit = np.percentile(deficit_values, top_cover_quantile * 100)
    else:
        top_cover_limit = 0

    lmi_claims_mild = np.where(deficit_mask & (final_surplus >= top_cover_limit),
                                -final_surplus, 0)
    lmi_claims_severe = np.where(deficit_mask & (final_surplus < top_cover_limit),
                                  -top_cover_limit, 0)
    total_lmi_claims = lmi_claims_mild + lmi_claims_severe
    lmi_fair_premium = discount * np.mean(total_lmi_claims)

    deep_deficit_mask = deficit_mask & (final_surplus < top_cover_limit)
    tail_claims = np.where(deep_deficit_mask, -(final_surplus - top_cover_limit), 0)
    tail_fair_premium = discount * np.mean(tail_claims)
    tail_poc = np.mean(deep_deficit_mask) * 100

    # Revenue streams
    total_funder = np.mean(np.sum(yearly_funder_received, axis=1))
    total_lender = np.mean(np.sum(yearly_lender_nim, axis=1))
    total_fp_margin = np.mean(np.sum(yearly_fp_margin_received, axis=1))
    total_ps = np.mean(cumulative_profit_share)
    mean_windup = np.mean(np.maximum(final_surplus, 0))

    # Holiday stats
    total_holiday_years = np.sum(yearly_holidays, axis=1)
    pct_zero_holidays = np.mean(total_holiday_years == 0) * 100
    mean_holiday_years = np.mean(total_holiday_years)

    # Deficit by year
    deficit_by_year = {}
    percentiles_by_year = {}
    for yr in [1, 5, 10, 15, 20, 25, 30]:
        if yr <= tenure:
            s = yearly_surplus[:, yr]
            deficit_by_year[yr] = round(np.mean(s < 0) * 100, 2)
            percentiles_by_year[yr] = {
                'p1': round(float(np.percentile(s, 1)), 0),
                'p5': round(float(np.percentile(s, 5)), 0),
                'p10': round(float(np.percentile(s, 10)), 0),
                'median': round(float(np.median(s)), 0),
                'mean': round(float(np.mean(s)), 0),
                'p90': round(float(np.percentile(s, 90)), 0),
                'p95': round(float(np.percentile(s, 95)), 0),
                'p99': round(float(np.percentile(s, 99)), 0),
            }

    cond_deficit = float(np.mean(deficit_values)) if n_deficit > 0 else 0

    results = {
        'n_paths': n_paths,
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
        'cond_expected_deficit': round(cond_deficit, 0),
        'insurance': {
            'lmi_fair_premium': round(float(lmi_fair_premium), 0),
            'lmi_loaded': round(float(lmi_fair_premium * 1.5), 0),
            'tail_fair_premium': round(float(tail_fair_premium), 0),
            'tail_poc': round(tail_poc, 2),
            'top_cover_limit': round(float(top_cover_limit), 0),
            'total_fair': round(float(lmi_fair_premium + tail_fair_premium), 0),
            'total_loaded': round(float((lmi_fair_premium + tail_fair_premium) * 1.5), 0),
        },
        'revenue': {
            'funder_total': round(total_funder, 0),
            'lender_nim_total': round(total_lender, 0),
            'fp_margin_total': round(total_fp_margin, 0),
            'profit_share_total': round(total_ps, 0),
            'maturity_surplus_mean': round(mean_windup, 0),
        },
        'holidays': {
            'mean_years': round(mean_holiday_years, 2),
            'pct_zero': round(pct_zero_holidays, 1),
        },
        'deficit_by_year': deficit_by_year,
        'percentiles_by_year': percentiles_by_year,
    }

    return results


# ============================================================
# PHASE 1: BASE CASE
# ============================================================
def run_base_case():
    print("=" * 80)
    print("PHASE 1: BASE CASE — v14c Parameters, 50,000 Paths")
    print("=" * 80)
    print(f"  Equity: mean={EQUITY_MEAN*100:.1f}%, vol={EQUITY_VOL*100:.1f}%")
    print(f"  Cash rate: initial={CASH_RATE_INITIAL*100:.2f}%, theta={CASH_RATE_THETA*100:.2f}%, "
          f"kappa={CASH_RATE_KAPPA}, sigma={CASH_RATE_SIGMA*100:.2f}%")
    print(f"  Correlation: {CASH_RATE_EQUITY_CORR}")
    print(f"  Collar: {BUFFER_FLOOR*100:.0f}%-{BUFFER_CAP*100:.0f}%, cost={COLLAR_PRICE*100:.4f}%")
    print(f"  Variable costs: {(WHOLESALE_MARGIN+RETAIL_MARGIN+HEDGING_FEE+FP_MARGIN)*100:.2f}%")
    print(f"  Loan: ${INITIAL_LOAN:,} ({LOAN_TYPE}), Annuity: ${ANNUITY_PA:,}/yr × {ANNUITY_TERM_YEARS}yr")
    print()

    start = time.time()
    results = run_single_simulation(n_paths=N_PATHS, verbose=True)
    elapsed = time.time() - start
    print(f"  Completed in {elapsed:.1f}s")

    print(f"\n  --- Results ---")
    print(f"  PoC (Year 30):        {results['deficit_prob']:.2f}% (SE: {results['deficit_se']:.2f}%)")
    print(f"  Mean surplus:         ${results['mean_surplus']:>14,.0f}")
    print(f"  Median surplus:       ${results['median_surplus']:>14,.0f}")
    print(f"  1st percentile:       ${results['p1']:>14,.0f}")
    print(f"  5th percentile:       ${results['p5']:>14,.0f}")
    print(f"  10th percentile:      ${results['p10']:>14,.0f}")
    print(f"  25th percentile:      ${results['p25']:>14,.0f}")
    print(f"  75th percentile:      ${results['p75']:>14,.0f}")
    print(f"  90th percentile:      ${results['p90']:>14,.0f}")
    print(f"  95th percentile:      ${results['p95']:>14,.0f}")
    print(f"  99th percentile:      ${results['p99']:>14,.0f}")
    print(f"  Cond. expected deficit: ${results['cond_expected_deficit']:>12,.0f}")
    print(f"\n  --- Insurance ---")
    ins = results['insurance']
    print(f"  LMI fair premium:     ${ins['lmi_fair_premium']:>12,.0f}")
    print(f"  LMI loaded (150%):    ${ins['lmi_loaded']:>12,.0f}")
    print(f"  Tail fair premium:    ${ins['tail_fair_premium']:>12,.0f}")
    print(f"  Tail PoC:             {ins['tail_poc']:.2f}%")
    print(f"  Top cover limit:      ${ins['top_cover_limit']:>12,.0f}")
    print(f"\n  --- Revenue (per mortgage, undiscounted) ---")
    rev = results['revenue']
    print(f"  Funder interest:      ${rev['funder_total']:>14,.0f}")
    print(f"  Lender NIM:           ${rev['lender_nim_total']:>14,.0f}")
    print(f"  FP margin:            ${rev['fp_margin_total']:>14,.0f}")
    print(f"  Profit share:         ${rev['profit_share_total']:>14,.0f}")
    print(f"  Maturity surplus:     ${rev['maturity_surplus_mean']:>14,.0f}")
    print(f"\n  --- Holidays ---")
    print(f"  Mean holiday years:   {results['holidays']['mean_years']:.2f}")
    print(f"  Paths with zero:      {results['holidays']['pct_zero']:.1f}%")
    print(f"\n  --- Surplus Percentiles by Year ---")
    print(f"  {'Year':>4s}  {'Def%':>7s}  {'P1':>12s}  {'P10':>12s}  {'Median':>12s}  {'P90':>12s}  {'P99':>12s}")
    for yr in [1, 5, 10, 15, 20, 25, 30]:
        p = results['percentiles_by_year'].get(yr, {})
        d = results['deficit_by_year'].get(yr, 0)
        print(f"  {yr:4d}  {d:6.2f}%  ${p.get('p1',0):>11,.0f}  ${p.get('p10',0):>11,.0f}  "
              f"${p.get('median',0):>11,.0f}  ${p.get('p90',0):>11,.0f}  ${p.get('p99',0):>11,.0f}")

    return results


# ============================================================
# PHASE 2: SENSITIVITY ANALYSIS
# ============================================================
def run_sensitivity():
    print("\n" + "=" * 80)
    print("PHASE 2: SENSITIVITY ANALYSIS — Equity Return × Volatility Grid")
    print("=" * 80)

    equity_returns = [0.07, 0.075, 0.08, 0.085, 0.09, 0.094, 0.10, 0.11]
    equity_vols = [0.12, 0.15, 0.175, 0.20, 0.25]

    total_scenarios = len(equity_returns) * len(equity_vols)
    print(f"  Running {total_scenarios} scenarios × {N_PATHS:,} paths each")
    print(f"  Returns: {[f'{r*100:.1f}%' for r in equity_returns]}")
    print(f"  Vols:    {[f'{v*100:.1f}%' for v in equity_vols]}")
    print()

    results_grid = {}
    completed = 0
    start = time.time()

    for eq_ret in equity_returns:
        for eq_vol in equity_vols:
            key = f"ret_{eq_ret:.3f}_vol_{eq_vol:.3f}"
            r = run_single_simulation(
                n_paths=N_PATHS,
                equity_mean=eq_ret,
                equity_vol=eq_vol,
            )
            results_grid[key] = {
                'equity_return': eq_ret,
                'equity_vol': eq_vol,
                'poc': r['deficit_prob'],
                'mean_surplus': r['mean_surplus'],
                'median_surplus': r['median_surplus'],
                'p1': r['p1'],
                'p10': r['p10'],
                'cond_deficit': r['cond_expected_deficit'],
                'lmi_fair': r['insurance']['lmi_fair_premium'],
                'tail_poc': r['insurance']['tail_poc'],
                'mean_holidays': r['holidays']['mean_years'],
            }
            completed += 1
            elapsed = time.time() - start
            eta = (elapsed / completed) * (total_scenarios - completed)
            print(f"  [{completed:2d}/{total_scenarios}] Return={eq_ret*100:5.1f}%, Vol={eq_vol*100:5.1f}% "
                  f"→ PoC={r['deficit_prob']:5.2f}%, Median=${r['median_surplus']:>12,.0f}, "
                  f"P1=${r['p1']:>12,.0f}  ({elapsed:.0f}s, ETA {eta:.0f}s)")

    # Summary table
    print(f"\n  --- PoC (%) Grid: Return × Volatility ---")
    header = f"  {'Return↓ / Vol→':>15s}"
    for v in equity_vols:
        header += f"  {v*100:5.1f}%"
    print(header)
    for ret in equity_returns:
        row = f"  {ret*100:14.1f}%"
        for vol in equity_vols:
            key = f"ret_{ret:.3f}_vol_{vol:.3f}"
            poc = results_grid[key]['poc']
            row += f"  {poc:5.1f}%"
        star = " ◀ BASE" if ret == EQUITY_MEAN else ""
        print(row + star)

    print(f"\n  --- Median Surplus ($) Grid ---")
    print(header)
    for ret in equity_returns:
        row = f"  {ret*100:14.1f}%"
        for vol in equity_vols:
            key = f"ret_{ret:.3f}_vol_{vol:.3f}"
            ms = results_grid[key]['median_surplus']
            if ms >= 0:
                row += f"  {ms/1000:5.0f}K"
            else:
                row += f" {ms/1000:5.0f}K"
        star = " ◀ BASE" if ret == EQUITY_MEAN else ""
        print(row + star)

    print(f"\n  --- 1st Percentile ($) Grid ---")
    print(header)
    for ret in equity_returns:
        row = f"  {ret*100:14.1f}%"
        for vol in equity_vols:
            key = f"ret_{ret:.3f}_vol_{vol:.3f}"
            p1 = results_grid[key]['p1']
            row += f" {p1/1000:5.0f}K"
        star = " ◀ BASE" if ret == EQUITY_MEAN else ""
        print(row + star)

    total_time = time.time() - start
    print(f"\n  Sensitivity analysis completed in {total_time:.0f}s ({total_time/60:.1f} min)")

    return results_grid


# ============================================================
# PHASE 3: STRESS TESTS — Correlation Regimes
# ============================================================
def run_stress_tests():
    print("\n" + "=" * 80)
    print("PHASE 3: STRESS TESTS — Correlation Regime Shifts")
    print("=" * 80)

    correlations = [-0.30, -0.15, 0.0, 0.15, 0.30, 0.45, 0.60]
    print(f"  Testing correlations: {correlations}")
    print(f"  Base case correlation: {CASH_RATE_EQUITY_CORR}")
    print()

    results_corr = {}
    start = time.time()

    for i, corr in enumerate(correlations):
        r = run_single_simulation(n_paths=N_PATHS, correlation=corr)
        results_corr[corr] = {
            'poc': r['deficit_prob'],
            'mean_surplus': r['mean_surplus'],
            'median_surplus': r['median_surplus'],
            'p1': r['p1'],
            'p10': r['p10'],
            'cond_deficit': r['cond_expected_deficit'],
            'mean_holidays': r['holidays']['mean_years'],
        }
        marker = " ◀ BASE" if corr == CASH_RATE_EQUITY_CORR else ""
        print(f"  Corr={corr:+5.2f}: PoC={r['deficit_prob']:5.2f}%, "
              f"Median=${r['median_surplus']:>12,.0f}, P1=${r['p1']:>12,.0f}, "
              f"Holidays={r['holidays']['mean_years']:.2f}{marker}")

    print(f"\n  Correlation stress completed in {time.time()-start:.0f}s")

    # === Cash rate parameter stress ===
    print(f"\n  --- Cash Rate Parameter Stress ---")
    cash_rate_scenarios = [
        ("Low rates (theta=1.5%)", 0.015, CASH_RATE_KAPPA),
        ("Base case (theta=2.13%)", CASH_RATE_THETA, CASH_RATE_KAPPA),
        ("Medium rates (theta=3.5%)", 0.035, CASH_RATE_KAPPA),
        ("High rates (theta=4.5%)", 0.045, CASH_RATE_KAPPA),
        ("High + fast reversion", 0.045, 0.50),
        ("Low + slow reversion", 0.015, 0.10),
    ]

    results_rates = {}
    for name, theta, kappa in cash_rate_scenarios:
        r = run_single_simulation(n_paths=N_PATHS, cash_rate_theta=theta, cash_rate_kappa=kappa)
        results_rates[name] = {
            'theta': theta, 'kappa': kappa,
            'poc': r['deficit_prob'],
            'mean_surplus': r['mean_surplus'],
            'median_surplus': r['median_surplus'],
            'p1': r['p1'],
        }
        print(f"  {name:30s}: PoC={r['deficit_prob']:5.2f}%, Median=${r['median_surplus']:>12,.0f}")

    return results_corr, results_rates


# ============================================================
# PHASE 4: COMBINED ADVERSE SCENARIO
# ============================================================
def run_combined_stress():
    print("\n" + "=" * 80)
    print("PHASE 4: COMBINED ADVERSE SCENARIOS")
    print("=" * 80)

    scenarios = [
        ("Base case",
         dict(equity_mean=0.094, equity_vol=0.175, correlation=0.30,
              cash_rate_theta=0.0213)),
        ("Mild adverse: 8% return, 20% vol",
         dict(equity_mean=0.08, equity_vol=0.20, correlation=0.30,
              cash_rate_theta=0.0213)),
        ("Moderate adverse: 7.5% return, 20% vol, neg corr",
         dict(equity_mean=0.075, equity_vol=0.20, correlation=-0.15,
              cash_rate_theta=0.035)),
        ("Severe: 7% return, 25% vol, neg corr, high rates",
         dict(equity_mean=0.07, equity_vol=0.25, correlation=-0.30,
              cash_rate_theta=0.045)),
        ("Japan scenario: 7% return, 12% vol, low rates",
         dict(equity_mean=0.07, equity_vol=0.12, correlation=0.15,
              cash_rate_theta=0.01)),
        ("GFC-like: 8% long-run but 25% vol, negative corr",
         dict(equity_mean=0.08, equity_vol=0.25, correlation=-0.30,
              cash_rate_theta=0.025)),
        ("Stagflation: low return, high rates, high vol",
         dict(equity_mean=0.07, equity_vol=0.22, correlation=0.0,
              cash_rate_theta=0.05)),
        ("Goldilocks: high return, low vol, moderate rates",
         dict(equity_mean=0.11, equity_vol=0.12, correlation=0.15,
              cash_rate_theta=0.03)),
    ]

    results_combined = {}
    start = time.time()

    for name, params in scenarios:
        r = run_single_simulation(n_paths=N_PATHS, **params)
        results_combined[name] = {
            'params': params,
            'poc': r['deficit_prob'],
            'mean_surplus': r['mean_surplus'],
            'median_surplus': r['median_surplus'],
            'p1': r['p1'],
            'p5': r['p5'],
            'p10': r['p10'],
            'cond_deficit': r['cond_expected_deficit'],
            'lmi_fair': r['insurance']['lmi_fair_premium'],
            'tail_poc': r['insurance']['tail_poc'],
            'mean_holidays': r['holidays']['mean_years'],
            'deficit_by_year': r['deficit_by_year'],
        }
        print(f"  {name:50s}: PoC={r['deficit_prob']:6.2f}%, Median=${r['median_surplus']:>12,.0f}, "
              f"P1=${r['p1']:>12,.0f}, Holidays={r['holidays']['mean_years']:.1f}")

    print(f"\n  Combined stress completed in {time.time()-start:.0f}s")
    return results_combined


# ============================================================
# MAIN
# ============================================================
if __name__ == '__main__':
    total_start = time.time()

    print("╔══════════════════════════════════════════════════════════════════════╗")
    print("║   FutureProof EPM v14c — Comprehensive Actuarial Analysis          ║")
    print("║   50,000 paths × 4 phases                                          ║")
    print("╚══════════════════════════════════════════════════════════════════════╝")
    print()

    # Phase 1: Base case
    base_results = run_base_case()

    # Phase 2: Sensitivity
    sensitivity_results = run_sensitivity()

    # Phase 3: Stress tests
    corr_results, rate_results = run_stress_tests()

    # Phase 4: Combined
    combined_results = run_combined_stress()

    # ============================================================
    # SAVE ALL RESULTS
    # ============================================================
    all_results = {
        'model_version': 'v14c',
        'analysis_date': '2026-04-13',
        'n_paths': N_PATHS,
        'parameters': {
            'home_value': HOME_VALUE,
            'lvr': LVR,
            'initial_loan': INITIAL_LOAN,
            'loan_type': LOAN_TYPE,
            'annuity_pa': ANNUITY_PA,
            'annuity_term_years': ANNUITY_TERM_YEARS,
            'equity_mean': EQUITY_MEAN,
            'equity_vol': EQUITY_VOL,
            'buffer_cap': BUFFER_CAP,
            'buffer_floor': BUFFER_FLOOR,
            'wholesale_margin': WHOLESALE_MARGIN,
            'retail_margin': RETAIL_MARGIN,
            'hedging_fee': HEDGING_FEE,
            'fp_margin': FP_MARGIN,
            'cash_rate_initial': CASH_RATE_INITIAL,
            'cash_rate_theta': CASH_RATE_THETA,
            'cash_rate_kappa': CASH_RATE_KAPPA,
            'cash_rate_sigma': CASH_RATE_SIGMA,
            'correlation': CASH_RATE_EQUITY_CORR,
            'collar_price': COLLAR_PRICE,
        },
        'base_case': base_results,
        'sensitivity': sensitivity_results,
        'correlation_stress': {str(k): v for k, v in corr_results.items()},
        'rate_stress': rate_results,
        'combined_stress': combined_results,
    }

    output_file = 'monte_carlo_v14c_comprehensive_results.json'
    with open(output_file, 'w') as f:
        json.dump(all_results, f, indent=2, default=str)
    print(f"\nResults saved to {output_file}")

    total_elapsed = time.time() - total_start
    print(f"\n{'='*80}")
    print(f"TOTAL ELAPSED: {total_elapsed:.0f}s ({total_elapsed/60:.1f} minutes)")
    print(f"{'='*80}")
