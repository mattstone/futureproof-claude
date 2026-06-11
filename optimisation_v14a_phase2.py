#!/usr/bin/env python3
"""
EPM v14a Comprehensive Optimisation — PHASE 2
===============================================
Constraint: Borrower income UNCHANGED ($25,000/yr × 10 years = $250,000 total)

Optimises all other levers:
  - Loan Type: P&I vs IO
  - Collar Width: ±20% to ±40%
  - Holiday Entry/Exit
  - Profit Share % and Frequency
  - FP Margin

Phase 1: Individual lever sweeps at fixed annuity (10yr × $25K)
Phase 2: Combined grid of best values
Phase 3: Top candidates validated at 50K paths
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
ANNUITY_TERM = 10  # FIXED — not optimised

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

SEED = 42
HOLIDAY_RATIO = 1.458 / 0.90


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
    loan_type: str  # "IO" or "PI"
    profit_share_pct: float
    profit_share_years: int
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
    loan_type: str
    profit_share_pct: float
    profit_share_years: int
    fp_margin: float
    retail_margin: float
    buffer_cap: float
    buffer_floor: float
    holiday_entry: float
    holiday_exit: float
    collar_price: float

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
    max_drawdown_p1: float

    mean_surplus_yr30: float
    mean_total_profit_share: float
    mean_fp_margin_income: float
    mean_total_fp_revenue: float
    mean_funder_surplus_share: float
    mean_borrower_equity_return: float
    mean_final_loan_balance: float

    revenue_per_unit_risk: float
    sharpe_like: float
    total_variable_cost_pct: float
    premium_as_pct_loan: float

    pod_by_year: list
    mean_surplus_by_year: list
    p10_by_year: list
    mean_investment_by_year: list
    mean_holidays_by_year: list
    mean_loan_by_year: list


def build_loan_trajectory(loan_type):
    loan = np.zeros(TENURE_YEARS + 1)
    loan[0] = INITIAL_LOAN
    for t in range(1, TENURE_YEARS + 1):
        if t <= ANNUITY_TERM:
            loan[t] = loan[t-1] + ANNUITY_PA
        else:
            loan[t] = loan[t-1]

    if loan_type == "PI":
        remaining = TENURE_YEARS - ANNUITY_TERM
        if remaining > 0:
            peak = loan[ANNUITY_TERM]
            annual_principal = peak / remaining
            for t in range(ANNUITY_TERM + 1, TENURE_YEARS + 1):
                loan[t] = max(loan[t-1] - annual_principal, 0)
    return loan


def run_scenario(params, z1, z2):
    collar_price = estimate_collar_price(params.buffer_cap, params.buffer_floor)
    loan = build_loan_trajectory(params.loan_type)
    max_loan = np.max(loan)

    upfront_LMI = max_loan * LMI_UPFRONT_PCT
    upfront_reinsurance = max_loan * REINSURANCE_UPFRONT_PCT
    hol_entry_thresh = INITIAL_LOAN * params.holiday_entry
    hol_exit_thresh = INITIAL_LOAN * params.holiday_exit

    n = z1.shape[0]
    investment = np.full(n, INITIAL_LOAN - upfront_LMI - upfront_reinsurance, dtype=np.float64)
    cash_rate = np.full(n, CASH_RATE_INITIAL, dtype=np.float64)
    hol_flag = np.zeros(n, dtype=bool)
    hol_count = np.zeros(n, dtype=np.float64)
    hol_account = np.zeros(n, dtype=np.float64)
    rep_step = np.zeros(n, dtype=np.float64)
    fi_tot = np.zeros(n, dtype=np.float64)
    ic_tot = np.zeros(n, dtype=np.float64)
    int_deficit = np.zeros(n, dtype=np.float64)
    cum_ps = np.zeros(n)
    cum_fm = np.zeros(n)

    pod_by_year = []
    mean_surp_by_year = []
    p10_by_year = []
    mean_inv_by_year = [float(np.mean(investment))]
    mean_hol_by_year = []
    mean_loan_by_year = [float(loan[0])]
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
        avg_loan = (loan[t-1] + loan[t]) / 2
        fi = -ffc * avg_loan
        fi_tot += fi

        prev_hf = hol_flag.copy()
        prev_hc = hol_count.copy()
        entering = (~prev_hf) & (investment < hol_entry_thresh)
        exiting = prev_hf & (investment > hol_exit_thresh)
        staying = prev_hf & (~exiting)
        hol_flag = entering | staying
        hol_count = np.where(hol_flag, prev_hc + 1, 0)
        mean_hol_by_year.append(float(np.mean(hol_flag)))

        rf = prev_hf & (~hol_flag)
        nr = np.where(rf & (rep_step <= 0), prev_hc, 0)
        rep_step = np.where(nr > 0, nr, np.maximum(rep_step - 1, 0))

        hao = hol_account.copy()
        ih = np.where(hol_flag, -fi, 0)
        rh = np.where(rep_step > 0, -hao / np.maximum(rep_step, 1), 0)
        hol_account = hao + ih + rh

        ic = fi + ih + rh
        ic_tot += ic
        int_deficit = fi_tot - ic_tot

        rn = -params.retail_margin * avg_loan
        fp = -params.fp_margin * investment
        hf = -HEDGING_FEE * investment
        cum_fm += np.abs(fp)

        principal_payment = 0.0
        if params.loan_type == "PI" and t > ANNUITY_TERM:
            pd_due = loan[t-1] - loan[t]
            if pd_due > 0:
                principal_payment = -pd_due

        if t == TENURE_YEARS:
            rn = -params.retail_margin * loan[t-1] / 2
            ic = -ffc * loan[t-1] / 2

        inv_ret = investment * hedged_ret
        investment = investment + inv_ret + ic + rn + fp + hf + principal_payment

        surplus = investment - loan[t] + int_deficit

        if t < TENURE_YEARS and t % params.profit_share_years == 0:
            ps = np.where(surplus > 0, surplus * params.profit_share_pct, 0)
            investment -= ps
            cum_ps += ps

        if t == TENURE_YEARS:
            windup = np.maximum(surplus, 0)
            investment -= windup

        if t < TENURE_YEARS:
            investment *= (1 - collar_price)

        dp = float(np.mean(surplus < 0) * 100)
        pod_by_year.append(dp)
        mean_surp_by_year.append(float(np.mean(surplus)))
        p10_by_year.append(float(np.percentile(surplus, 10)))
        mean_inv_by_year.append(float(np.mean(investment)))
        mean_loan_by_year.append(float(loan[t]))
        p1y = float(np.percentile(surplus, 1))
        if p1y < worst_p1:
            worst_p1 = p1y

        if t == 10: pod_yr10 = dp
        if t == 15: pod_yr15 = dp
        if t == 20: pod_yr20 = dp

    fs = surplus
    pod30 = float(np.mean(fs < 0) * 100)
    dm = fs < 0
    nd = np.sum(dm)
    ced = float(np.mean(fs[dm])) if nd > 0 else 0.0
    disc = np.exp(-CASH_RATE_THETA * TENURE_YEARS)
    fp_raw = float(-np.mean(disc * fs[dm]) * (pod30 / 100)) if nd > 0 else 0.0

    mat_pos = np.where(fs > 0, fs * 0.5, 0)
    beq = float((1 - pod30 / 100) * 100)
    std_s = float(np.std(fs))
    total_vc = params.retail_margin + params.fp_margin + HEDGING_FEE
    fp_rev = float(np.mean(cum_ps) + np.mean(cum_fm))

    return Result(
        label=params.label,
        loan_type=params.loan_type,
        profit_share_pct=params.profit_share_pct,
        profit_share_years=params.profit_share_years,
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
        mean_total_profit_share=round(float(np.mean(cum_ps)), 0),
        mean_fp_margin_income=round(float(np.mean(cum_fm)), 0),
        mean_total_fp_revenue=round(fp_rev, 0),
        mean_funder_surplus_share=round(float(np.mean(mat_pos)), 0),
        mean_borrower_equity_return=round(beq, 1),
        mean_final_loan_balance=round(float(loan[TENURE_YEARS]), 0),

        revenue_per_unit_risk=round(fp_rev / max(pod30, 0.01), 0),
        sharpe_like=round(float(np.mean(fs)) / max(std_s, 1), 4),
        total_variable_cost_pct=round(total_vc * 100, 2),
        premium_as_pct_loan=round(fp_raw * 1.5 / max(max_loan, 1) * 100, 3),

        pod_by_year=[round(x, 2) for x in pod_by_year],
        mean_surplus_by_year=[round(x, 0) for x in mean_surp_by_year],
        p10_by_year=[round(x, 0) for x in p10_by_year],
        mean_investment_by_year=[round(x, 0) for x in mean_inv_by_year],
        mean_holidays_by_year=[round(x, 3) for x in mean_hol_by_year],
        mean_loan_by_year=[round(x, 0) for x in mean_loan_by_year],
    )


# ============================================================
# BASELINE
# ============================================================
BASELINE = dict(
    loan_type="IO", profit_share_pct=0.25, profit_share_years=5,
    fp_margin=0.0025, retail_margin=0.007,
    buffer_cap=1.20, buffer_floor=0.80,
    holiday_entry=0.90, holiday_exit=1.458,
)


def mkp(label, **kw):
    p = dict(BASELINE)
    p.update(kw)
    return Params(label=label, **p)


# ============================================================
# SCENARIO BUILDERS
# ============================================================
def build_phase1():
    s = []

    # Baselines
    s.append(mkp("v14a_BASELINE"))
    s.append(mkp("PI_baseline", loan_type="PI"))

    # ── Loan Type × Collar ──
    for cap_pct in [20, 22, 25, 28, 30, 33, 35, 40]:
        cap = 1 + cap_pct / 100
        floor = 2 - cap
        s.append(mkp(f"IO_±{cap_pct}%", buffer_cap=cap, buffer_floor=floor))
        s.append(mkp(f"PI_±{cap_pct}%", loan_type="PI", buffer_cap=cap, buffer_floor=floor))

    # ── Holiday Entry (IO and PI) ──
    for entry in [0.85, 0.90, 0.92, 0.95, 0.98, 1.00, 1.02, 1.05]:
        ex = entry * HOLIDAY_RATIO
        for lt in ["IO", "PI"]:
            if lt == "IO" and abs(entry - 0.90) < 0.005:
                continue  # already baseline
            s.append(mkp(f"{lt}_HE={entry:.2f}", loan_type=lt,
                         holiday_entry=entry, holiday_exit=ex))

    # No holidays
    s.append(mkp("IO_no_holiday", holiday_entry=0.0, holiday_exit=99.0))
    s.append(mkp("PI_no_holiday", loan_type="PI", holiday_entry=0.0, holiday_exit=99.0))

    # ── PS% (IO and PI) ──
    for ps in [0.10, 0.15, 0.20, 0.25, 0.30, 0.35]:
        if abs(ps - 0.25) < 0.005:
            continue
        s.append(mkp(f"IO_PS={ps*100:.0f}%", profit_share_pct=ps))
        s.append(mkp(f"PI_PS={ps*100:.0f}%", loan_type="PI", profit_share_pct=ps))

    # ── PS Frequency ──
    for ps in [0.15, 0.20, 0.25]:
        s.append(mkp(f"IO_PS={ps*100:.0f}%_q3", profit_share_pct=ps, profit_share_years=3))
        s.append(mkp(f"PI_PS={ps*100:.0f}%_q3", loan_type="PI", profit_share_pct=ps, profit_share_years=3))

    # ── FP Margin ──
    for fm in [0.001, 0.0015, 0.002, 0.003, 0.004]:
        s.append(mkp(f"IO_FM={fm*100:.2f}%", fp_margin=fm))
        s.append(mkp(f"PI_FM={fm*100:.2f}%", loan_type="PI", fp_margin=fm))

    return s


def build_phase2():
    s = []

    loan_types = ["IO", "PI"]
    collars = [(1.25, 0.75), (1.30, 0.70), (1.35, 0.65)]
    holidays = [0.95, 1.00, 1.05]
    ps_configs = [
        (0.20, 5), (0.25, 5), (0.30, 5),
        (0.15, 3), (0.20, 3), (0.25, 3),
    ]
    fp_margins = [0.0015, 0.0025]

    for lt in loan_types:
        for cap, floor in collars:
            for he in holidays:
                hx = he * HOLIDAY_RATIO
                for ps_pct, ps_yr in ps_configs:
                    for fm in fp_margins:
                        label = (f"{lt}_C±{(cap-1)*100:.0f}_HE={he:.2f}_"
                                 f"PS={ps_pct*100:.0f}q{ps_yr}_FM={fm*100:.1f}")
                        s.append(Params(
                            label=label, loan_type=lt,
                            profit_share_pct=ps_pct, profit_share_years=ps_yr,
                            fp_margin=fm, retail_margin=0.007,
                            buffer_cap=cap, buffer_floor=floor,
                            holiday_entry=he, holiday_exit=hx,
                        ))

    return s


def find_pareto(results):
    pareto = []
    for r in results:
        dominated = False
        for r2 in results:
            if (r2.mean_total_fp_revenue > r.mean_total_fp_revenue and
                r2.pod_yr30 < r.pod_yr30):
                dominated = True
                break
        if not dominated:
            pareto.append(r)
    return sorted(pareto, key=lambda r: r.pod_yr30)


def print_table(title, results, n=20):
    print(f"\n--- {title} ---")
    print(f"  {'#':>3}  {'Label':55s}  {'Type':>4}  {'PoD%':>6}  {'FP Rev':>12}  "
          f"{'Sharpe':>7}  {'Mean Surp':>12}  {'P1':>12}  {'Prem':>10}")
    print("  " + "-" * 145)
    for i, r in enumerate(results[:n]):
        print(f"  {i+1:3d}  {r.label:55s}  {r.loan_type:>4s}  {r.pod_yr30:5.1f}%  "
              f"${r.mean_total_fp_revenue:>11,.0f}  {r.sharpe_like:6.3f}  "
              f"${r.mean_surplus_yr30:>11,.0f}  ${r.p1_surplus:>11,.0f}  "
              f"${r.fair_premium_loaded:>9,.0f}")


def main():
    print("=" * 80)
    print("EPM v14a PHASE 2: OPTIMISATION WITH FIXED INCOME")
    print(f"Annuity: ${ANNUITY_PA:,}/yr × {ANNUITY_TERM}yr = ${ANNUITY_PA * ANNUITY_TERM:,} total")
    print("=" * 80)

    rng = np.random.default_rng(SEED)
    z1_10k = rng.standard_normal((10_000, TENURE_YEARS))
    z2r = rng.standard_normal((10_000, TENURE_YEARS))
    rho = CASH_RATE_EQUITY_CORR
    z2_10k = rho * z1_10k + np.sqrt(1 - rho**2) * z2r

    # ── Phase 1 ──
    p1_scenarios = build_phase1()
    print(f"\nPhase 1: {len(p1_scenarios)} scenarios × 10,000 paths")

    t0 = time.time()
    r1 = []
    for i, p in enumerate(p1_scenarios):
        if (i+1) % 20 == 0 or i == 0:
            print(f"  [{i+1}/{len(p1_scenarios)}] {p.label}")
        r1.append(run_scenario(p, z1_10k, z2_10k))
    print(f"  Done in {time.time()-t0:.1f}s")

    bl = next(r for r in r1 if r.label == "v14a_BASELINE")

    # Individual lever analysis
    print(f"\n{'='*80}")
    print("INDIVIDUAL LEVER ANALYSIS (delta vs v14a baseline)")
    print(f"{'='*80}")

    # Loan Type
    pi_bl = next(r for r in r1 if r.label == "PI_baseline")
    print(f"\n  LOAN TYPE:")
    print(f"    IO: PoD={bl.pod_yr30:.1f}%, Surplus=${bl.mean_surplus_yr30:>11,.0f}, Sharpe={bl.sharpe_like:.3f}")
    print(f"    PI: PoD={pi_bl.pod_yr30:.1f}%, Surplus=${pi_bl.mean_surplus_yr30:>11,.0f}, Sharpe={pi_bl.sharpe_like:.3f}")
    print(f"    → P&I reduces PoD by {bl.pod_yr30 - pi_bl.pod_yr30:.1f}pp, Sharpe +{pi_bl.sharpe_like - bl.sharpe_like:.3f}")

    # Collar
    print(f"\n  COLLAR WIDTH (IO vs PI):")
    print(f"    {'Width':>8s}  {'IO PoD%':>8s}  {'IO Surp':>12s}  {'PI PoD%':>8s}  {'PI Surp':>12s}  {'PI Sharpe':>10s}")
    for cap_pct in [20, 22, 25, 28, 30, 33, 35, 40]:
        io_r = next((r for r in r1 if r.label == f"IO_±{cap_pct}%"), None)
        pi_r = next((r for r in r1 if r.label == f"PI_±{cap_pct}%"), None)
        if io_r and pi_r:
            print(f"    ±{cap_pct:2d}%     {io_r.pod_yr30:6.1f}%  ${io_r.mean_surplus_yr30:>11,.0f}  "
                  f"{pi_r.pod_yr30:6.1f}%  ${pi_r.mean_surplus_yr30:>11,.0f}  {pi_r.sharpe_like:9.3f}")

    # Holiday
    print(f"\n  HOLIDAY ENTRY (PI only):")
    print(f"    {'Entry':>8s}  {'PoD%':>6s}  {'Surplus':>12s}  {'Sharpe':>8s}  {'Premium':>10s}")
    for entry in [0.85, 0.90, 0.92, 0.95, 0.98, 1.00, 1.02, 1.05]:
        r = next((r for r in r1 if r.label == f"PI_HE={entry:.2f}"), None)
        if r:
            print(f"    {entry:7.2f}  {r.pod_yr30:5.1f}%  ${r.mean_surplus_yr30:>11,.0f}  "
                  f"{r.sharpe_like:7.3f}  ${r.fair_premium_loaded:>9,.0f}")

    # PS%
    print(f"\n  PROFIT SHARE % (PI only):")
    for ps in [0.10, 0.15, 0.20, 0.25, 0.30, 0.35]:
        r = next((r for r in r1 if r.label == f"PI_PS={ps*100:.0f}%"), None) if abs(ps-0.25)>0.005 else pi_bl
        if r:
            print(f"    {ps*100:4.0f}%: PoD={r.pod_yr30:.1f}%, Rev=${r.mean_total_fp_revenue:>11,.0f}, "
                  f"Sharpe={r.sharpe_like:.3f}")

    # PS Frequency
    print(f"\n  PROFIT SHARE FREQUENCY (PI only):")
    for ps in [0.15, 0.20, 0.25]:
        r3 = next((r for r in r1 if r.label == f"PI_PS={ps*100:.0f}%_q3"), None)
        if r3:
            print(f"    {ps*100:.0f}% q3: PoD={r3.pod_yr30:.1f}%, Rev=${r3.mean_total_fp_revenue:>11,.0f}, "
                  f"Sharpe={r3.sharpe_like:.3f}")

    # ── Phase 2 ──
    p2_scenarios = build_phase2()
    print(f"\n\n{'='*80}")
    print(f"COMBINED OPTIMISATION: {len(p2_scenarios)} scenarios × 10,000 paths")
    print(f"{'='*80}")

    t1 = time.time()
    r2 = []
    for i, p in enumerate(p2_scenarios):
        if (i+1) % 50 == 0 or i == 0:
            print(f"  [{i+1}/{len(p2_scenarios)}] {p.label}")
        r2.append(run_scenario(p, z1_10k, z2_10k))
    print(f"  Done in {time.time()-t1:.1f}s")

    all_r = r1 + r2
    for r in all_r:
        r._composite = r.revenue_per_unit_risk * r.sharpe_like

    pareto = find_pareto(all_r)
    top_comp = sorted(all_r, key=lambda r: r._composite, reverse=True)
    top_sharpe = sorted(all_r, key=lambda r: r.sharpe_like, reverse=True)
    lowest_pod = sorted(all_r, key=lambda r: r.pod_yr30)

    print_table(f"PARETO FRONT ({len(pareto)} scenarios)", pareto)
    print_table("TOP 20 BY COMPOSITE SCORE", top_comp)
    print_table("TOP 20 SAFEST (lowest PoD)", lowest_pod)

    # ── Phase 3: 50K validation ──
    candidates = set(["v14a_BASELINE", "PI_baseline"])
    for r in pareto[:10]: candidates.add(r.label)
    for r in top_comp[:10]: candidates.add(r.label)
    for r in top_sharpe[:5]: candidates.add(r.label)
    for r in lowest_pod[:5]: candidates.add(r.label)

    all_params = {p.label: p for p in p1_scenarios + p2_scenarios}
    val_labels = [l for l in candidates if l in all_params]

    print(f"\n\n{'='*80}")
    print(f"50,000-PATH VALIDATION: {len(val_labels)} candidates")
    print(f"{'='*80}")

    rng2 = np.random.default_rng(SEED)
    z1_50k = rng2.standard_normal((50_000, TENURE_YEARS))
    z2r_50k = rng2.standard_normal((50_000, TENURE_YEARS))
    z2_50k = rho * z1_50k + np.sqrt(1 - rho**2) * z2r_50k

    r50k = []
    for i, label in enumerate(val_labels):
        p = all_params[label]
        print(f"  [{i+1}/{len(val_labels)}] {label}")
        r50k.append(run_scenario(p, z1_50k, z2_50k))

    for r in r50k:
        r._composite = r.revenue_per_unit_risk * r.sharpe_like

    pareto_50k = find_pareto(r50k)
    recommended = max(r50k, key=lambda r: r._composite)
    bl_50k = next((r for r in r50k if r.label == "v14a_BASELINE"), None)

    print_table(f"PARETO FRONT — 50K ({len(pareto_50k)} scenarios)", pareto_50k)
    print_table("ALL VALIDATED (by composite)", sorted(r50k, key=lambda r: r._composite, reverse=True), n=30)

    # ── Final comparison ──
    if bl_50k:
        print(f"\n{'='*80}")
        print("FINAL: v14a BASELINE vs RECOMMENDED (income preserved at $250,000)")
        print(f"{'='*80}")

        print(f"\n  {'Metric':40s}  {'v14a Baseline':>15s}  {'Recommended':>15s}  {'Change':>12s}")
        print("  " + "-" * 90)

        rows = [
            ("", "", "", ""),
            ("Configuration", "", "", ""),
            ("  Loan Type", bl_50k.loan_type, recommended.loan_type, ""),
            ("  Collar Width", f"±{(bl_50k.buffer_cap-1)*100:.0f}%", f"±{(recommended.buffer_cap-1)*100:.0f}%", ""),
            ("  Holiday Entry", f"{bl_50k.holiday_entry:.2f}", f"{recommended.holiday_entry:.2f}", ""),
            ("  PS %", f"{bl_50k.profit_share_pct*100:.0f}%", f"{recommended.profit_share_pct*100:.0f}%", ""),
            ("  PS Frequency", f"q{bl_50k.profit_share_years}", f"q{recommended.profit_share_years}", ""),
            ("  FP Margin", f"{bl_50k.fp_margin*100:.2f}%", f"{recommended.fp_margin*100:.2f}%", ""),
            ("  Annuity", "$25,000/yr × 10yr", "$25,000/yr × 10yr", "UNCHANGED"),
            ("  Total Income", "$250,000", "$250,000", "UNCHANGED"),
            ("", "", "", ""),
            ("Risk", "", "", ""),
            ("  PoD Year 30", f"{bl_50k.pod_yr30:.1f}%", f"{recommended.pod_yr30:.1f}%",
             f"{recommended.pod_yr30 - bl_50k.pod_yr30:+.1f}pp"),
            ("  PoD Year 15", f"{bl_50k.pod_yr15:.1f}%", f"{recommended.pod_yr15:.1f}%",
             f"{recommended.pod_yr15 - bl_50k.pod_yr15:+.1f}pp"),
            ("  Mean Surplus", f"${bl_50k.mean_surplus_yr30:>12,.0f}", f"${recommended.mean_surplus_yr30:>12,.0f}",
             f"+{(recommended.mean_surplus_yr30/bl_50k.mean_surplus_yr30 - 1)*100:.0f}%"),
            ("  Median Surplus", f"${bl_50k.median_surplus:>12,.0f}", f"${recommended.median_surplus:>12,.0f}",
             f"+{(recommended.median_surplus/bl_50k.median_surplus - 1)*100:.0f}%"),
            ("  P1 Surplus", f"${bl_50k.p1_surplus:>12,.0f}", f"${recommended.p1_surplus:>12,.0f}", ""),
            ("  P10 Surplus", f"${bl_50k.p10_surplus:>12,.0f}", f"${recommended.p10_surplus:>12,.0f}", ""),
            ("  Sharpe", f"{bl_50k.sharpe_like:.3f}", f"{recommended.sharpe_like:.3f}",
             f"+{(recommended.sharpe_like/bl_50k.sharpe_like - 1)*100:.0f}%"),
            ("  Premium", f"${bl_50k.fair_premium_loaded:>12,.0f}", f"${recommended.fair_premium_loaded:>12,.0f}",
             f"{(recommended.fair_premium_loaded/max(bl_50k.fair_premium_loaded,1) - 1)*100:+.0f}%"),
            ("", "", "", ""),
            ("Revenue", "", "", ""),
            ("  FP Total Revenue", f"${bl_50k.mean_total_fp_revenue:>12,.0f}", f"${recommended.mean_total_fp_revenue:>12,.0f}",
             f"+{(recommended.mean_total_fp_revenue/bl_50k.mean_total_fp_revenue - 1)*100:.0f}%"),
            ("    Profit Share", f"${bl_50k.mean_total_profit_share:>12,.0f}", f"${recommended.mean_total_profit_share:>12,.0f}", ""),
            ("    FP Margin", f"${bl_50k.mean_fp_margin_income:>12,.0f}", f"${recommended.mean_fp_margin_income:>12,.0f}", ""),
            ("  Funder Surplus", f"${bl_50k.mean_funder_surplus_share:>12,.0f}", f"${recommended.mean_funder_surplus_share:>12,.0f}",
             f"+{(recommended.mean_funder_surplus_share/max(bl_50k.mean_funder_surplus_share,1) - 1)*100:.0f}%"),
            ("", "", "", ""),
            ("Borrower", "", "", ""),
            ("  Final Loan Balance", f"${bl_50k.mean_final_loan_balance:>12,.0f}", f"${recommended.mean_final_loan_balance:>12,.0f}", ""),
            ("  Equity Protection", f"{bl_50k.mean_borrower_equity_return:.1f}%", f"{recommended.mean_borrower_equity_return:.1f}%", ""),
        ]

        for label, v1, v2, chg in rows:
            if not label:
                print()
            elif not v1 and not v2:
                print(f"\n  {label}")
            else:
                print(f"  {label:40s}  {v1:>15s}  {v2:>15s}  {chg:>12s}")

        print(f"\n  ★ Recommended: {recommended.label}")
        print(f"    Borrower income: UNCHANGED at $250,000")

    # Save
    output = {
        'metadata': {
            'constraint': 'Annuity fixed at $25,000/yr × 10yr = $250,000 total',
            'phase1_scenarios': len(r1),
            'phase2_scenarios': len(r2),
            'phase3_scenarios': len(r50k),
            'phase1_paths': 10_000,
            'phase3_paths': 50_000,
            'seed': SEED,
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        },
        'baseline': asdict(bl_50k) if bl_50k else None,
        'recommended': asdict(recommended),
        'pareto_front_50k': [asdict(r) for r in pareto_50k],
        'all_50k_validated': [asdict(r) for r in sorted(r50k, key=lambda r: r._composite, reverse=True)],
    }

    # Clean
    for key in ['recommended', 'baseline']:
        if output.get(key):
            output[key].pop('_composite', None)
    for lst in ['pareto_front_50k', 'all_50k_validated']:
        for d in output.get(lst, []):
            d.pop('_composite', None)

    with open('optimisation_v14a_phase2_results.json', 'w') as f:
        json.dump(output, f, indent=2)
    print(f"\nResults saved to optimisation_v14a_phase2_results.json")
    print(f"Total scenarios: {len(r1) + len(r2) + len(r50k)}")


if __name__ == '__main__':
    main()
