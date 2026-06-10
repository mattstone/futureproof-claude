#!/usr/bin/env python3
"""
EPM v14a Fine-Grid Optimisation Engine
=======================================
Zooms into the optimal region identified by the coarse sweep:
  - Collar: ±25% to ±35%
  - Holiday entry: 0.92 to 1.00
  - Profit share: 15% to 35%
  - FP margin: 0.15% to 0.40%
  - Retail margin: 0.50% to 0.80%

Runs 10,000 paths per scenario for ranking, then 50,000 paths for the top 10.
"""

import numpy as np
import json
import time
from dataclasses import dataclass, asdict
from scipy.stats import norm

# ============================================================
# FIXED PARAMETERS
# ============================================================
HOME_VALUE = 2_000_000
LVR = 0.80
INITIAL_LOAN = 1_350_000
TENURE_YEARS = 30
ANNUITY_PA = 25_000
ANNUITY_TERM_YEARS = 10

WHOLESALE_MARGIN = 0.02
HEDGING_FEE = 0.0025
LMI_UPFRONT_PCT = 0.016
REINSURANCE_UPFRONT_PCT = 0.001

EQUITY_MEAN = 0.10
EQUITY_VOL = 0.10

CASH_RATE_INITIAL = 0.044
CASH_RATE_THETA = 0.044
CASH_RATE_KAPPA = 0.80
CASH_RATE_SIGMA = 0.015
CASH_RATE_EQUITY_CORR = 0.069

PROFIT_SHARE_YEARS = 5
SEED = 42


def estimate_collar_price(cap, floor):
    S, T, r = 1.0, 1.0, 0.0
    vol = EQUITY_VOL
    d1c = (np.log(S / cap) + 0.5 * vol**2 * T) / (vol * np.sqrt(T))
    d2c = d1c - vol * np.sqrt(T)
    call = S * norm.cdf(d1c) - cap * norm.cdf(d2c)
    d1p = (np.log(S / floor) + 0.5 * vol**2 * T) / (vol * np.sqrt(T))
    d2p = d1p - vol * np.sqrt(T)
    put = floor * norm.cdf(-d2p) - S * norm.cdf(-d1p)
    return put - call


@dataclass
class Params:
    profit_share_pct: float
    fp_margin: float
    retail_margin: float
    buffer_cap: float
    buffer_floor: float
    holiday_entry: float
    holiday_exit: float
    label: str = ""


@dataclass
class Result:
    label: str
    profit_share_pct: float
    fp_margin: float
    retail_margin: float
    buffer_cap: float
    buffer_floor: float
    holiday_entry: float
    holiday_exit: float
    collar_price: float

    # Risk
    pod_yr30: float
    pod_yr20: float
    pod_yr15: float
    pod_yr10: float
    cond_expected_deficit: float
    p1_surplus: float
    p5_surplus: float
    p10_surplus: float
    p25_surplus: float
    median_surplus: float
    p75_surplus: float
    p90_surplus: float
    p95_surplus: float
    p99_surplus: float
    fair_premium: float
    fair_premium_loaded: float
    std_surplus: float
    max_drawdown_p1: float  # worst P1 across all years

    # Return
    mean_surplus_yr30: float
    mean_total_profit_share: float
    mean_fp_margin_income: float
    mean_total_fp_revenue: float
    mean_funder_surplus_share: float
    mean_borrower_equity_return: float  # what borrower gets back

    # Efficiency
    revenue_per_unit_risk: float
    sharpe_like: float
    total_variable_cost_pct: float
    premium_as_pct_loan: float

    # Time series (for charts)
    pod_by_year: list
    mean_surplus_by_year: list
    p10_by_year: list
    mean_investment_by_year: list
    mean_holidays_by_year: list


