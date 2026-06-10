#!/usr/bin/env python3
"""
EPM v14a CONSTRAINED Optimisation v2
======================================
Corrected constraints per feedback:

1. Collar ≤ ±20% (±35% too wide/costly)
2. FP margin ≥ 0.25% (commercial floor)
3. IO must deliver higher total annuity than PI
4. Total annuity is FIXED — longer terms divide same total over more years
5. PS period: 3yr or 5yr (5yr preferred for compounding)
6. PoC ≤ 5% (reinsurance) / ≤ 12% (LMI)

ANNUITY STRUCTURE (CRITICAL):
  Total annuity = rate × property value × 10yr base
  Both PI and IO: 1.25%–2.00% → $250K–$400K total on $2M (identical range)
  Initial loan = $1,600,000 − total annuity (dynamic)

  Longer terms SPREAD the same total:
    $250K over 10yr = $25,000/yr   (peak loan $1.60M, amortises over 20yr)
    $250K over 15yr = $16,667/yr   (peak loan $1.60M, amortises over 15yr)
    $250K over 20yr = $12,500/yr   (peak loan $1.60M, amortises over 10yr)
    $250K over 25yr = $10,000/yr   (peak loan $1.60M, amortises over 5yr)

  Peak loan is SAME for all terms. For PI, shorter payout = more amortisation years = better PoC.
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
GROSS_LOAN = int(HOME_VALUE * LVR)  # $1,600,000
# INITIAL_LOAN is now dynamic: GROSS_LOAN - total_annuity
# e.g. $1,600K - $250K = $1,350K; $1,600K - $400K = $1,200K
TENURE_YEARS = 30

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

# ============================================================
# CONSTRAINED RANGES
# ============================================================
# Collar: max ±20%
COLLAR_OPTIONS = [(1.10, 0.90), (1.15, 0.85), (1.20, 0.80)]  # ±10%, ±15%, ±20%

# FP margin: floor at 0.25%
FP_MARGIN_OPTIONS = [0.0025, 0.0030, 0.0035]  # 0.25%, 0.30%, 0.35%

# Holiday entry
HOLIDAY_OPTIONS = [0.90, 0.95, 1.00, 1.05]

# Profit share: 3yr or 5yr, various %
PS_OPTIONS = [(0.20, 3), (0.20, 5), (0.25, 3), (0.25, 5)]

# TOTAL annuity (FIXED — does not increase with term)
# Same range for both PI and IO — like-for-like comparison
ANNUITY_TOTALS = [250_000, 275_000, 300_000, 350_000, 400_000]  # 1.25%–2.00%
PI_TOTALS = ANNUITY_TOTALS
IO_TOTALS = ANNUITY_TOTALS

# Payout terms
TERMS = [10, 15, 20, 25]

# PoC thresholds
POC_REINSURANCE = 5.0
POC_LMI = 12.0


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
    loan_type: str
    annuity_pa: float
    annuity_term: int
    total_annuity: float
    initial_loan: float
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
    annuity_pa: float
    annuity_term: int
    total_annuity: float
    initial_loan: float
    annuity_pct: float
    profit_share_pct: float
    profit_share_years: int
    fp_margin: float
    retail_margin: float
    buffer_cap: float
    buffer_floor: float
    holiday_entry: float
    holiday_exit: float
    collar_price: float

    poc_yr30: float
    poc_yr20: float
    poc_yr15: float
    poc_yr10: float
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
    peak_loan: float

    revenue_per_unit_risk: float
    sharpe_like: float
    total_variable_cost_pct: float
    premium_as_pct_loan: float

    poc_by_year: list
    mean_surplus_by_year: list
    p10_by_year: list
    mean_investment_by_year: list
    mean_holidays_by_year: list
    mean_loan_by_year: list


def build_loan_trajectory(annuity_pa, annuity_term, loan_type, initial_loan):
    """Build loan trajectory. Total annuity = annuity_pa × annuity_term (FIXED)."""
    loan = np.zeros(TENURE_YEARS + 1)
    loan[0] = initial_loan
    for t in range(1, TENURE_YEARS + 1):
        if t <= annuity_term:
            loan[t] = loan[t-1] + annuity_pa
        else:
            loan[t] = loan[t-1]

    if loan_type == "PI":
        remaining = TENURE_YEARS - annuity_term
        if remaining > 0:
            peak = loan[annuity_term]
            annual_p = peak / remaining
            for t in range(annuity_term + 1, TENURE_YEARS + 1):
                loan[t] = max(loan[t-1] - annual_p, 0)
    return loan


def run_scenario(params, z1, z2):
    collar_price = estimate_collar_price(params.buffer_cap, params.buffer_floor)
    loan = build_loan_trajectory(params.annuity_pa, params.annuity_term, params.loan_type, params.initial_loan)
    max_loan = np.max(loan)
    peak_loan = float(max_loan)

    upfront_LMI = max_loan * LMI_UPFRONT_PCT
    upfront_reinsurance = max_loan * REINSURANCE_UPFRONT_PCT
    het = params.initial_loan * params.holiday_entry
    hxt = params.initial_loan * params.holiday_exit

    n = z1.shape[0]
    inv = np.full(n, params.initial_loan - upfront_LMI - upfront_reinsurance, dtype=np.float64)
    cr = np.full(n, CASH_RATE_INITIAL, dtype=np.float64)
    hf = np.zeros(n, dtype=bool)
    hc = np.zeros(n, dtype=np.float64)
    ha = np.zeros(n, dtype=np.float64)
    rs = np.zeros(n, dtype=np.float64)
    fi_t = np.zeros(n, dtype=np.float64)
    ic_t = np.zeros(n, dtype=np.float64)
    idef = np.zeros(n, dtype=np.float64)
    cum_ps = np.zeros(n)
    cum_fm = np.zeros(n)

    poc_by_year = []
    ms_by_year = []
    p10_by_year = []
    mi_by_year = [float(np.mean(inv))]
    mh_by_year = []
    ml_by_year = [float(loan[0])]
    worst_p1 = 0.0
    poc10 = poc15 = poc20 = 0.0

    inv *= (1 - collar_price)

    for t in range(1, TENURE_YEARS + 1):
        yi = t - 1
        cr = (cr * np.exp(-CASH_RATE_KAPPA) +
              CASH_RATE_THETA * (1 - np.exp(-CASH_RATE_KAPPA)) +
              CASH_RATE_SIGMA * z2[:, yi])
        cr = np.maximum(cr, 0)

        raw = np.exp(EQUITY_MEAN + EQUITY_VOL * z1[:, yi]) - 1
        hedged = np.clip(raw, params.buffer_floor - 1, params.buffer_cap - 1)

        ffc = WHOLESALE_MARGIN + cr
        al = (loan[t-1] + loan[t]) / 2
        fi = -ffc * al
        fi_t += fi

        phf = hf.copy(); phc = hc.copy()
        ent = (~phf) & (inv < het)
        ext = phf & (inv > hxt)
        sta = phf & (~ext)
        hf = ent | sta
        hc = np.where(hf, phc + 1, 0)
        mh_by_year.append(float(np.mean(hf)))

        rf = phf & (~hf)
        nr = np.where(rf & (rs <= 0), phc, 0)
        rs = np.where(nr > 0, nr, np.maximum(rs - 1, 0))

        hao = ha.copy()
        ih = np.where(hf, -fi, 0)
        rh = np.where(rs > 0, -hao / np.maximum(rs, 1), 0)
        ha = hao + ih + rh

        ic = fi + ih + rh
        ic_t += ic
        idef = fi_t - ic_t

        rn = -params.retail_margin * al
        fp = -params.fp_margin * inv
        hfee = -HEDGING_FEE * inv
        cum_fm += np.abs(fp)

        pp = 0.0
        if params.loan_type == "PI" and t > params.annuity_term:
            pd = loan[t-1] - loan[t]
            if pd > 0: pp = -pd

        if t == TENURE_YEARS:
            rn = -params.retail_margin * loan[t-1] / 2
            ic = -ffc * loan[t-1] / 2

        ir = inv * hedged
        inv = inv + ir + ic + rn + fp + hfee + pp

        surplus = inv - loan[t] + idef

        if t < TENURE_YEARS and t % params.profit_share_years == 0:
            ps = np.where(surplus > 0, surplus * params.profit_share_pct, 0)
            inv -= ps
            cum_ps += ps

        if t == TENURE_YEARS:
            wu = np.maximum(surplus, 0)
            inv -= wu

        if t < TENURE_YEARS:
            inv *= (1 - collar_price)

        dp = float(np.mean(surplus < 0) * 100)
        poc_by_year.append(dp)
        ms_by_year.append(float(np.mean(surplus)))
        p10_by_year.append(float(np.percentile(surplus, 10)))
        mi_by_year.append(float(np.mean(inv)))
        ml_by_year.append(float(loan[t]))
        p1y = float(np.percentile(surplus, 1))
        if p1y < worst_p1: worst_p1 = p1y
        if t == 10: poc10 = dp
        if t == 15: poc15 = dp
        if t == 20: poc20 = dp

    fs = surplus
    poc30 = float(np.mean(fs < 0) * 100)
    dm = fs < 0; nd = np.sum(dm)
    ced = float(np.mean(fs[dm])) if nd > 0 else 0.0
    disc = np.exp(-CASH_RATE_THETA * TENURE_YEARS)
    fpr = float(-np.mean(disc * fs[dm]) * (poc30 / 100)) if nd > 0 else 0.0
    mp = np.where(fs > 0, fs * 0.5, 0)
    beq = float((1 - poc30 / 100) * 100)
    ss = float(np.std(fs))
    tvc = params.retail_margin + params.fp_margin + HEDGING_FEE
    frev = float(np.mean(cum_ps) + np.mean(cum_fm))
    ann_pct = round(params.total_annuity / HOME_VALUE * 100, 3)

    return Result(
        label=params.label, loan_type=params.loan_type,
        annuity_pa=params.annuity_pa, annuity_term=params.annuity_term,
        total_annuity=params.total_annuity, initial_loan=params.initial_loan,
        annuity_pct=ann_pct,
        profit_share_pct=params.profit_share_pct,
        profit_share_years=params.profit_share_years,
        fp_margin=params.fp_margin, retail_margin=params.retail_margin,
        buffer_cap=params.buffer_cap, buffer_floor=params.buffer_floor,
        holiday_entry=params.holiday_entry, holiday_exit=params.holiday_exit,
        collar_price=round(collar_price, 6),
        poc_yr30=round(poc30, 2), poc_yr20=round(poc20, 2),
        poc_yr15=round(poc15, 2), poc_yr10=round(poc10, 2),
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
        fair_premium=round(fpr, 0), fair_premium_loaded=round(fpr * 1.5, 0),
        std_surplus=round(ss, 0), max_drawdown_p1=round(worst_p1, 0),
        mean_surplus_yr30=round(float(np.mean(fs)), 0),
        mean_total_profit_share=round(float(np.mean(cum_ps)), 0),
        mean_fp_margin_income=round(float(np.mean(cum_fm)), 0),
        mean_total_fp_revenue=round(frev, 0),
        mean_funder_surplus_share=round(float(np.mean(mp)), 0),
        mean_borrower_equity_return=round(beq, 1),
        mean_final_loan_balance=round(float(loan[TENURE_YEARS]), 0),
        peak_loan=round(peak_loan, 0),
        revenue_per_unit_risk=round(frev / max(poc30, 0.01), 0),
        sharpe_like=round(float(np.mean(fs)) / max(ss, 1), 4),
        total_variable_cost_pct=round(tvc * 100, 2),
        premium_as_pct_loan=round(fpr * 1.5 / max(peak_loan, 1) * 100, 3),
        poc_by_year=[round(x, 2) for x in poc_by_year],
        mean_surplus_by_year=[round(x, 0) for x in ms_by_year],
        p10_by_year=[round(x, 0) for x in p10_by_year],
        mean_investment_by_year=[round(x, 0) for x in mi_by_year],
        mean_holidays_by_year=[round(x, 3) for x in mh_by_year],
        mean_loan_by_year=[round(x, 0) for x in ml_by_year],
    )


# ============================================================
# BASELINE (unconstrained reference)
# ============================================================
BL_TOTAL = 250_000
BL_TERM = 10
BL_PA = BL_TOTAL // BL_TERM


def mkp(label, loan_type="IO", total=BL_TOTAL, term=BL_TERM, **kw):
    pa = total // term
    init_loan = GROSS_LOAN - total  # Dynamic: $1.6M - annuity total
    defaults = dict(
        profit_share_pct=0.25, profit_share_years=5,
        fp_margin=0.0025, retail_margin=0.007,
        buffer_cap=1.20, buffer_floor=0.80,
        holiday_entry=0.90, holiday_exit=1.458,
    )
    defaults.update(kw)
    return Params(label=label, loan_type=loan_type, annuity_pa=pa,
                  annuity_term=term, total_annuity=total,
                  initial_loan=init_loan, **defaults)


# ============================================================
# PHASE 1: INDIVIDUAL LEVER SWEEPS
# ============================================================
def build_phase1():
    s = []
    # Baseline
    s.append(mkp("v14a_BASELINE"))

    # ── TOTAL ANNUITY × TERM (fixed total, varying term) ──
    # PI: $250K, $275K, $300K total spread over 10/15/20/25yr
    for total in PI_TOTALS:
        pct = total / HOME_VALUE * 100
        for term in TERMS:
            pa = total // term
            s.append(mkp(f"PI_{pct:.2f}%_T=${total//1000}K_{term}yr_${pa//1000}K/yr",
                         loan_type="PI", total=total, term=term))

    # IO: $300K, $350K, $400K total spread over 10/15/20/25yr
    for total in IO_TOTALS:
        pct = total / HOME_VALUE * 100
        for term in TERMS:
            pa = total // term
            s.append(mkp(f"IO_{pct:.2f}%_T=${total//1000}K_{term}yr_${pa//1000}K/yr",
                         loan_type="IO", total=total, term=term))

    # ── COLLAR (at representative configs) ──
    for cap, floor in COLLAR_OPTIONS:
        cap_pct = int((cap - 1) * 100)
        # PI at $250K total, 10yr
        s.append(mkp(f"PI_$250K_10y_C±{cap_pct}%",
                     loan_type="PI", total=250_000, term=10,
                     buffer_cap=cap, buffer_floor=floor))
        # PI at $250K total, 20yr
        s.append(mkp(f"PI_$250K_20y_C±{cap_pct}%",
                     loan_type="PI", total=250_000, term=20,
                     buffer_cap=cap, buffer_floor=floor))
        # IO at $300K total, 10yr
        s.append(mkp(f"IO_$300K_10y_C±{cap_pct}%",
                     loan_type="IO", total=300_000, term=10,
                     buffer_cap=cap, buffer_floor=floor))

    # ── HOLIDAY ──
    for he in HOLIDAY_OPTIONS:
        hx = he * HOLIDAY_RATIO
        s.append(mkp(f"PI_$250K_10y_HE={he:.2f}",
                     loan_type="PI", total=250_000, term=10,
                     holiday_entry=he, holiday_exit=hx))
        s.append(mkp(f"PI_$250K_20y_HE={he:.2f}",
                     loan_type="PI", total=250_000, term=20,
                     holiday_entry=he, holiday_exit=hx))
        s.append(mkp(f"IO_$300K_10y_HE={he:.2f}",
                     loan_type="IO", total=300_000, term=10,
                     holiday_entry=he, holiday_exit=hx))

    # ── PS% and FREQUENCY ──
    for ps_pct, ps_yr in PS_OPTIONS:
        s.append(mkp(f"PI_$250K_10y_PS={ps_pct*100:.0f}%q{ps_yr}",
                     loan_type="PI", total=250_000, term=10,
                     profit_share_pct=ps_pct, profit_share_years=ps_yr))
        s.append(mkp(f"IO_$300K_10y_PS={ps_pct*100:.0f}%q{ps_yr}",
                     loan_type="IO", total=300_000, term=10,
                     profit_share_pct=ps_pct, profit_share_years=ps_yr))

    # ── FP MARGIN (floor = 0.25%) ──
    for fm in FP_MARGIN_OPTIONS:
        s.append(mkp(f"PI_$250K_10y_FM={fm*100:.2f}%",
                     loan_type="PI", total=250_000, term=10, fp_margin=fm))
        s.append(mkp(f"IO_$300K_10y_FM={fm*100:.2f}%",
                     loan_type="IO", total=300_000, term=10, fp_margin=fm))

    return s


# ============================================================
# PHASE 2: COMBINED GRID (all within constraints)
# ============================================================
def build_phase2():
    s = []

    for lt, totals in [("PI", PI_TOTALS), ("IO", IO_TOTALS)]:
        for total in totals:
            pct = total / HOME_VALUE * 100
            for term in TERMS:
                pa = total // term
                for cap, floor in COLLAR_OPTIONS:
                    cap_pct = int((cap - 1) * 100)
                    for he in HOLIDAY_OPTIONS:
                        hx = he * HOLIDAY_RATIO
                        for ps_pct, ps_yr in PS_OPTIONS:
                            for fm in FP_MARGIN_OPTIONS:
                                label = (f"{lt}_{pct:.2f}%_T${total//1000}K_{term}y_"
                                         f"C±{cap_pct}_HE={he:.2f}_"
                                         f"PS={ps_pct*100:.0f}q{ps_yr}_FM={fm*100:.1f}")
                                init_loan = GROSS_LOAN - total
                                s.append(Params(
                                    label=label, loan_type=lt,
                                    annuity_pa=pa, annuity_term=term,
                                    total_annuity=total,
                                    initial_loan=init_loan,
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
            if r2.mean_total_fp_revenue > r.mean_total_fp_revenue and r2.poc_yr30 < r.poc_yr30:
                dominated = True; break
        if not dominated:
            pareto.append(r)
    return sorted(pareto, key=lambda r: r.poc_yr30)


def ptbl(title, results, n=25):
    print(f"\n--- {title} ---")
    print(f"  {'#':>3}  {'Label':55s}  {'Type':>3}  {'Total':>8}  {'Term':>4}  "
          f"{'$/yr':>8}  {'PoC%':>6}  {'FP Rev':>12}  {'Sharpe':>7}  {'Surplus':>12}  {'Prem':>10}")
    print("  " + "-" * 155)
    for i, r in enumerate(results[:n]):
        print(f"  {i+1:3d}  {r.label:55s}  {r.loan_type:>3s}  ${r.total_annuity/1000:>5.0f}K  "
              f"{r.annuity_term:3d}y  ${r.annuity_pa:>6,.0f}  "
              f"{r.poc_yr30:5.1f}%  ${r.mean_total_fp_revenue:>11,.0f}  {r.sharpe_like:6.3f}  "
              f"${r.mean_surplus_yr30:>11,.0f}  ${r.fair_premium_loaded:>9,.0f}")


def main():
    print("=" * 80)
    print("EPM v14a CONSTRAINED OPTIMISATION v2")
    print("=" * 80)
    print(f"\nCONSTRAINTS (CORRECTED):")
    print(f"  Collar: ≤ ±20% (max)")
    print(f"  FP margin: ≥ 0.25% (floor)")
    print(f"  Total annuity (both PI & IO): $250K–$400K (1.25%–2.00% of $2M) — identical range for comparison")
    print(f"  Total annuity is FIXED — longer terms = lower annual draw")
    print(f"  PS period: 3yr or 5yr")
    print(f"  PoC targets: ≤{POC_REINSURANCE:.0f}% (reinsurance) | ≤{POC_LMI:.0f}% (LMI)")

    rng = np.random.default_rng(SEED)
    z1_10k = rng.standard_normal((10_000, TENURE_YEARS))
    z2r = rng.standard_normal((10_000, TENURE_YEARS))
    rho = CASH_RATE_EQUITY_CORR
    z2_10k = rho * z1_10k + np.sqrt(1 - rho**2) * z2r

    # ── PHASE 1 ──
    p1 = build_phase1()
    print(f"\nPhase 1: {len(p1)} scenarios × 10,000 paths")
    t0 = time.time()
    r1 = []
    for i, p in enumerate(p1):
        if (i+1) % 20 == 0 or i == 0:
            print(f"  [{i+1}/{len(p1)}] {p.label}")
        r1.append(run_scenario(p, z1_10k, z2_10k))
    print(f"  Done in {time.time()-t0:.1f}s")

    bl = next(r for r in r1 if r.label == "v14a_BASELINE")

    # ── ANNUITY ANALYSIS ──
    print(f"\n{'='*80}")
    print("FIXED TOTAL ANNUITY × PAYOUT TERM")
    print(f"{'='*80}")

    for lt, totals, label in [("PI", PI_TOTALS, "P&I"), ("IO", IO_TOTALS, "IO")]:
        print(f"\n  {label} MORTGAGES:")
        print(f"    {'Total':>8}  {'Rate':>5}  {'Term':>5}  {'$/yr':>8}  {'Peak Loan':>12}  {'PoC%':>6}  {'Surplus':>12}  {'Sharpe':>7}")
        for total in totals:
            pct = total / HOME_VALUE * 100
            for term in TERMS:
                pa = total // term
                r = next((r for r in r1 if r.loan_type == lt
                         and r.total_annuity == total and r.annuity_term == term
                         and "C±" not in r.label and "HE=" not in r.label
                         and "PS=" not in r.label and "FM=" not in r.label), None)
                if r:
                    tier = "✓RE" if r.poc_yr30 <= POC_REINSURANCE else ("✓LMI" if r.poc_yr30 <= POC_LMI else "✗")
                    print(f"    ${total/1000:>5.0f}K  {pct:4.2f}%  {term:4d}y  ${pa:>6,.0f}  "
                          f"${r.peak_loan:>11,.0f}  {r.poc_yr30:5.1f}%  "
                          f"${r.mean_surplus_yr30:>11,.0f}  {r.sharpe_like:6.3f}  {tier}")

    # ── LEVER ANALYSIS ──
    print(f"\n{'='*80}")
    print("LEVER IMPACT")
    print(f"{'='*80}")

    print(f"\n  COLLAR WIDTH (PI $250K×10yr):")
    for cap, floor in COLLAR_OPTIONS:
        cap_pct = int((cap - 1) * 100)
        r = next((r for r in r1 if r.label == f"PI_$250K_10y_C±{cap_pct}%"), None)
        if r:
            tier = "✓RE" if r.poc_yr30 <= POC_REINSURANCE else ("✓LMI" if r.poc_yr30 <= POC_LMI else "✗")
            print(f"    ±{cap_pct}%: PoC={r.poc_yr30:5.1f}%  Surplus=${r.mean_surplus_yr30:>11,.0f}  "
                  f"Sharpe={r.sharpe_like:.3f}  {tier}")

    print(f"\n  COLLAR WIDTH (PI $250K×20yr):")
    for cap, floor in COLLAR_OPTIONS:
        cap_pct = int((cap - 1) * 100)
        r = next((r for r in r1 if r.label == f"PI_$250K_20y_C±{cap_pct}%"), None)
        if r:
            tier = "✓RE" if r.poc_yr30 <= POC_REINSURANCE else ("✓LMI" if r.poc_yr30 <= POC_LMI else "✗")
            print(f"    ±{cap_pct}%: PoC={r.poc_yr30:5.1f}%  Surplus=${r.mean_surplus_yr30:>11,.0f}  "
                  f"Sharpe={r.sharpe_like:.3f}  {tier}")

    print(f"\n  HOLIDAY ENTRY (PI $250K×10yr):")
    for he in HOLIDAY_OPTIONS:
        r = next((r for r in r1 if r.label == f"PI_$250K_10y_HE={he:.2f}"), None)
        if r:
            tier = "✓RE" if r.poc_yr30 <= POC_REINSURANCE else ("✓LMI" if r.poc_yr30 <= POC_LMI else "✗")
            print(f"    HE={he:.2f}: PoC={r.poc_yr30:5.1f}%  Surplus=${r.mean_surplus_yr30:>11,.0f}  "
                  f"Sharpe={r.sharpe_like:.3f}  {tier}")

    print(f"\n  HOLIDAY ENTRY (PI $250K×20yr):")
    for he in HOLIDAY_OPTIONS:
        r = next((r for r in r1 if r.label == f"PI_$250K_20y_HE={he:.2f}"), None)
        if r:
            tier = "✓RE" if r.poc_yr30 <= POC_REINSURANCE else ("✓LMI" if r.poc_yr30 <= POC_LMI else "✗")
            print(f"    HE={he:.2f}: PoC={r.poc_yr30:5.1f}%  Surplus=${r.mean_surplus_yr30:>11,.0f}  "
                  f"Sharpe={r.sharpe_like:.3f}  {tier}")

    print(f"\n  PROFIT SHARE:")
    for ps_pct, ps_yr in PS_OPTIONS:
        r_pi = next((r for r in r1 if r.label == f"PI_$250K_10y_PS={ps_pct*100:.0f}%q{ps_yr}"), None)
        r_io = next((r for r in r1 if r.label == f"IO_$300K_10y_PS={ps_pct*100:.0f}%q{ps_yr}"), None)
        if r_pi:
            print(f"    PI {ps_pct*100:.0f}% q{ps_yr}: PoC={r_pi.poc_yr30:5.1f}%  "
                  f"Rev=${r_pi.mean_total_fp_revenue:>11,.0f}  Sharpe={r_pi.sharpe_like:.3f}")
        if r_io:
            print(f"    IO {ps_pct*100:.0f}% q{ps_yr}: PoC={r_io.poc_yr30:5.1f}%  "
                  f"Rev=${r_io.mean_total_fp_revenue:>11,.0f}  Sharpe={r_io.sharpe_like:.3f}")

    # ── PHASE 2: COMBINED ──
    p2 = build_phase2()
    print(f"\n\n{'='*80}")
    print(f"PHASE 2: COMBINED GRID — {len(p2)} scenarios × 10,000 paths")
    print(f"{'='*80}")

    t1_time = time.time()
    r2 = []
    for i, p in enumerate(p2):
        if (i+1) % 500 == 0 or i == 0:
            print(f"  [{i+1}/{len(p2)}] {p.label}")
        r2.append(run_scenario(p, z1_10k, z2_10k))
    print(f"  Done in {time.time()-t1_time:.1f}s")

    all_r = r1 + r2
    for r in all_r:
        r._composite = r.revenue_per_unit_risk * r.sharpe_like

    # Filter: exclude baseline from ranking, keep only constrained configs
    ranked = [r for r in all_r if r.label != "v14a_BASELINE"]

    # Tier 1: Reinsurance (PoC ≤ 5%)
    tier1 = sorted([r for r in ranked if r.poc_yr30 <= POC_REINSURANCE],
                   key=lambda r: r._composite, reverse=True)
    # Tier 2: LMI (PoC ≤ 12%)
    tier2 = sorted([r for r in ranked if r.poc_yr30 <= POC_LMI],
                   key=lambda r: r._composite, reverse=True)

    print(f"\n  TIER 1 — Reinsurance (PoC ≤ {POC_REINSURANCE:.0f}%): {len(tier1)} scenarios")
    print(f"  TIER 2 — LMI (PoC ≤ {POC_LMI:.0f}%): {len(tier2)} scenarios")

    if tier1:
        ptbl(f"TIER 1 — REINSURANCE (PoC ≤ {POC_REINSURANCE:.0f}%) — Top 25", tier1)
    if tier2:
        ptbl(f"TIER 2 — LMI (PoC ≤ {POC_LMI:.0f}%) — Top 25", tier2)

    # Best by payout duration
    print(f"\n{'='*80}")
    print("BEST BY PAYOUT DURATION (10K screening)")
    print(f"{'='*80}")

    for tier_label, tier_data in [("REINSURANCE (PoC ≤ 5%)", tier1), ("LMI (PoC ≤ 12%)", tier2)]:
        print(f"\n  {tier_label}:")
        for min_term in [10, 15, 20, 25]:
            filt = sorted([r for r in tier_data if r.annuity_term >= min_term],
                          key=lambda r: r._composite, reverse=True)
            if filt:
                r = filt[0]
                pa = r.annuity_pa
                print(f"    ≥{min_term}yr: {r.label}")
                print(f"      Total=${r.total_annuity:,.0f} over {r.annuity_term}yr = ${pa:,.0f}/yr | "
                      f"PoC={r.poc_yr30:.1f}% | Rev=${r.mean_total_fp_revenue:,.0f} | Sharpe={r.sharpe_like:.3f}")
            else:
                print(f"    ≥{min_term}yr: No feasible configuration")

    # ── PHASE 3: 50K VALIDATION ──
    candidates = set(["v14a_BASELINE"])
    for r in tier1[:20]: candidates.add(r.label)
    for r in tier2[:15]: candidates.add(r.label)

    # Pareto fronts
    pareto_t1 = find_pareto(tier1) if tier1 else []
    pareto_t2 = find_pareto(tier2) if tier2 else []
    for r in pareto_t1: candidates.add(r.label)
    for r in pareto_t2: candidates.add(r.label)

    # Best from each duration bucket
    for tier_data in [tier1, tier2]:
        for min_term in [10, 15, 20, 25]:
            filt = sorted([r for r in tier_data if r.annuity_term >= min_term],
                          key=lambda r: r._composite, reverse=True)
            for r in filt[:3]:
                candidates.add(r.label)

    all_params = {p.label: p for p in p1 + p2}
    val_labels = [l for l in candidates if l in all_params]

    print(f"\n\n{'='*80}")
    print(f"PHASE 3: 50,000-PATH VALIDATION — {len(val_labels)} candidates")
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

    bl_50k = next((r for r in r50k if r.label == "v14a_BASELINE"), None)

    # Re-tier at 50K
    t1_50k = sorted([r for r in r50k if r.poc_yr30 <= POC_REINSURANCE and r.label != "v14a_BASELINE"],
                    key=lambda r: r._composite, reverse=True)
    t2_50k = sorted([r for r in r50k if r.poc_yr30 <= POC_LMI and r.label != "v14a_BASELINE"],
                    key=lambda r: r._composite, reverse=True)

    if t1_50k:
        ptbl(f"TIER 1 — REINSURANCE (PoC ≤ {POC_REINSURANCE:.0f}%) — 50K VALIDATED", t1_50k)
    if t2_50k:
        ptbl(f"TIER 2 — LMI (PoC ≤ {POC_LMI:.0f}%) — 50K VALIDATED", t2_50k)

    # ── FINAL RESULTS ──
    rec_re = t1_50k[0] if t1_50k else None
    rec_lmi = t2_50k[0] if t2_50k else None

    print(f"\n\n{'='*80}")
    print("FINAL RECOMMENDED (50K validated)")
    print(f"{'='*80}")

    for tier_label, rec in [("REINSURANCE (PoC ≤ 5%)", rec_re), ("LMI (PoC ≤ 12%)", rec_lmi)]:
        if not rec or not bl_50k:
            print(f"\n  {tier_label}: No feasible configuration")
            continue
        print(f"\n  {tier_label}: {rec.label}")
        print(f"  {'Metric':40s}  {'v14a Baseline':>15s}  {'Recommended':>15s}  {'Change':>12s}")
        print("  " + "-" * 90)
        rows = [
            ("Total Annuity", f"${bl_50k.total_annuity:>12,.0f}", f"${rec.total_annuity:>12,.0f}", "FIXED TOTAL"),
            ("Payout Term", f"{bl_50k.annuity_term}yr", f"{rec.annuity_term}yr", ""),
            ("Annual Draw", f"${bl_50k.annuity_pa:>12,.0f}", f"${rec.annuity_pa:>12,.0f}", ""),
            ("Loan Type", bl_50k.loan_type, rec.loan_type, ""),
            ("Collar", f"±{(bl_50k.buffer_cap-1)*100:.0f}%", f"±{(rec.buffer_cap-1)*100:.0f}%", ""),
            ("Holiday Entry", f"{bl_50k.holiday_entry:.2f}", f"{rec.holiday_entry:.2f}", ""),
            ("PS Config", f"{bl_50k.profit_share_pct*100:.0f}% q{bl_50k.profit_share_years}",
             f"{rec.profit_share_pct*100:.0f}% q{rec.profit_share_years}", ""),
            ("FP Margin", f"{bl_50k.fp_margin*100:.2f}%", f"{rec.fp_margin*100:.2f}%", ""),
            ("", "", "", ""),
            ("PoC Year 30", f"{bl_50k.poc_yr30:.1f}%", f"{rec.poc_yr30:.1f}%",
             f"{rec.poc_yr30 - bl_50k.poc_yr30:+.1f}pp"),
            ("Mean Surplus", f"${bl_50k.mean_surplus_yr30:>12,.0f}", f"${rec.mean_surplus_yr30:>12,.0f}",
             f"+{(rec.mean_surplus_yr30/bl_50k.mean_surplus_yr30 - 1)*100:.0f}%" if bl_50k.mean_surplus_yr30 > 0 else ""),
            ("Sharpe", f"{bl_50k.sharpe_like:.3f}", f"{rec.sharpe_like:.3f}", ""),
            ("FP Revenue", f"${bl_50k.mean_total_fp_revenue:>12,.0f}", f"${rec.mean_total_fp_revenue:>12,.0f}",
             f"+{(rec.mean_total_fp_revenue/bl_50k.mean_total_fp_revenue - 1)*100:.0f}%"),
            ("Premium", f"${bl_50k.fair_premium_loaded:>12,.0f}", f"${rec.fair_premium_loaded:>12,.0f}",
             f"{(rec.fair_premium_loaded/bl_50k.fair_premium_loaded - 1)*100:+.0f}%"),
            ("Final Loan", f"${bl_50k.mean_final_loan_balance:>12,.0f}",
             f"${rec.mean_final_loan_balance:>12,.0f}", ""),
            ("Protection", f"{bl_50k.mean_borrower_equity_return:.1f}%",
             f"{rec.mean_borrower_equity_return:.1f}%", ""),
        ]
        for lbl, v1, v2, chg in rows:
            if not lbl:
                print()
            else:
                print(f"  {lbl:40s}  {v1:>15s}  {v2:>15s}  {chg:>12s}")

    # Best by duration at 50K
    print(f"\n{'='*80}")
    print("BEST BY PAYOUT DURATION — 50K VALIDATED")
    print(f"{'='*80}")
    for tier_label, tier_data in [("REINSURANCE (PoC ≤ 5%)", t1_50k), ("LMI (PoC ≤ 12%)", t2_50k)]:
        print(f"\n  {tier_label}:")
        for min_term in [10, 15, 20, 25]:
            filt = sorted([r for r in tier_data if r.annuity_term >= min_term],
                          key=lambda r: r._composite, reverse=True)
            if filt:
                r = filt[0]
                print(f"    ≥{min_term}yr: {r.label}")
                print(f"      Total=${r.total_annuity:,.0f} / {r.annuity_term}yr = ${r.annuity_pa:,.0f}/yr | "
                      f"PoC={r.poc_yr30:.1f}% | Rev=${r.mean_total_fp_revenue:,.0f} | Sharpe={r.sharpe_like:.3f}")
            else:
                print(f"    ≥{min_term}yr: No feasible configuration")

    # ── Save ──
    output = {
        'metadata': {
            'description': 'Constrained optimisation v2: corrected collar/margin/annuity constraints',
            'constraints': {
                'collar_max': '±20%',
                'fp_margin_min': '0.25%',
                'annuity_totals': '$250K–$400K (1.25%–2.00% of $2M) — same for PI and IO',
                'initial_loan': 'Dynamic: $1,600,000 − total annuity',
                'total_annuity_fixed': True,
                'ps_periods': '3yr or 5yr',
                'poc_reinsurance': POC_REINSURANCE,
                'poc_lmi': POC_LMI,
                'property_value': HOME_VALUE,
            },
            'phase1_scenarios': len(r1),
            'phase2_scenarios': len(r2),
            'phase3_scenarios': len(r50k),
            'phase1_paths': 10_000,
            'phase3_paths': 50_000,
            'tier1_count_50k': len(t1_50k),
            'tier2_count_50k': len(t2_50k),
            'seed': SEED,
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        },
        'baseline': asdict(bl_50k) if bl_50k else None,
        'recommended_reinsurance': asdict(rec_re) if rec_re else None,
        'recommended_lmi': asdict(rec_lmi) if rec_lmi else None,
        'tier1_reinsurance_50k': [asdict(r) for r in t1_50k],
        'tier2_lmi_50k': [asdict(r) for r in t2_50k],
        'pareto_reinsurance_50k': [asdict(r) for r in find_pareto(t1_50k)] if t1_50k else [],
        'pareto_lmi_50k': [asdict(r) for r in find_pareto(t2_50k)] if t2_50k else [],
        'all_50k_validated': [asdict(r) for r in sorted(r50k, key=lambda r: r._composite, reverse=True)],
    }

    # Best by duration
    output['best_by_duration'] = {}
    for tier_key, tier_data in [('reinsurance', t1_50k), ('lmi', t2_50k)]:
        output['best_by_duration'][tier_key] = {}
        for min_term in [10, 15, 20, 25]:
            filt = sorted([r for r in tier_data if r.annuity_term >= min_term],
                          key=lambda r: r._composite, reverse=True)
            if filt:
                output['best_by_duration'][tier_key][f'min_{min_term}yr'] = asdict(filt[0])

    # Clean
    def clean(d):
        if isinstance(d, dict): d.pop('_composite', None)
    for k in ['recommended_reinsurance', 'recommended_lmi', 'baseline']:
        if output.get(k): clean(output[k])
    for k in ['tier1_reinsurance_50k', 'tier2_lmi_50k', 'pareto_reinsurance_50k',
              'pareto_lmi_50k', 'all_50k_validated']:
        for d in output.get(k, []): clean(d)
    for tier_data in output.get('best_by_duration', {}).values():
        for v in tier_data.values():
            clean(v)

    with open('optimisation_v14a_constrained_v2_results.json', 'w') as f:
        json.dump(output, f, indent=2)
    print(f"\n\nResults saved to optimisation_v14a_constrained_v2_results.json")
    print(f"Total scenarios: {len(r1) + len(r2) + len(r50k)}")


if __name__ == '__main__':
    main()
