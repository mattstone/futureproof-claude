#!/usr/bin/env python3
"""
EPM v14a CONSTRAINED Optimisation
==================================
Optimises all parameters subject to two hard constraints:

CONSTRAINT 1 — Annuity Rate (% of property value per annum):
  P&I loans:  1.25% – 1.50%  ($25,000 – $30,000/yr on $2M property)
  IO  loans:  1.50% – 2.00%  ($30,000 – $40,000/yr on $2M property)
  Annuity period varies (10–25yr) but annual rate stays in range.

CONSTRAINT 2 — Probability of Claim (PoC):
  Individual LMI:       PoC ≤ 10–12%
  Portfolio reinsurance: PoC ≤ ~5%

Results are reported in two tiers:
  TIER 1 "Reinsurance grade":  PoC ≤ 5%
  TIER 2 "LMI grade":         PoC ≤ 12%
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
# ANNUITY CONSTRAINTS (% of property value p.a.)
# ============================================================
PI_ANNUITY_MIN_PCT = 0.0125   # 1.25%
PI_ANNUITY_MAX_PCT = 0.0150   # 1.50%
IO_ANNUITY_MIN_PCT = 0.0150   # 1.50%
IO_ANNUITY_MAX_PCT = 0.0200   # 2.00%

PI_ANNUITY_MIN = int(HOME_VALUE * PI_ANNUITY_MIN_PCT)  # $25,000
PI_ANNUITY_MAX = int(HOME_VALUE * PI_ANNUITY_MAX_PCT)  # $30,000
IO_ANNUITY_MIN = int(HOME_VALUE * IO_ANNUITY_MIN_PCT)  # $30,000
IO_ANNUITY_MAX = int(HOME_VALUE * IO_ANNUITY_MAX_PCT)  # $40,000

# ============================================================
# POC CONSTRAINTS
# ============================================================
POC_REINSURANCE = 5.0    # ≤5% for portfolio reinsurance
POC_LMI = 12.0           # ≤12% for individual LMI


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
    peak_loan: float

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


def build_loan_trajectory(annuity_pa, annuity_term, loan_type):
    loan = np.zeros(TENURE_YEARS + 1)
    loan[0] = INITIAL_LOAN
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
    loan = build_loan_trajectory(params.annuity_pa, params.annuity_term, params.loan_type)
    max_loan = np.max(loan)
    peak_loan = float(max_loan)

    upfront_LMI = max_loan * LMI_UPFRONT_PCT
    upfront_reinsurance = max_loan * REINSURANCE_UPFRONT_PCT
    het = INITIAL_LOAN * params.holiday_entry
    hxt = INITIAL_LOAN * params.holiday_exit

    n = z1.shape[0]
    inv = np.full(n, INITIAL_LOAN - upfront_LMI - upfront_reinsurance, dtype=np.float64)
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

    pod_by_year = []
    ms_by_year = []
    p10_by_year = []
    mi_by_year = [float(np.mean(inv))]
    mh_by_year = []
    ml_by_year = [float(loan[0])]
    worst_p1 = 0.0
    pod10 = pod15 = pod20 = 0.0

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
        pod_by_year.append(dp)
        ms_by_year.append(float(np.mean(surplus)))
        p10_by_year.append(float(np.percentile(surplus, 10)))
        mi_by_year.append(float(np.mean(inv)))
        ml_by_year.append(float(loan[t]))
        p1y = float(np.percentile(surplus, 1))
        if p1y < worst_p1: worst_p1 = p1y
        if t == 10: pod10 = dp
        if t == 15: pod15 = dp
        if t == 20: pod20 = dp

    fs = surplus
    pod30 = float(np.mean(fs < 0) * 100)
    dm = fs < 0; nd = np.sum(dm)
    ced = float(np.mean(fs[dm])) if nd > 0 else 0.0
    disc = np.exp(-CASH_RATE_THETA * TENURE_YEARS)
    fpr = float(-np.mean(disc * fs[dm]) * (pod30 / 100)) if nd > 0 else 0.0
    mp = np.where(fs > 0, fs * 0.5, 0)
    beq = float((1 - pod30 / 100) * 100)
    ss = float(np.std(fs))
    tvc = params.retail_margin + params.fp_margin + HEDGING_FEE
    frev = float(np.mean(cum_ps) + np.mean(cum_fm))
    ta = params.annuity_pa * params.annuity_term
    ann_pct = round(params.annuity_pa / HOME_VALUE * 100, 3)

    return Result(
        label=params.label, loan_type=params.loan_type,
        annuity_pa=params.annuity_pa, annuity_term=params.annuity_term,
        total_annuity=ta, annuity_pct=ann_pct,
        profit_share_pct=params.profit_share_pct,
        profit_share_years=params.profit_share_years,
        fp_margin=params.fp_margin, retail_margin=params.retail_margin,
        buffer_cap=params.buffer_cap, buffer_floor=params.buffer_floor,
        holiday_entry=params.holiday_entry, holiday_exit=params.holiday_exit,
        collar_price=round(collar_price, 6),
        pod_yr30=round(pod30, 2), pod_yr20=round(pod20, 2),
        pod_yr15=round(pod15, 2), pod_yr10=round(pod10, 2),
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
        revenue_per_unit_risk=round(frev / max(pod30, 0.01), 0),
        sharpe_like=round(float(np.mean(fs)) / max(ss, 1), 4),
        total_variable_cost_pct=round(tvc * 100, 2),
        premium_as_pct_loan=round(fpr * 1.5 / max(peak_loan, 1) * 100, 3),
        pod_by_year=[round(x, 2) for x in pod_by_year],
        mean_surplus_by_year=[round(x, 0) for x in ms_by_year],
        p10_by_year=[round(x, 0) for x in p10_by_year],
        mean_investment_by_year=[round(x, 0) for x in mi_by_year],
        mean_holidays_by_year=[round(x, 3) for x in mh_by_year],
        mean_loan_by_year=[round(x, 0) for x in ml_by_year],
    )


# ============================================================
# BASELINE
# ============================================================
BL = dict(
    loan_type="IO", annuity_pa=25_000, annuity_term=10,
    profit_share_pct=0.25, profit_share_years=5,
    fp_margin=0.0025, retail_margin=0.007,
    buffer_cap=1.20, buffer_floor=0.80,
    holiday_entry=0.90, holiday_exit=1.458,
)


def mkp(label, **kw):
    p = dict(BL); p.update(kw)
    return Params(label=label, **p)


def annuity_in_range(loan_type, annuity_pa):
    """Check if annuity is within the constrained range."""
    if loan_type == "PI":
        return PI_ANNUITY_MIN <= annuity_pa <= PI_ANNUITY_MAX
    else:
        return IO_ANNUITY_MIN <= annuity_pa <= IO_ANNUITY_MAX


# ============================================================
# PHASE 1: INDIVIDUAL LEVER SWEEPS (within constraints)
# ============================================================
def build_phase1():
    s = []
    # Baseline (unconstrained reference point)
    s.append(mkp("v14a_BASELINE"))

    # ── ANNUITY within constrained ranges ──
    # P&I: $25K–$30K/yr (1.25%–1.50%)
    for pa in [25_000, 27_500, 30_000]:
        for term in [10, 15, 20, 25]:
            total = pa * term
            pct = pa / HOME_VALUE * 100
            s.append(mkp(f"PI_{pct:.2f}%_${pa//1000}K×{term}yr=${total//1000}K",
                         loan_type="PI", annuity_pa=pa, annuity_term=term))

    # IO: $30K–$40K/yr (1.50%–2.00%)
    for pa in [30_000, 35_000, 40_000]:
        for term in [10, 15, 20, 25]:
            total = pa * term
            pct = pa / HOME_VALUE * 100
            s.append(mkp(f"IO_{pct:.2f}%_${pa//1000}K×{term}yr=${total//1000}K",
                         loan_type="IO", annuity_pa=pa, annuity_term=term))

    # ── COLLAR (at constrained annuity levels) ──
    for cap_pct in [20, 25, 30, 35, 40]:
        cap = 1 + cap_pct / 100; floor = 2 - cap
        # PI at 1.25% ($25K) and 1.50% ($30K)
        for pa, pct_lbl in [(25_000, "1.25%"), (30_000, "1.50%")]:
            s.append(mkp(f"PI_{pct_lbl}_C±{cap_pct}%",
                         loan_type="PI", annuity_pa=pa, buffer_cap=cap, buffer_floor=floor))
        # IO at 1.50% ($30K) and 2.00% ($40K)
        for pa, pct_lbl in [(30_000, "1.50%"), (40_000, "2.00%")]:
            s.append(mkp(f"IO_{pct_lbl}_C±{cap_pct}%",
                         loan_type="IO", annuity_pa=pa, buffer_cap=cap, buffer_floor=floor))

    # ── HOLIDAY (at constrained annuity levels) ──
    for entry in [0.90, 0.95, 1.00, 1.05]:
        ex = entry * HOLIDAY_RATIO
        for lt, pa, pct_lbl in [("PI", 25_000, "1.25%"), ("PI", 30_000, "1.50%"),
                                 ("IO", 30_000, "1.50%"), ("IO", 40_000, "2.00%")]:
            s.append(mkp(f"{lt}_{pct_lbl}_HE={entry:.2f}",
                         loan_type=lt, annuity_pa=pa, holiday_entry=entry, holiday_exit=ex))

    # ── PS% and FREQUENCY ──
    for ps in [0.15, 0.20, 0.25, 0.30]:
        for freq in [3, 5]:
            for lt, pa, pct_lbl in [("PI", 25_000, "1.25%"), ("IO", 30_000, "1.50%")]:
                s.append(mkp(f"{lt}_{pct_lbl}_PS={ps*100:.0f}%q{freq}",
                             loan_type=lt, annuity_pa=pa,
                             profit_share_pct=ps, profit_share_years=freq))

    # ── FP MARGIN ──
    for fm in [0.0010, 0.0015, 0.0020, 0.0025]:
        for lt, pa, pct_lbl in [("PI", 25_000, "1.25%"), ("IO", 30_000, "1.50%")]:
            s.append(mkp(f"{lt}_{pct_lbl}_FM={fm*100:.2f}%",
                         loan_type=lt, annuity_pa=pa, fp_margin=fm))

    return s


# ============================================================
# PHASE 2: COMBINED GRID (constrained annuity ranges)
# ============================================================
def build_phase2():
    s = []

    collars = [(1.25, 0.75), (1.30, 0.70), (1.35, 0.65)]
    holidays = [0.95, 1.00, 1.05]
    ps_configs = [(0.25, 5), (0.25, 3), (0.20, 3), (0.20, 5)]
    fp_margins = [0.0010, 0.0015, 0.0020]

    # P&I annuity configs: 1.25%–1.50%
    pi_annuities = [
        (25_000, 10), (25_000, 15), (25_000, 20), (25_000, 25),
        (27_500, 10), (27_500, 15), (27_500, 20),
        (30_000, 10), (30_000, 15), (30_000, 20),
    ]

    # IO annuity configs: 1.50%–2.00%
    io_annuities = [
        (30_000, 10), (30_000, 15), (30_000, 20), (30_000, 25),
        (35_000, 10), (35_000, 15), (35_000, 20),
        (40_000, 10), (40_000, 15), (40_000, 20),
    ]

    for lt, annuity_configs in [("PI", pi_annuities), ("IO", io_annuities)]:
        for cap, floor in collars:
            for he in holidays:
                hx = he * HOLIDAY_RATIO
                for ann_pa, ann_term in annuity_configs:
                    for ps_pct, ps_yr in ps_configs:
                        for fm in fp_margins:
                            pct = ann_pa / HOME_VALUE * 100
                            total = ann_pa * ann_term
                            label = (f"{lt}_{pct:.2f}%_${ann_pa//1000}K×{ann_term}y_"
                                     f"C±{(cap-1)*100:.0f}_HE={he:.2f}_"
                                     f"PS={ps_pct*100:.0f}q{ps_yr}_FM={fm*100:.1f}")
                            s.append(Params(
                                label=label, loan_type=lt,
                                annuity_pa=ann_pa, annuity_term=ann_term,
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
            if r2.mean_total_fp_revenue > r.mean_total_fp_revenue and r2.pod_yr30 < r.pod_yr30:
                dominated = True; break
        if not dominated:
            pareto.append(r)
    return sorted(pareto, key=lambda r: r.pod_yr30)


def ptbl(title, results, n=25):
    print(f"\n--- {title} ---")
    print(f"  {'#':>3}  {'Label':55s}  {'Type':>3}  {'Ann%':>5}  {'Payout':>14}  "
          f"{'PoC%':>6}  {'FP Rev':>12}  {'Sharpe':>7}  {'Surplus':>12}  {'Prem':>10}")
    print("  " + "-" * 160)
    for i, r in enumerate(results[:n]):
        ann = f"${r.annuity_pa/1000:.0f}K×{r.annuity_term}y=${r.total_annuity/1000:.0f}K"
        print(f"  {i+1:3d}  {r.label:55s}  {r.loan_type:>3s}  {r.annuity_pct:4.2f}%  {ann:>14s}  "
              f"{r.pod_yr30:5.1f}%  ${r.mean_total_fp_revenue:>11,.0f}  {r.sharpe_like:6.3f}  "
              f"${r.mean_surplus_yr30:>11,.0f}  ${r.fair_premium_loaded:>9,.0f}")


def main():
    print("=" * 80)
    print("EPM v14a CONSTRAINED OPTIMISATION")
    print("=" * 80)
    print(f"\nCONSTRAINTS:")
    print(f"  P&I annuity: {PI_ANNUITY_MIN_PCT*100:.2f}%–{PI_ANNUITY_MAX_PCT*100:.2f}% "
          f"(${PI_ANNUITY_MIN:,}–${PI_ANNUITY_MAX:,}/yr on ${HOME_VALUE:,} property)")
    print(f"  IO  annuity: {IO_ANNUITY_MIN_PCT*100:.2f}%–{IO_ANNUITY_MAX_PCT*100:.2f}% "
          f"(${IO_ANNUITY_MIN:,}–${IO_ANNUITY_MAX:,}/yr on ${HOME_VALUE:,} property)")
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
        if (i+1) % 30 == 0 or i == 0:
            print(f"  [{i+1}/{len(p1)}] {p.label}")
        r1.append(run_scenario(p, z1_10k, z2_10k))
    print(f"  Done in {time.time()-t0:.1f}s")

    bl = next(r for r in r1 if r.label == "v14a_BASELINE")

    # ── ANNUITY ANALYSIS ──
    print(f"\n{'='*80}")
    print("ANNUITY RATE ANALYSIS (within constraints)")
    print(f"{'='*80}")

    print(f"\n  P&I MORTGAGES (1.25%–1.50% = $25K–$30K/yr):")
    print(f"    {'Config':45s}  {'Ann%':>5}  {'Term':>5}  {'Total':>10}  {'Peak Loan':>12}  {'PoC%':>6}  {'Surplus':>12}  {'Sharpe':>7}")
    for r in sorted([r for r in r1 if r.loan_type == "PI" and "C±" not in r.label
                     and "HE=" not in r.label and "PS=" not in r.label and "FM=" not in r.label
                     and r.label != "v14a_BASELINE"],
                    key=lambda r: (r.annuity_pa, r.annuity_term)):
        tier = "✓RE" if r.pod_yr30 <= POC_REINSURANCE else ("✓LMI" if r.pod_yr30 <= POC_LMI else "✗")
        print(f"    {r.label:45s}  {r.annuity_pct:4.2f}%  {r.annuity_term:4d}y  ${r.total_annuity:>8,.0f}  "
              f"${r.peak_loan:>11,.0f}  {r.pod_yr30:5.1f}%  ${r.mean_surplus_yr30:>11,.0f}  {r.sharpe_like:6.3f}  {tier}")

    print(f"\n  IO MORTGAGES (1.50%–2.00% = $30K–$40K/yr):")
    print(f"    {'Config':45s}  {'Ann%':>5}  {'Term':>5}  {'Total':>10}  {'Peak Loan':>12}  {'PoC%':>6}  {'Surplus':>12}  {'Sharpe':>7}")
    for r in sorted([r for r in r1 if r.loan_type == "IO" and "C±" not in r.label
                     and "HE=" not in r.label and "PS=" not in r.label and "FM=" not in r.label
                     and r.label != "v14a_BASELINE"],
                    key=lambda r: (r.annuity_pa, r.annuity_term)):
        tier = "✓RE" if r.pod_yr30 <= POC_REINSURANCE else ("✓LMI" if r.pod_yr30 <= POC_LMI else "✗")
        print(f"    {r.label:45s}  {r.annuity_pct:4.2f}%  {r.annuity_term:4d}y  ${r.total_annuity:>8,.0f}  "
              f"${r.peak_loan:>11,.0f}  {r.pod_yr30:5.1f}%  ${r.mean_surplus_yr30:>11,.0f}  {r.sharpe_like:6.3f}  {tier}")

    # ── OTHER LEVERS ──
    print(f"\n{'='*80}")
    print("LEVER IMPACT AT CONSTRAINED ANNUITY LEVELS")
    print(f"{'='*80}")

    # Collar impact
    print(f"\n  COLLAR WIDTH:")
    for cap_pct in [20, 25, 30, 35, 40]:
        results_at_collar = [r for r in r1 if f"C±{cap_pct}%" in r.label]
        for r in sorted(results_at_collar, key=lambda x: x.label):
            tier = "✓RE" if r.pod_yr30 <= POC_REINSURANCE else ("✓LMI" if r.pod_yr30 <= POC_LMI else "✗")
            print(f"    {r.label:40s}  PoC={r.pod_yr30:5.1f}%  Surplus=${r.mean_surplus_yr30:>11,.0f}  "
                  f"Sharpe={r.sharpe_like:.3f}  {tier}")

    # Holiday impact
    print(f"\n  HOLIDAY ENTRY:")
    for entry in [0.90, 0.95, 1.00, 1.05]:
        results_at_he = [r for r in r1 if f"HE={entry:.2f}" in r.label]
        for r in sorted(results_at_he, key=lambda x: x.label):
            tier = "✓RE" if r.pod_yr30 <= POC_REINSURANCE else ("✓LMI" if r.pod_yr30 <= POC_LMI else "✗")
            print(f"    {r.label:40s}  PoC={r.pod_yr30:5.1f}%  Surplus=${r.mean_surplus_yr30:>11,.0f}  "
                  f"Sharpe={r.sharpe_like:.3f}  {tier}")

    # PS impact
    print(f"\n  PROFIT SHARE:")
    ps_results = [r for r in r1 if "PS=" in r.label]
    for r in sorted(ps_results, key=lambda x: x.label):
        tier = "✓RE" if r.pod_yr30 <= POC_REINSURANCE else ("✓LMI" if r.pod_yr30 <= POC_LMI else "✗")
        print(f"    {r.label:40s}  PoC={r.pod_yr30:5.1f}%  Rev=${r.mean_total_fp_revenue:>11,.0f}  "
              f"Sharpe={r.sharpe_like:.3f}  {tier}")

    # ── PHASE 2: COMBINED ──
    p2 = build_phase2()
    print(f"\n\n{'='*80}")
    print(f"PHASE 2: COMBINED GRID — {len(p2)} scenarios × 10,000 paths")
    print(f"{'='*80}")

    t1 = time.time()
    r2 = []
    for i, p in enumerate(p2):
        if (i+1) % 200 == 0 or i == 0:
            print(f"  [{i+1}/{len(p2)}] {p.label}")
        r2.append(run_scenario(p, z1_10k, z2_10k))
    print(f"  Done in {time.time()-t1:.1f}s")

    all_r = r1 + r2
    for r in all_r:
        r._composite = r.revenue_per_unit_risk * r.sharpe_like

    # Filter to constrained annuity range only
    constrained = [r for r in all_r if r.label == "v14a_BASELINE" or annuity_in_range(r.loan_type, r.annuity_pa)]

    # ── TIER 1: Reinsurance grade (PoC ≤ 5%) ──
    tier1 = [r for r in constrained if r.pod_yr30 <= POC_REINSURANCE and r.label != "v14a_BASELINE"]
    tier1.sort(key=lambda r: r._composite, reverse=True)

    # ── TIER 2: LMI grade (PoC ≤ 12%) ──
    tier2 = [r for r in constrained if r.pod_yr30 <= POC_LMI and r.label != "v14a_BASELINE"]
    tier2.sort(key=lambda r: r._composite, reverse=True)

    print(f"\n  Constrained scenarios (correct annuity range): {len(constrained)}")
    print(f"  TIER 1 — Reinsurance grade (PoC ≤ {POC_REINSURANCE:.0f}%): {len(tier1)} scenarios")
    print(f"  TIER 2 — LMI grade (PoC ≤ {POC_LMI:.0f}%): {len(tier2)} scenarios")

    # Show pareto for each tier
    pareto_t1 = find_pareto(tier1) if tier1 else []
    pareto_t2 = find_pareto(tier2) if tier2 else []

    if tier1:
        ptbl(f"TIER 1 — REINSURANCE GRADE (PoC ≤ {POC_REINSURANCE:.0f}%) — Top 25 by composite", tier1)
    if tier2:
        ptbl(f"TIER 2 — LMI GRADE (PoC ≤ {POC_LMI:.0f}%) — Top 25 by composite", tier2)

    # Best by payout duration within each tier
    print(f"\n{'='*80}")
    print("BEST BY PAYOUT DURATION (within constraints)")
    print(f"{'='*80}")

    for tier_label, tier_results, poc_limit in [
        ("REINSURANCE (PoC ≤ 5%)", tier1, POC_REINSURANCE),
        ("LMI (PoC ≤ 12%)", tier2, POC_LMI),
    ]:
        print(f"\n  {tier_label}:")
        for min_term in [10, 15, 20, 25]:
            filt = sorted([r for r in tier_results if r.annuity_term >= min_term],
                          key=lambda r: r._composite, reverse=True)
            if filt:
                r = filt[0]
                print(f"    Best ≥{min_term}yr: {r.label}")
                print(f"      {r.annuity_pct:.2f}% = ${r.annuity_pa:,.0f}/yr × {r.annuity_term}yr "
                      f"= ${r.total_annuity:,.0f} | PoC={r.pod_yr30:.1f}% | "
                      f"FP Rev=${r.mean_total_fp_revenue:,.0f} | Sharpe={r.sharpe_like:.3f}")
            else:
                print(f"    Best ≥{min_term}yr: NO FEASIBLE CONFIGURATION at PoC ≤ {poc_limit:.0f}%")

    # Best by loan type
    print(f"\n{'='*80}")
    print("BEST BY LOAN TYPE (within constraints)")
    print(f"{'='*80}")
    for tier_label, tier_results in [("REINSURANCE", tier1), ("LMI", tier2)]:
        print(f"\n  {tier_label}:")
        for lt in ["PI", "IO"]:
            filt = sorted([r for r in tier_results if r.loan_type == lt],
                          key=lambda r: r._composite, reverse=True)
            if filt:
                r = filt[0]
                print(f"    Best {lt}: {r.label}")
                print(f"      {r.annuity_pct:.2f}% = ${r.annuity_pa:,.0f}/yr × {r.annuity_term}yr "
                      f"= ${r.total_annuity:,.0f} | PoC={r.pod_yr30:.1f}% | "
                      f"FP Rev=${r.mean_total_fp_revenue:,.0f} | Sharpe={r.sharpe_like:.3f}")
            else:
                print(f"    Best {lt}: NO FEASIBLE CONFIGURATION")

    # ── PHASE 3: 50K VALIDATION ──
    candidates = set(["v14a_BASELINE"])
    for r in pareto_t1: candidates.add(r.label)
    for r in pareto_t2: candidates.add(r.label)
    for r in tier1[:15]: candidates.add(r.label)
    for r in tier2[:10]: candidates.add(r.label)

    # Best from each payout duration in each tier
    for tier_results in [tier1, tier2]:
        for min_term in [10, 15, 20, 25]:
            filt = sorted([r for r in tier_results if r.annuity_term >= min_term],
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
    t1_50k = sorted([r for r in r50k if r.pod_yr30 <= POC_REINSURANCE and r.label != "v14a_BASELINE"],
                    key=lambda r: r._composite, reverse=True)
    t2_50k = sorted([r for r in r50k if r.pod_yr30 <= POC_LMI and r.label != "v14a_BASELINE"],
                    key=lambda r: r._composite, reverse=True)

    pareto_50k_t1 = find_pareto(t1_50k) if t1_50k else []
    pareto_50k_t2 = find_pareto(t2_50k) if t2_50k else []

    if t1_50k:
        ptbl(f"TIER 1 — REINSURANCE (PoC ≤ {POC_REINSURANCE:.0f}%) — 50K VALIDATED", t1_50k)
    if t2_50k:
        ptbl(f"TIER 2 — LMI (PoC ≤ {POC_LMI:.0f}%) — 50K VALIDATED", t2_50k)

    # ── FINAL RESULTS ──
    print(f"\n\n{'='*80}")
    print("FINAL RECOMMENDED CONFIGURATIONS (50K validated)")
    print(f"{'='*80}")

    rec_reinsurance = t1_50k[0] if t1_50k else None
    rec_lmi = t2_50k[0] if t2_50k else None

    for tier_label, rec in [("REINSURANCE GRADE (PoC ≤ 5%)", rec_reinsurance),
                             ("LMI GRADE (PoC ≤ 12%)", rec_lmi)]:
        if not rec or not bl_50k:
            print(f"\n  {tier_label}: No feasible configuration")
            continue
        print(f"\n  {tier_label}: {rec.label}")
        print(f"  {'Metric':40s}  {'v14a Baseline':>15s}  {'Recommended':>15s}  {'Change':>12s}")
        print("  " + "-" * 90)
        rows = [
            ("Annuity Rate", f"{bl_50k.annuity_pct:.2f}%", f"{rec.annuity_pct:.2f}%", ""),
            ("Annuity", f"${bl_50k.annuity_pa:,.0f}×{bl_50k.annuity_term}yr",
             f"${rec.annuity_pa:,.0f}×{rec.annuity_term}yr", ""),
            ("Total Income", f"${bl_50k.total_annuity:>12,.0f}", f"${rec.total_annuity:>12,.0f}",
             f"+${rec.total_annuity - bl_50k.total_annuity:,.0f}" if rec.total_annuity >= bl_50k.total_annuity else f"-${bl_50k.total_annuity - rec.total_annuity:,.0f}"),
            ("Loan Type", bl_50k.loan_type, rec.loan_type, ""),
            ("Collar", f"±{(bl_50k.buffer_cap-1)*100:.0f}%", f"±{(rec.buffer_cap-1)*100:.0f}%", ""),
            ("Holiday Entry", f"{bl_50k.holiday_entry:.2f}", f"{rec.holiday_entry:.2f}", ""),
            ("PS Config", f"{bl_50k.profit_share_pct*100:.0f}% q{bl_50k.profit_share_years}",
             f"{rec.profit_share_pct*100:.0f}% q{rec.profit_share_years}", ""),
            ("FP Margin", f"{bl_50k.fp_margin*100:.2f}%", f"{rec.fp_margin*100:.2f}%", ""),
            ("", "", "", ""),
            ("PoC Year 30", f"{bl_50k.pod_yr30:.1f}%", f"{rec.pod_yr30:.1f}%",
             f"{rec.pod_yr30 - bl_50k.pod_yr30:+.1f}pp"),
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

    # Best by payout duration at 50K
    print(f"\n{'='*80}")
    print("BEST BY PAYOUT DURATION — 50K VALIDATED")
    print(f"{'='*80}")
    for tier_label, tier_results in [("REINSURANCE (PoC ≤ 5%)", t1_50k), ("LMI (PoC ≤ 12%)", t2_50k)]:
        print(f"\n  {tier_label}:")
        for min_term in [10, 15, 20, 25]:
            filt = sorted([r for r in tier_results if r.annuity_term >= min_term],
                          key=lambda r: r._composite, reverse=True)
            if filt:
                r = filt[0]
                print(f"    ≥{min_term}yr: {r.label}")
                print(f"      {r.annuity_pct:.2f}% × {r.annuity_term}yr = ${r.total_annuity:,.0f} | "
                      f"PoC={r.pod_yr30:.1f}% | Rev=${r.mean_total_fp_revenue:,.0f} | Sharpe={r.sharpe_like:.3f}")
            else:
                print(f"    ≥{min_term}yr: No feasible configuration")

    # ── Save ──
    output = {
        'metadata': {
            'description': 'Constrained optimisation: annuity rate 1.25-1.50% (PI) / 1.50-2.00% (IO), PoC ≤ 5%/12%',
            'constraints': {
                'pi_annuity_range': f'{PI_ANNUITY_MIN_PCT*100:.2f}%-{PI_ANNUITY_MAX_PCT*100:.2f}%',
                'io_annuity_range': f'{IO_ANNUITY_MIN_PCT*100:.2f}%-{IO_ANNUITY_MAX_PCT*100:.2f}%',
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
        'recommended_reinsurance': asdict(rec_reinsurance) if rec_reinsurance else None,
        'recommended_lmi': asdict(rec_lmi) if rec_lmi else None,
        'tier1_reinsurance_50k': [asdict(r) for r in t1_50k],
        'tier2_lmi_50k': [asdict(r) for r in t2_50k],
        'pareto_reinsurance_50k': [asdict(r) for r in pareto_50k_t1],
        'pareto_lmi_50k': [asdict(r) for r in pareto_50k_t2],
        'all_50k_validated': [asdict(r) for r in sorted(r50k, key=lambda r: r._composite, reverse=True)],
    }

    # Best by payout duration
    output['best_by_duration'] = {}
    for tier_key, tier_results in [('reinsurance', t1_50k), ('lmi', t2_50k)]:
        output['best_by_duration'][tier_key] = {}
        for min_term in [10, 15, 20, 25]:
            filt = sorted([r for r in tier_results if r.annuity_term >= min_term],
                          key=lambda r: r._composite, reverse=True)
            if filt:
                output['best_by_duration'][tier_key][f'min_{min_term}yr'] = asdict(filt[0])

    # Clean _composite
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

    with open('optimisation_v14a_constrained_results.json', 'w') as f:
        json.dump(output, f, indent=2)
    print(f"\n\nResults saved to optimisation_v14a_constrained_results.json")
    print(f"Total scenarios: {len(r1) + len(r2) + len(r50k)}")


if __name__ == '__main__':
    main()