def run_scenario(params, z1, z2, loan_from_funder, max_loan):
    collar_price = estimate_collar_price(params.buffer_cap, params.buffer_floor)
    upfront_LMI = max_loan * LMI_UPFRONT_PCT
    upfront_reinsurance = max_loan * REINSURANCE_UPFRONT_PCT
    holiday_entry_threshold = INITIAL_LOAN * params.holiday_entry
    holiday_exit_threshold = INITIAL_LOAN * params.holiday_exit

    n = z1.shape[0]
    investment = np.full(n, INITIAL_LOAN - upfront_LMI - upfront_reinsurance, dtype=np.float64)
    cash_rate = np.full(n, CASH_RATE_INITIAL, dtype=np.float64)
    holiday_entry_flag = np.zeros(n, dtype=bool)
    holiday_count = np.zeros(n, dtype=np.float64)
    holiday_account = np.zeros(n, dtype=np.float64)
    repayment_step = np.zeros(n, dtype=np.float64)
    funder_interest_tot = np.zeros(n, dtype=np.float64)
    interest_charged_tot = np.zeros(n, dtype=np.float64)
    interest_deficit = np.zeros(n, dtype=np.float64)
    cumulative_profit_share = np.zeros(n)
    cumulative_fp_margin = np.zeros(n)

    pod_by_year = []
    mean_surplus_by_year = []
    p10_by_year = []
    mean_investment_by_year = [float(np.mean(investment))]
    mean_holidays_by_year = []
    worst_p1 = 0.0

    pod_yr10 = pod_yr15 = pod_yr20 = 0.0

    investment *= (1 - collar_price)

    for t in range(1, TENURE_YEARS + 1):
        yi = t - 1
        cash_rate = (cash_rate * np.exp(-CASH_RATE_KAPPA) +
                     CASH_RATE_THETA * (1 - np.exp(-CASH_RATE_KAPPA)) +
                     CASH_RATE_SIGMA * z2[:, yi])
        cash_rate = np.maximum(cash_rate, 0)

        raw_ret = np.exp(EQUITY_MEAN + EQUITY_VOL * z1[:, yi]) - 1
        hedged_ret = np.clip(raw_ret, params.buffer_floor - 1, params.buffer_cap - 1)

        ffc = WHOLESALE_MARGIN + cash_rate
        avg_loan = (loan_from_funder[t-1] + loan_from_funder[t]) / 2
        funder_int = -ffc * avg_loan
        funder_interest_tot += funder_int

        prev_hf = holiday_entry_flag.copy()
        prev_hc = holiday_count.copy()
        entering = (~prev_hf) & (investment < holiday_entry_threshold)
        exiting = prev_hf & (investment > holiday_exit_threshold)
        staying = prev_hf & (~exiting)
        holiday_entry_flag = entering | staying
        holiday_count = np.where(holiday_entry_flag, prev_hc + 1, 0)
        mean_holidays_by_year.append(float(np.mean(holiday_entry_flag)))

        rep_flag = prev_hf & (~holiday_entry_flag)
        new_rep = np.where(rep_flag & (repayment_step <= 0), prev_hc, 0)
        repayment_step = np.where(new_rep > 0, new_rep, np.maximum(repayment_step - 1, 0))

        hao = holiday_account.copy()
        int_hol = np.where(holiday_entry_flag, -funder_int, 0)
        rep_hol = np.where(repayment_step > 0, -hao / np.maximum(repayment_step, 1), 0)
        holiday_account = hao + int_hol + rep_hol

        int_charged = funder_int + int_hol + rep_hol
        interest_charged_tot += int_charged
        interest_deficit = funder_interest_tot - interest_charged_tot

        ret_nim = -params.retail_margin * avg_loan
        fp_pay = -params.fp_margin * investment
        hedge_pay = -HEDGING_FEE * investment
        cumulative_fp_margin += np.abs(fp_pay)

        if t == TENURE_YEARS:
            ret_nim = -params.retail_margin * loan_from_funder[t-1] / 2
            int_charged = -ffc * loan_from_funder[t-1] / 2

        inv_ret = investment * hedged_ret
        investment = investment + inv_ret + int_charged + ret_nim + fp_pay + hedge_pay

        surplus = investment - loan_from_funder[t] + interest_deficit

        if t < TENURE_YEARS and t % PROFIT_SHARE_YEARS == 0:
            ps = np.where(surplus > 0, surplus * params.profit_share_pct, 0)
            investment -= ps
            cumulative_profit_share += ps

        if t == TENURE_YEARS:
            windup = np.maximum(surplus, 0)
            investment -= windup

        if t < TENURE_YEARS:
            investment *= (1 - collar_price)

        dp = float(np.mean(surplus < 0) * 100)
        pod_by_year.append(dp)
        mean_surplus_by_year.append(float(np.mean(surplus)))
        p10_by_year.append(float(np.percentile(surplus, 10)))
        mean_investment_by_year.append(float(np.mean(investment)))
        p1_yr = float(np.percentile(surplus, 1))
        if p1_yr < worst_p1:
            worst_p1 = p1_yr

        if t == 10: pod_yr10 = dp
        if t == 15: pod_yr15 = dp
        if t == 20: pod_yr20 = dp

    fs = surplus  # final surplus at t=30
    pod30 = float(np.mean(fs < 0) * 100)
    dmask = fs < 0
    nd = np.sum(dmask)
    if nd > 0:
        ced = float(np.mean(fs[dmask]))
        disc = np.exp(-CASH_RATE_THETA * TENURE_YEARS)
        fp_raw = float(-np.mean(disc * fs[dmask]) * (pod30 / 100))
    else:
        ced = 0.0
        fp_raw = 0.0

    mat_pos = np.where(fs > 0, fs * 0.5, 0)
    # Borrower equity return: they keep their house + any surplus share
    # In the current model structure, surplus goes to FP and funder, borrower keeps house
    # But borrower benefit = house appreciation (not modelled here) + loan fully paid off
    # We'll track the % of paths where borrower's loan is fully covered (= 1 - PoD)
    borrower_equity_return = float((1 - pod30/100) * 100)

    std_s = float(np.std(fs))
    total_vc = params.retail_margin + params.fp_margin + HEDGING_FEE
    fp_rev = float(np.mean(cumulative_profit_share) + np.mean(cumulative_fp_margin))

    return Result(
        label=params.label,
        profit_share_pct=params.profit_share_pct,
        fp_margin=params.fp_margin,
        retail_margin=params.retail_margin,
        buffer_cap=params.buffer_cap,
        buffer_floor=params.buffer_floor,
        holiday_entry=params.holiday_entry,
        holiday_exit=params.holiday_exit,
        collar_price=round(collar_price, 6),

        pod_yr30=round(pod30, 2),
        pod_yr20=round(pod_yr20, 2),
        pod_yr15=round(pod_yr15, 2),
        pod_yr10=round(pod_yr10, 2),
        cond_expected_deficit=round(ced, 0),
        p1_surplus=round(float(np.percentile(fs, 1)), 0),
        p5_surplus=round(float(np.percentile(fs, 5)), 0),
        p10_surplus=round(float(np.percentile(fs, 10)), 0),
        p25_surplus=round(float(np.percentile(fs, 25)), 0),
        median_surplus=round(float(np.median(fs)), 0),
        p75_surplus=round(float(np.percentile(fs, 75)), 0),
        p90_surplus=round(float(np.percentile(fs, 90)), 0),
        p95_surplus=round(float(np.percentile(fs, 95)), 0),
        p99_surplus=round(float(np.percentile(fs, 99)), 0),
        fair_premium=round(fp_raw, 0),
        fair_premium_loaded=round(fp_raw * 1.5, 0),
        std_surplus=round(std_s, 0),
        max_drawdown_p1=round(worst_p1, 0),

        mean_surplus_yr30=round(float(np.mean(fs)), 0),
        mean_total_profit_share=round(float(np.mean(cumulative_profit_share)), 0),
        mean_fp_margin_income=round(float(np.mean(cumulative_fp_margin)), 0),
        mean_total_fp_revenue=round(fp_rev, 0),
        mean_funder_surplus_share=round(float(np.mean(mat_pos)), 0),
        mean_borrower_equity_return=round(borrower_equity_return, 1),

        revenue_per_unit_risk=round(fp_rev / max(pod30, 0.01), 0),
        sharpe_like=round(float(np.mean(fs)) / max(std_s, 1), 4),
        total_variable_cost_pct=round(total_vc * 100, 2),
        premium_as_pct_loan=round(fp_raw * 1.5 / max_loan * 100, 3),

        pod_by_year=[round(x, 2) for x in pod_by_year],
        mean_surplus_by_year=[round(x, 0) for x in mean_surplus_by_year],
        p10_by_year=[round(x, 0) for x in p10_by_year],
        mean_investment_by_year=[round(x, 0) for x in mean_investment_by_year],
        mean_holidays_by_year=[round(x, 3) for x in mean_holidays_by_year],
    )


