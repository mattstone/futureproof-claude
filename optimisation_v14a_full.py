#!/usr/bin/env python3
"""
EPM v14a FULL Optimisation — Including Longer Payouts
======================================================
Addresses the concern that short payout periods (7yr on a 30yr EPM)
are unattractive to borrowers. Explores annuity terms from 10 to 25 years
alongside all other levers.

PHASE 1: Individual lever analysis — annuity term × amount, loan type,
          collar, holiday, PS%, PS frequency, FP margin
PHASE 2: Combined grid with attractive payout configurations
PHASE 3: 50K validation of top candidates
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

    return Result(
        label=params.label, loan_type=params.loan_type,
        annuity_pa=params.annuity_pa, annuity_term=params.annuity_term,
        total_annuity=ta,
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


# ============================================================
# PHASE 1: INDIVIDUAL LEVER SWEEPS
# ============================================================
def build_phase1():
    s = []
    s.append(mkp("v14a_BASELINE"))

    # ── ANNUITY: Term × Amount (the key new dimension) ──
    # Fixed annual amount, varying term
    for pa in [15_000, 20_000, 25_000, 30_000]:
        for term in [10, 12, 15, 18, 20, 25]:
            if pa == 25_000 and term == 10:
                continue  # baseline
            total = pa * term
            for lt in ["IO", "PI"]:
                s.append(mkp(f"{lt}_${pa//1000}K×{term}yr=${total//1000}K",
                             loan_type=lt, annuity_pa=pa, annuity_term=term))

    # Fixed total payout, varying term/amount
    for total in [250_000, 300_000, 375_000]:
        for term in [10, 12, 15, 20, 25]:
            pa = total // term
            if pa == 25_000 and term == 10 and total == 250_000:
                continue
            for lt in ["IO", "PI"]:
                s.append(mkp(f"{lt}_${pa//1000}K×{term}yr(T=${total//1000}K)",
                             loan_type=lt, annuity_pa=pa, annuity_term=term))

    # ── LOAN TYPE at baseline ──
    s.append(mkp("PI_baseline", loan_type="PI"))

    # ── COLLAR (IO and PI) ──
    for cap_pct in [20, 25, 30, 35, 40]:
        cap = 1 + cap_pct / 100; floor = 2 - cap
        if cap_pct != 20:
            s.append(mkp(f"IO_±{cap_pct}%", buffer_cap=cap, buffer_floor=floor))
        s.append(mkp(f"PI_±{cap_pct}%", loan_type="PI", buffer_cap=cap, buffer_floor=floor))

    # ── HOLIDAY ──
    for entry in [0.90, 0.95, 1.00, 1.05]:
        ex = entry * HOLIDAY_RATIO
        if abs(entry - 0.90) > 0.005:
            s.append(mkp(f"IO_HE={entry:.2f}", holiday_entry=entry, holiday_exit=ex))
        s.append(mkp(f"PI_HE={entry:.2f}", loan_type="PI", holiday_entry=entry, holiday_exit=ex))

    # ── PS% and FREQUENCY ──
    for ps in [0.15, 0.20, 0.25, 0.30]:
        for freq in [3, 5]:
            if ps == 0.25 and freq == 5:
                continue
            s.append(mkp(f"PS={ps*100:.0f}%_q{freq}",
                         profit_share_pct=ps, profit_share_years=freq))

    # ── FP MARGIN ──
    for fm in [0.0010, 0.0015, 0.0025]:
        if abs(fm - 0.0025) > 0.0001:
            s.append(mkp(f"FM={fm*100:.2f}%", fp_margin=fm))

    return s


# ============================================================
# PHASE 2: COMBINED GRID
# ============================================================
def build_phase2():
    s = []

    loan_types = ["IO", "PI"]
    collars = [(1.25, 0.75), (1.30, 0.70), (1.35, 0.65)]
    holidays = [0.95, 1.00, 1.05]
    ps_configs = [(0.25, 5), (0.25, 3), (0.20, 3)]
    fp_margins = [0.0015, 0.0025]

    # Attractive payout configurations (longer terms)
    annuity_configs = [
        (25_000, 10),   # baseline: $250K total
        (25_000, 15),   # $375K over 15yr — strong income
        (25_000, 20),   # $500K over 20yr — very attractive
        (20_000, 15),   # $300K over 15yr — moderate income, long payout
        (20_000, 20),   # $400K over 20yr — long payout
        (15_000, 20),   # $300K over 20yr — modest but very long
        (15_000, 25),   # $375K over 25yr — near-lifetime income
    ]

    for lt in loan_types:
        for cap, floor in collars:
            for he in holidays:
                hx = he * HOLIDAY_RATIO
                for ann_pa, ann_term in annuity_configs:
                    for ps_pct, ps_yr in ps_configs:
                        for fm in fp_margins:
                            total = ann_pa * ann_term
                            label = (f"{lt}_${ann_pa//1000}K×{ann_term}y_"
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
    print(f"  {'#':>3}  {'Label':58s}  {'Type':>4}  {'Annuity':>14}  {'PoD%':>6}  {'FP Rev':>12}  "
          f"{'Sharpe':>7}  {'Mean Surp':>12}  {'P1':>12}  {'Prem':>10}")
    print("  " + "-" * 165)
    for i, r in enumerate(results[:n]):
        ann = f"${r.annuity_pa/1000:.0f}K×{r.annuity_term}y=${r.total_annuity/1000:.0f}K"
        print(f"  {i+1:3d}  {r.label:58s}  {r.loan_type:>4s}  {ann:>14s}  {r.pod_yr30:5.1f}%  "
              f"${r.mean_total_fp_revenue:>11,.0f}  {r.sharpe_like:6.3f}  "
              f"${r.mean_surplus_yr30:>11,.0f}  ${r.p1_surplus:>11,.0f}  "
              f"${r.fair_premium_loaded:>9,.0f}")


def main():
    print("=" * 80)
    print("EPM v14a FULL OPTIMISATION — INCLUDING LONGER PAYOUTS")
    print("=" * 80)

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

    # ── ANNUITY TERM ANALYSIS ──
    print(f"\n{'='*80}")
    print("ANNUITY TERM × AMOUNT ANALYSIS")
    print(f"{'='*80}")

    # Fixed amount, varying term
    print(f"\n  FIXED $25K/yr, VARYING TERM:")
    print(f"    {'Config':30s}  {'Type':>4}  {'Total':>10}  {'Peak Loan':>12}  {'PoD%':>6}  {'Surplus':>12}  {'Sharpe':>7}  {'FP Rev':>12}")
    for term in [10, 12, 15, 18, 20, 25]:
        for lt in ["IO", "PI"]:
            label_search = f"{lt}_$25K×{term}yr=$" if term != 10 else ("v14a_BASELINE" if lt == "IO" else "PI_baseline")
            r = next((r for r in r1 if r.label.startswith(label_search) or r.label == label_search), None)
            if r:
                print(f"    {r.label:30s}  {r.loan_type:>4s}  ${r.total_annuity:>8,.0f}  ${r.peak_loan:>11,.0f}  "
                      f"{r.pod_yr30:5.1f}%  ${r.mean_surplus_yr30:>11,.0f}  {r.sharpe_like:6.3f}  ${r.mean_total_fp_revenue:>11,.0f}")

    # Fixed total, varying term
    for total in [250_000, 300_000, 375_000]:
        print(f"\n  FIXED TOTAL ${total//1000}K, VARYING TERM (P&I only):")
        print(f"    {'Config':40s}  {'Annual':>8}  {'Term':>5}  {'Peak Loan':>12}  {'PoD%':>6}  {'Surplus':>12}  {'Sharpe':>7}")
        for term in [10, 12, 15, 20, 25]:
            pa = total // term
            r = next((r for r in r1 if f"PI_${pa//1000}K×{term}yr(T=${total//1000}K)" == r.label), None)
            if not r and total == 250_000 and term == 10:
                r = next((r for r in r1 if r.label == "PI_baseline"), None)
            if r:
                print(f"    {r.label:40s}  ${r.annuity_pa:>7,.0f}  {r.annuity_term:>4d}y  ${r.peak_loan:>11,.0f}  "
                      f"{r.pod_yr30:5.1f}%  ${r.mean_surplus_yr30:>11,.0f}  {r.sharpe_like:6.3f}")

    # ── OTHER LEVERS ──
    print(f"\n{'='*80}")
    print("OTHER LEVER ANALYSIS")
    print(f"{'='*80}")

    # Collar
    print(f"\n  COLLAR WIDTH (P&I at baseline annuity):")
    for cap_pct in [20, 25, 30, 35, 40]:
        r = next((r for r in r1 if r.label == f"PI_±{cap_pct}%"), None)
        if r:
            print(f"    ±{cap_pct}%: PoD={r.pod_yr30:.1f}%, Surplus=${r.mean_surplus_yr30:>11,.0f}, Sharpe={r.sharpe_like:.3f}")

    # Holiday
    print(f"\n  HOLIDAY ENTRY (P&I at baseline annuity):")
    for entry in [0.90, 0.95, 1.00, 1.05]:
        r = next((r for r in r1 if r.label == f"PI_HE={entry:.2f}"), None)
        if r:
            print(f"    HE={entry:.2f}: PoD={r.pod_yr30:.1f}%, Surplus=${r.mean_surplus_yr30:>11,.0f}, Sharpe={r.sharpe_like:.3f}")

    # PS
    print(f"\n  PROFIT SHARE % & FREQUENCY:")
    for ps in [0.15, 0.20, 0.25, 0.30]:
        for freq in [3, 5]:
            lbl = f"PS={ps*100:.0f}%_q{freq}"
            r = next((r for r in r1 if r.label == lbl), None)
            if r:
                print(f"    {lbl}: PoD={r.pod_yr30:.1f}%, Rev=${r.mean_total_fp_revenue:>11,.0f}, Sharpe={r.sharpe_like:.3f}")

    # ── PHASE 2: COMBINED ──
    p2 = build_phase2()
    print(f"\n\n{'='*80}")
    print(f"PHASE 2: COMBINED OPTIMISATION — {len(p2)} scenarios × 10,000 paths")
    print(f"{'='*80}")

    t1 = time.time()
    r2 = []
    for i, p in enumerate(p2):
        if (i+1) % 100 == 0 or i == 0:
            print(f"  [{i+1}/{len(p2)}] {p.label}")
        r2.append(run_scenario(p, z1_10k, z2_10k))
    print(f"  Done in {time.time()-t1:.1f}s")

    all_r = r1 + r2
    for r in all_r:
        r._composite = r.revenue_per_unit_risk * r.sharpe_like

    pareto = find_pareto(all_r)
    top_comp = sorted(all_r, key=lambda r: r._composite, reverse=True)
    lowest_pod = sorted(all_r, key=lambda r: r.pod_yr30)

    ptbl(f"PARETO FRONT ({len(pareto)} scenarios)", pareto)
    ptbl("TOP 25 BY COMPOSITE SCORE", top_comp)
    ptbl("TOP 25 SAFEST (lowest PoD)", lowest_pod)

    # ── Show best configs by payout attractiveness ──
    print(f"\n{'='*80}")
    print("BEST CONFIGS BY PAYOUT DURATION (minimum 10yr payout)")
    print(f"{'='*80}")

    for min_term in [10, 15, 20, 25]:
        filtered = [r for r in all_r if r.annuity_term >= min_term]
        if not filtered:
            continue
        for r in filtered:
            r._composite = r.revenue_per_unit_risk * r.sharpe_like
        best = sorted(filtered, key=lambda r: r._composite, reverse=True)
        ptbl(f"BEST WITH ≥{min_term}yr PAYOUT (top 10)", best, n=10)

    # ── PHASE 3: 50K VALIDATION ──
    candidates = set(["v14a_BASELINE"])
    for r in pareto[:12]: candidates.add(r.label)
    for r in top_comp[:12]: candidates.add(r.label)
    for r in lowest_pod[:8]: candidates.add(r.label)

    # Also add best from each payout duration bucket
    for min_term in [10, 15, 20, 25]:
        filt = sorted([r for r in all_r if r.annuity_term >= min_term],
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

    pareto_50k = find_pareto(r50k)
    recommended = max(r50k, key=lambda r: r._composite)
    bl_50k = next((r for r in r50k if r.label == "v14a_BASELINE"), None)

    ptbl(f"PARETO FRONT — 50K ({len(pareto_50k)} scenarios)", pareto_50k)
    ptbl("ALL VALIDATED (by composite)", sorted(r50k, key=lambda r: r._composite, reverse=True), n=40)

    # Best by payout duration at 50K
    print(f"\n{'='*80}")
    print("BEST BY PAYOUT DURATION (50K validated)")
    print(f"{'='*80}")
    for min_term in [10, 15, 20, 25]:
        filt = sorted([r for r in r50k if r.annuity_term >= min_term],
                      key=lambda r: r._composite, reverse=True)
        if filt:
            r = filt[0]
            print(f"\n  Best ≥{min_term}yr payout: {r.label}")
            print(f"    Income: ${r.annuity_pa:,.0f}/yr × {r.annuity_term}yr = ${r.total_annuity:,.0f}")
            print(f"    PoD: {r.pod_yr30:.1f}%  |  Surplus: ${r.mean_surplus_yr30:>11,.0f}  |  "
                  f"FP Rev: ${r.mean_total_fp_revenue:>11,.0f}  |  Sharpe: {r.sharpe_like:.3f}")

    # ── FINAL COMPARISON ──
    if bl_50k:
        print(f"\n\n{'='*80}")
        print("FINAL COMPARISON")
        print(f"{'='*80}")

        # Show recommended for each payout bucket
        for min_term, label in [(10, "≥10yr"), (15, "≥15yr"), (20, "≥20yr")]:
            filt = sorted([r for r in r50k if r.annuity_term >= min_term],
                          key=lambda r: r._composite, reverse=True)
            if not filt:
                continue
            rec = filt[0]
            print(f"\n  RECOMMENDED ({label} payout): {rec.label}")
            print(f"  {'Metric':40s}  {'v14a Baseline':>15s}  {'Recommended':>15s}  {'Change':>12s}")
            print("  " + "-" * 90)
            rows = [
                ("Annuity", f"${bl_50k.annuity_pa:,.0f}×{bl_50k.annuity_term}yr",
                 f"${rec.annuity_pa:,.0f}×{rec.annuity_term}yr", ""),
                ("Total Income", f"${bl_50k.total_annuity:>12,.0f}", f"${rec.total_annuity:>12,.0f}",
                 f"+${rec.total_annuity - bl_50k.total_annuity:,.0f}" if rec.total_annuity > bl_50k.total_annuity else f"-${bl_50k.total_annuity - rec.total_annuity:,.0f}"),
                ("Loan Type", bl_50k.loan_type, rec.loan_type, ""),
                ("Collar", f"±{(bl_50k.buffer_cap-1)*100:.0f}%", f"±{(rec.buffer_cap-1)*100:.0f}%", ""),
                ("Holiday Entry", f"{bl_50k.holiday_entry:.2f}", f"{rec.holiday_entry:.2f}", ""),
                ("PS Config", f"{bl_50k.profit_share_pct*100:.0f}% q{bl_50k.profit_share_years}",
                 f"{rec.profit_share_pct*100:.0f}% q{rec.profit_share_years}", ""),
                ("FP Margin", f"{bl_50k.fp_margin*100:.2f}%", f"{rec.fp_margin*100:.2f}%", ""),
                ("", "", "", ""),
                ("PoD Year 30", f"{bl_50k.pod_yr30:.1f}%", f"{rec.pod_yr30:.1f}%",
                 f"{rec.pod_yr30 - bl_50k.pod_yr30:+.1f}pp"),
                ("Mean Surplus", f"${bl_50k.mean_surplus_yr30:>12,.0f}", f"${rec.mean_surplus_yr30:>12,.0f}",
                 f"+{(rec.mean_surplus_yr30/bl_50k.mean_surplus_yr30 - 1)*100:.0f}%"),
                ("Sharpe", f"{bl_50k.sharpe_like:.3f}", f"{rec.sharpe_like:.3f}", ""),
                ("FP Revenue", f"${bl_50k.mean_total_fp_revenue:>12,.0f}", f"${rec.mean_total_fp_revenue:>12,.0f}",
                 f"+{(rec.mean_total_fp_revenue/bl_50k.mean_total_fp_revenue - 1)*100:.0f}%"),
                ("Premium", f"${bl_50k.fair_premium_loaded:>12,.0f}", f"${rec.fair_premium_loaded:>12,.0f}",
                 f"{(rec.fair_premium_loaded/bl_50k.fair_premium_loaded - 1)*100:+.0f}%"),
                ("Final Loan", f"${bl_50k.mean_final_loan_balance:>12,.0f}", f"${rec.mean_final_loan_balance:>12,.0f}", ""),
                ("Protection", f"{bl_50k.mean_borrower_equity_return:.1f}%",
                 f"{rec.mean_borrower_equity_return:.1f}%", ""),
            ]
            for lbl, v1, v2, chg in rows:
                if not lbl:
                    print()
                else:
                    print(f"  {lbl:40s}  {v1:>15s}  {v2:>15s}  {chg:>12s}")

    # Save
    output = {
        'metadata': {
            'description': 'Full optimisation including longer payout periods',
            'phase1_scenarios': len(r1),
            'phase2_scenarios': len(r2),
            'phase3_scenarios': len(r50k),
            'phase1_paths': 10_000,
            'phase3_paths': 50_000,
            'seed': SEED,
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        },
        'baseline': asdict(bl_50k) if bl_50k else None,
        'recommended_overall': asdict(recommended),
        'pareto_front_50k': [asdict(r) for r in pareto_50k],
        'all_50k_validated': [asdict(r) for r in sorted(r50k, key=lambda r: r._composite, reverse=True)],
        'best_by_payout_duration': {},
    }

    for min_term in [10, 15, 20, 25]:
        filt = sorted([r for r in r50k if r.annuity_term >= min_term],
                      key=lambda r: r._composite, reverse=True)
        if filt:
            output['best_by_payout_duration'][f'min_{min_term}yr'] = asdict(filt[0])

    # Clean
    def clean(d):
        if isinstance(d, dict): d.pop('_composite', None)
    for k in ['recommended_overall', 'baseline']:
        if output.get(k): clean(output[k])
    for k in ['pareto_front_50k', 'all_50k_validated']:
        for d in output.get(k, []): clean(d)
    for v in output.get('best_by_payout_duration', {}).values():
        clean(v)

    with open('optimisation_v14a_full_results.json', 'w') as f:
        json.dump(output, f, indent=2)
    print(f"\n\nResults saved to optimisation_v14a_full_results.json")
    print(f"Total scenarios: {len(r1) + len(r2) + len(r50k)}")


if __name__ == '__main__':
    main()