def build_fine_grid():
    scenarios = []

    # Fine grid around optimal region
    profit_shares = [0.15, 0.18, 0.20, 0.22, 0.25, 0.28, 0.30, 0.35]
    fp_margins = [0.0015, 0.002, 0.0025, 0.003, 0.0035]
    buffer_caps = [1.25, 1.27, 1.30, 1.33, 1.35]
    holiday_entries = [0.92, 0.94, 0.95, 0.96, 0.98, 1.00]
    retail_margins = [0.005, 0.006, 0.007, 0.008]

    # Holiday exit scaled: exit = entry * 1.62 (same ratio as 0.90 → 1.458)
    HOLIDAY_RATIO = 1.458 / 0.90

    # SWEEP A: Full 4D grid (PS × FM × Cap × Holiday) at RM=0.70%
    for ps in profit_shares:
        for fm in fp_margins:
            for cap in buffer_caps:
                floor = 2.0 - cap  # symmetric collar
                for he in holiday_entries:
                    hx = he * HOLIDAY_RATIO
                    scenarios.append(Params(
                        profit_share_pct=ps, fp_margin=fm,
                        retail_margin=0.007,
                        buffer_cap=cap, buffer_floor=floor,
                        holiday_entry=he, holiday_exit=hx,
                        label=f"PS={ps*100:.0f}_FM={fm*100:.1f}_C±{(cap-1)*100:.0f}_HE={he:.2f}"
                    ))

    # SWEEP B: Retail margin sensitivity at optimal collar/holiday combos
    for rm in retail_margins:
        if rm == 0.007:
            continue
        for cap in [1.28, 1.30, 1.32]:
            floor = 2.0 - cap
            for he in [0.95, 0.96, 0.98]:
                hx = he * HOLIDAY_RATIO
                scenarios.append(Params(
                    profit_share_pct=0.25, fp_margin=0.0025,
                    retail_margin=rm,
                    buffer_cap=cap, buffer_floor=floor,
                    holiday_entry=he, holiday_exit=hx,
                    label=f"RM={rm*100:.1f}_C±{(cap-1)*100:.0f}_HE={he:.2f}"
                ))

    # SWEEP C: v14a baseline for comparison
    scenarios.append(Params(
        profit_share_pct=0.25, fp_margin=0.0025,
        retail_margin=0.007,
        buffer_cap=1.20, buffer_floor=0.80,
        holiday_entry=0.90, holiday_exit=1.458,
        label="v14a_BASELINE"
    ))

    return scenarios


def main():
    print("=" * 80)
    print("EPM v14a FINE-GRID OPTIMISATION")
    print("=" * 80)

    scenarios = build_fine_grid()
    print(f"\nPhase 1: {len(scenarios)} scenarios × 10,000 paths")

    # Pre-compute
    loan = np.zeros(TENURE_YEARS + 1)
    loan[0] = INITIAL_LOAN
    for t in range(1, TENURE_YEARS + 1):
        loan[t] = loan[t-1] + (ANNUITY_PA if t <= ANNUITY_TERM_YEARS else 0)
    max_loan = np.max(loan)

    rng = np.random.default_rng(SEED)
    z1_10k = rng.standard_normal((10_000, TENURE_YEARS))
    z2r_10k = rng.standard_normal((10_000, TENURE_YEARS))
    rho = CASH_RATE_EQUITY_CORR
    z2_10k = rho * z1_10k + np.sqrt(1 - rho**2) * z2r_10k

    start = time.time()
    results_10k = []
    for i, p in enumerate(scenarios):
        if (i+1) % 200 == 0 or i == 0:
            print(f"  {i+1}/{len(scenarios)}...")
        results_10k.append(run_scenario(p, z1_10k, z2_10k, loan, max_loan))

    t1 = time.time() - start
    print(f"  Phase 1 done in {t1:.1f}s ({t1/len(scenarios)*1000:.0f}ms/scenario)")

    # Pareto front
    pareto = []
    for r in results_10k:
        dominated = False
        for r2 in results_10k:
            if (r2.mean_total_fp_revenue > r.mean_total_fp_revenue and
                r2.pod_yr30 < r.pod_yr30):
                dominated = True
                break
        if not dominated:
            pareto.append(r)
    pareto.sort(key=lambda r: r.pod_yr30)

    print(f"\n  Pareto-optimal: {len(pareto)} scenarios")

    # Top candidates by composite score: revenue/risk × sharpe
    for r in results_10k:
        r._composite = r.revenue_per_unit_risk * r.sharpe_like
    top_composite = sorted(results_10k, key=lambda r: r._composite, reverse=True)

    # Select top 20 for 50K validation (union of pareto + top composite + top sharpe + lowest pod)
    top_sharpe = sorted(results_10k, key=lambda r: r.sharpe_like, reverse=True)[:5]
    lowest_pod = sorted(results_10k, key=lambda r: r.pod_yr30)[:5]
    highest_rev = sorted(results_10k, key=lambda r: r.mean_total_fp_revenue, reverse=True)[:5]

    candidates = set()
    for r in pareto[:10]:
        candidates.add(r.label)
    for r in top_composite[:10]:
        candidates.add(r.label)
    for r in top_sharpe:
        candidates.add(r.label)
    for r in lowest_pod:
        candidates.add(r.label)
    for r in highest_rev:
        candidates.add(r.label)
    candidates.add("v14a_BASELINE")

    candidate_params = {p.label: p for p in scenarios}
    validate_labels = list(candidates)
    print(f"\nPhase 2: Validating {len(validate_labels)} candidates × 50,000 paths")

    rng2 = np.random.default_rng(SEED)
    z1_50k = rng2.standard_normal((50_000, TENURE_YEARS))
    z2r_50k = rng2.standard_normal((50_000, TENURE_YEARS))
    z2_50k = rho * z1_50k + np.sqrt(1 - rho**2) * z2r_50k

    results_50k = []
    for i, label in enumerate(validate_labels):
        p = candidate_params[label]
        print(f"  [{i+1}/{len(validate_labels)}] {label}")
        results_50k.append(run_scenario(p, z1_50k, z2_50k, loan, max_loan))

    # Re-compute pareto on 50K results
    pareto_50k = []
    for r in results_50k:
        dominated = False
        for r2 in results_50k:
            if (r2.mean_total_fp_revenue > r.mean_total_fp_revenue and
                r2.pod_yr30 < r.pod_yr30):
                dominated = True
                break
        if not dominated:
            pareto_50k.append(r)
    pareto_50k.sort(key=lambda r: r.pod_yr30)

    # Print results
    print("\n" + "=" * 80)
    print("FINE-GRID RESULTS (50,000-path validated)")
    print("=" * 80)

    print(f"\n--- PARETO FRONT ({len(pareto_50k)} scenarios) ---")
    print(f"  {'#':>3}  {'Label':45s}  {'PoD%':>6}  {'FP Rev':>12}  {'Sharpe':>7}  "
          f"{'Mean Surp':>12}  {'P1':>12}  {'Premium':>10}")
    print("  " + "-" * 150)
    for i, r in enumerate(pareto_50k):
        marker = " ★" if r.label == "v14a_BASELINE" else ""
        print(f"  {i+1:3d}  {r.label:45s}  {r.pod_yr30:5.1f}%  ${r.mean_total_fp_revenue:>11,.0f}  "
              f"{r.sharpe_like:6.3f}  ${r.mean_surplus_yr30:>11,.0f}  "
              f"${r.p1_surplus:>11,.0f}  ${r.fair_premium_loaded:>9,.0f}{marker}")

    print(f"\n--- ALL 50K VALIDATED (sorted by Sharpe) ---")
    print(f"  {'#':>3}  {'Label':45s}  {'PoD%':>6}  {'Sharpe':>7}  {'FP Rev':>12}  "
          f"{'Mean Surp':>12}  {'Median':>12}  {'P1':>12}  {'P10':>12}")
    print("  " + "-" * 165)
    for i, r in enumerate(sorted(results_50k, key=lambda r: r.sharpe_like, reverse=True)):
        marker = " ★" if r.label == "v14a_BASELINE" else ""
        print(f"  {i+1:3d}  {r.label:45s}  {r.pod_yr30:5.1f}%  {r.sharpe_like:6.3f}  "
              f"${r.mean_total_fp_revenue:>11,.0f}  ${r.mean_surplus_yr30:>11,.0f}  "
              f"${r.median_surplus:>11,.0f}  ${r.p1_surplus:>11,.0f}  ${r.p10_surplus:>11,.0f}{marker}")

    # Find the "recommended" config: highest composite on 50K
    for r in results_50k:
        r._composite = r.revenue_per_unit_risk * r.sharpe_like
    recommended = max(results_50k, key=lambda r: r._composite)

    baseline = [r for r in results_50k if r.label == "v14a_BASELINE"]
    if baseline:
        bl = baseline[0]
        print(f"\n--- v14a BASELINE vs RECOMMENDED ---")
        print(f"  {'Metric':35s}  {'v14a Baseline':>15s}  {'Recommended':>15s}  {'Change':>12s}")
        print("  " + "-" * 85)
        comparisons = [
            ("PoD at Year 30", f"{bl.pod_yr30:.1f}%", f"{recommended.pod_yr30:.1f}%",
             f"{recommended.pod_yr30 - bl.pod_yr30:+.1f}pp"),
            ("PoD at Year 15", f"{bl.pod_yr15:.1f}%", f"{recommended.pod_yr15:.1f}%",
             f"{recommended.pod_yr15 - bl.pod_yr15:+.1f}pp"),
            ("Mean Surplus Yr30", f"${bl.mean_surplus_yr30:>12,.0f}", f"${recommended.mean_surplus_yr30:>12,.0f}",
             f"{(recommended.mean_surplus_yr30/bl.mean_surplus_yr30 - 1)*100:+.0f}%"),
            ("Median Surplus Yr30", f"${bl.median_surplus:>12,.0f}", f"${recommended.median_surplus:>12,.0f}",
             f"{(recommended.median_surplus/bl.median_surplus - 1)*100:+.0f}%"),
            ("P1 Surplus (worst)", f"${bl.p1_surplus:>12,.0f}", f"${recommended.p1_surplus:>12,.0f}",
             f"{(recommended.p1_surplus/bl.p1_surplus - 1)*100:+.0f}%"),
            ("P10 Surplus (LMI cap)", f"${bl.p10_surplus:>12,.0f}", f"${recommended.p10_surplus:>12,.0f}",
             f"${recommended.p10_surplus - bl.p10_surplus:>+12,.0f}"),
            ("Sharpe-like ratio", f"{bl.sharpe_like:.3f}", f"{recommended.sharpe_like:.3f}",
             f"{(recommended.sharpe_like/bl.sharpe_like - 1)*100:+.0f}%"),
            ("FP Total Revenue", f"${bl.mean_total_fp_revenue:>12,.0f}", f"${recommended.mean_total_fp_revenue:>12,.0f}",
             f"{(recommended.mean_total_fp_revenue/bl.mean_total_fp_revenue - 1)*100:+.0f}%"),
            ("  - Profit Share", f"${bl.mean_total_profit_share:>12,.0f}", f"${recommended.mean_total_profit_share:>12,.0f}",
             ""),
            ("  - FP Margin", f"${bl.mean_fp_margin_income:>12,.0f}", f"${recommended.mean_fp_margin_income:>12,.0f}",
             ""),
            ("Funder Surplus Share", f"${bl.mean_funder_surplus_share:>12,.0f}", f"${recommended.mean_funder_surplus_share:>12,.0f}",
             f"{(recommended.mean_funder_surplus_share/max(bl.mean_funder_surplus_share,1) - 1)*100:+.0f}%"),
            ("Insurance Premium (loaded)", f"${bl.fair_premium_loaded:>12,.0f}", f"${recommended.fair_premium_loaded:>12,.0f}",
             f"{(recommended.fair_premium_loaded/max(bl.fair_premium_loaded,1) - 1)*100:+.0f}%"),
            ("Cond. Expected Deficit", f"${bl.cond_expected_deficit:>12,.0f}", f"${recommended.cond_expected_deficit:>12,.0f}",
             f"{(recommended.cond_expected_deficit/bl.cond_expected_deficit - 1)*100:+.0f}%"),
            ("Revenue/Risk", f"${bl.revenue_per_unit_risk:>12,.0f}", f"${recommended.revenue_per_unit_risk:>12,.0f}",
             f"{(recommended.revenue_per_unit_risk/bl.revenue_per_unit_risk - 1)*100:+.0f}%"),
        ]
        for label, v1, v2, chg in comparisons:
            print(f"  {label:35s}  {v1:>15s}  {v2:>15s}  {chg:>12s}")

        print(f"\n  Recommended config: {recommended.label}")
        print(f"    Profit Share:  {recommended.profit_share_pct*100:.0f}%")
        print(f"    FP Margin:     {recommended.fp_margin*100:.2f}%")
        print(f"    Retail Margin: {recommended.retail_margin*100:.2f}%")
        print(f"    Buffer Cap:    {recommended.buffer_cap:.0%}")
        print(f"    Buffer Floor:  {recommended.buffer_floor:.0%}")
        print(f"    Holiday Entry: {recommended.holiday_entry:.2f}")
        print(f"    Holiday Exit:  {recommended.holiday_exit:.2f}")
        print(f"    Collar Price:  {recommended.collar_price:.4f}")

    # Save everything
    output = {
        'metadata': {
            'phase1_scenarios': len(results_10k),
            'phase1_paths': 10_000,
            'phase2_scenarios': len(results_50k),
            'phase2_paths': 50_000,
            'seed': SEED,
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        },
        'recommended': asdict(recommended),
        'baseline': asdict(bl) if baseline else None,
        'pareto_front_50k': [asdict(r) for r in pareto_50k],
        'all_50k_validated': [asdict(r) for r in sorted(results_50k, key=lambda r: r.sharpe_like, reverse=True)],
        'all_10k_results': [asdict(r) for r in sorted(results_10k, key=lambda r: r.sharpe_like, reverse=True)[:50]],
    }

    # Clean up non-serializable attrs
    for d in output.get('all_50k_validated', []):
        d.pop('_composite', None)
    for d in output.get('all_10k_results', []):
        d.pop('_composite', None)
    if output.get('recommended'):
        output['recommended'].pop('_composite', None)
    if output.get('baseline'):
        output['baseline'].pop('_composite', None)
    for d in output.get('pareto_front_50k', []):
        d.pop('_composite', None)

    with open('optimisation_v14a_fine_results.json', 'w') as f:
        json.dump(output, f, indent=2)
    print(f"\nResults saved to optimisation_v14a_fine_results.json")


if __name__ == '__main__':
    main()
