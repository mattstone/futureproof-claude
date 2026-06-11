#!/usr/bin/env python3
"""
EPM v14a COMPREHENSIVE Parameter Optimisation
===============================================
Extends the previous optimisation (collar, holiday, PS%, FP margin) with
the NEW levers requested by the owner:

  NEW DIMENSIONS:
  1. Loan Type: P&I (Principal & Interest) vs IO (Interest-Only)
  2. Profit Share Frequency: every 3 years vs every 5 years
  3. Annuity Term: 5, 7, 10, 12, 15 years
  4. Holiday Entry/Exit Thresholds: fine-grained sweep

  EXISTING DIMENSIONS (refined):
  5. Profit Share %: 15% to 35%
  6. Collar Width: ±20% to ±35%

Strategy:
  Phase 1: Individual lever analysis (each lever vs baseline, ~800 scenarios × 10K paths)
  Phase 2: Combined optimisation of best values (~600 scenarios × 10K paths)
  Phase 3: Top 30 candidates validated at 50K paths

Total: ~1,400+ scenarios
"""

import numpy as np
import json
import time
from dataclasses import dataclass, asdict, field
from scipy.stats import norm

# ============================================================
# FIXED PARAMETERS (market / structural)
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

# ============================================================
# v14a BASELINE VALUES
# ============================================================
BASELINE = {
    'annuity_pa': 25_000,
    'annuity_term': 10,
    'loan_type': 'IO',           # Interest-Only (current)
    'profit_share_pct': 0.25,
    'profit_share_years': 5,     # every 5 years
    'fp_margin': 0.0025,
    'retail_margin': 0.007,
    'buffer_cap': 1.20,
    'buffer_floor': 0.80,
    'holiday_entry': 0.90,
    'holiday_exit': 1.458,
}

# Previous optimisation recommended values
PREV_RECOMMENDED = {
    'annuity_pa': 25_000,
    'annuity_term': 10,
    'loan_type': 'IO',
    'profit_share_pct': 0.25,
    'profit_share_years': 5,
    'fp_margin': 0.0015,
    'retail_margin': 0.007,
    'buffer_cap': 1.35,
    'buffer_floor': 0.65,
    'holiday_entry': 1.00,
    'holiday_exit': 1.62,
}


# ============================================================
# COLLAR PRICING
# ============================================================
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


# ============================================================
# SCENARIO PARAMS — now includes all new levers
# ============================================================
@dataclass
class ScenarioParams:
    profit_share_pct: float
    fp_margin: float
    retail_margin: float
    buffer_cap: float
    buffer_floor: float
    holiday_entry: float
    holiday_exit: float
    annuity_pa: float = 25_000
    annuity_term: int = 10
    loan_type: str = "IO"           # "IO" or "PI"
    profit_share_years: int = 5     # 3 or 5
    label: str = ""


@dataclass
class ScenarioResult:
    label: str
    # All params
    profit_share_pct: float
    fp_margin: float
    retail_margin: float
    buffer_cap: float
    buffer_floor: float
    holiday_entry: float
    holiday_exit: float
    annuity_pa: float
    annuity_term: int
    loan_type: str
    profit_share_years: int
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
    max_drawdown_p1: float

    # Return
    mean_surplus_yr30: float
    mean_total_profit_share: float
    mean_fp_margin_income: float
    mean_total_fp_revenue: float
    mean_funder_surplus_share: float
    mean_borrower_equity_return: float

    # Borrower metrics
    total_annuity_received: float        # total $ borrower receives
    mean_final_loan_balance: float       # what's owed at maturity

    # Efficiency
    revenue_per_unit_risk: float
    sharpe_like: float
    total_variable_cost_pct: float
    premium_as_pct_loan: float

    # Time series
    pod_by_year: list
    mean_surplus_by_year: list
    p10_by_year: list
    mean_investment_by_year: list
    mean_holidays_by_year: list
    mean_loan_by_year: list


# ============================================================
# LOAN TRAJECTORY BUILDER
# ============================================================
def build_loan_trajectory(annuity_pa, annuity_term, loan_type, initial_loan=INITIAL_LOAN):
    """
    Build deterministic loan trajectory.

    IO (Interest-Only): Loan increases during annuity term, then stays flat.
    PI (Principal & Interest): After annuity term, loan amortizes to zero over remaining years.
    """
    loan = np.zeros(TENURE_YEARS + 1)
    loan[0] = initial_loan

    # Phase 1: Annuity drawdown (loan increases)
    for t in range(1, TENURE_YEARS + 1):
        if t <= annuity_term:
            loan[t] = loan[t-1] + annuity_pa
        else:
            loan[t] = loan[t-1]

    if loan_type == "PI":
        # Phase 2: After annuity term, amortize to zero over remaining years
        remaining_years = TENURE_YEARS - annuity_term
        if remaining_years > 0:
            peak_loan = loan[annuity_term]
            # Linear amortization: reduce loan evenly to zero
            annual_principal = peak_loan / remaining_years
            for t in range(annuity_term + 1, TENURE_YEARS + 1):
                loan[t] = loan[t-1] - annual_principal
                loan[t] = max(loan[t], 0)  # can't go negative

    return loan


# ============================================================
# SIMULATION ENGINE (extended with new levers)
# ============================================================
def run_scenario(params: ScenarioParams, z1, z2, n_paths=None) -> ScenarioResult:
    """Run MC simulation for a single parameter set."""

    collar_price = estimate_collar_price(params.buffer_cap, params.buffer_floor)

    # Build loan trajectory for this scenario
    loan = build_loan_trajectory(
        params.annuity_pa, params.annuity_term, params.loan_type
    )
    max_loan = np.max(loan)

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

    # For P&I: track principal payments from investment account
    cumulative_principal_paid = np.zeros(n)

    pod_by_year = []
    mean_surplus_by_year = []
    p10_by_year = []
    mean_investment_by_year = [float(np.mean(investment))]
    mean_holidays_by_year = []
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
        funder_int = -ffc * avg_loan
        funder_interest_tot += funder_int

        # Holiday mechanism
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

        # For P&I: principal repayment comes from investment account
        principal_payment = 0.0
        if params.loan_type == "PI" and t > params.annuity_term:
            # The difference in loan[t-1] vs loan[t] is the principal repayment
            principal_due = loan[t-1] - loan[t]
            if principal_due > 0:
                principal_payment = -principal_due  # negative = cost to investment
                cumulative_principal_paid += principal_due

        if t == TENURE_YEARS:
            ret_nim = -params.retail_margin * loan[t-1] / 2
            int_charged = -ffc * loan[t-1] / 2

        inv_ret = investment * hedged_ret
        investment = investment + inv_ret + int_charged + ret_nim + fp_pay + hedge_pay + principal_payment

        surplus = investment - loan[t] + interest_deficit

        # Profit share at configured frequency
        if t < TENURE_YEARS and t % params.profit_share_years == 0:
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
        mean_loan_by_year.append(float(loan[t]))
        p1_yr = float(np.percentile(surplus, 1))
        if p1_yr < worst_p1:
            worst_p1 = p1_yr

        if t == 10: pod_yr10 = dp
        if t == 15: pod_yr15 = dp
        if t == 20: pod_yr20 = dp

    # Final metrics
    fs = surplus
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
    borrower_equity_return = float((1 - pod30 / 100) * 100)
    std_s = float(np.std(fs))
    total_vc = params.retail_margin + params.fp_margin + HEDGING_FEE
    fp_rev = float(np.mean(cumulative_profit_share) + np.mean(cumulative_fp_margin))

    total_annuity = params.annuity_pa * params.annuity_term

    return ScenarioResult(
        label=params.label,
        profit_share_pct=params.profit_share_pct,
        fp_margin=params.fp_margin,
        retail_margin=params.retail_margin,
        buffer_cap=params.buffer_cap,
        buffer_floor=params.buffer_floor,
        holiday_entry=params.holiday_entry,
        holiday_exit=params.holiday_exit,
        annuity_pa=params.annuity_pa,
        annuity_term=params.annuity_term,
        loan_type=params.loan_type,
        profit_share_years=params.profit_share_years,
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

        total_annuity_received=total_annuity,
        mean_final_loan_balance=round(float(loan[TENURE_YEARS]), 0),

        revenue_per_unit_risk=round(fp_rev / max(pod30, 0.01), 0),
        sharpe_like=round(float(np.mean(fs)) / max(std_s, 1), 4),
        total_variable_cost_pct=round(total_vc * 100, 2),
        premium_as_pct_loan=round(fp_raw * 1.5 / max(max_loan, 1) * 100, 3),

        pod_by_year=[round(x, 2) for x in pod_by_year],
        mean_surplus_by_year=[round(x, 0) for x in mean_surplus_by_year],
        p10_by_year=[round(x, 0) for x in p10_by_year],
        mean_investment_by_year=[round(x, 0) for x in mean_investment_by_year],
        mean_holidays_by_year=[round(x, 3) for x in mean_holidays_by_year],
        mean_loan_by_year=[round(x, 0) for x in mean_loan_by_year],
    )


# ============================================================
# SCENARIO BUILDERS
# ============================================================
HOLIDAY_RATIO = 1.458 / 0.90  # standard entry-to-exit ratio


def make_params(label, **overrides):
    """Create ScenarioParams from baseline with overrides."""
    p = dict(BASELINE)
    p.update(overrides)
    return ScenarioParams(
        profit_share_pct=p['profit_share_pct'],
        fp_margin=p['fp_margin'],
        retail_margin=p['retail_margin'],
        buffer_cap=p['buffer_cap'],
        buffer_floor=p['buffer_floor'],
        holiday_entry=p['holiday_entry'],
        holiday_exit=p['holiday_exit'],
        annuity_pa=p['annuity_pa'],
        annuity_term=p['annuity_term'],
        loan_type=p['loan_type'],
        profit_share_years=p['profit_share_years'],
        label=label,
    )


def build_phase1_scenarios():
    """Phase 1: Individual lever analysis — each new lever swept independently."""
    scenarios = []

    # ── BASELINE ──
    scenarios.append(make_params("v14a_BASELINE"))
    scenarios.append(make_params("PREV_RECOMMENDED",
        **{k: v for k, v in PREV_RECOMMENDED.items() if k != 'annuity_pa'}))

    # ── LEVER 1: Loan Type (P&I vs IO) ──
    # Test P&I at baseline AND at previous recommended settings
    scenarios.append(make_params("PI_at_baseline", loan_type="PI"))
    scenarios.append(make_params("PI_at_prev_rec",
        loan_type="PI", fp_margin=0.0015, buffer_cap=1.35, buffer_floor=0.65,
        holiday_entry=1.00, holiday_exit=1.62))

    # P&I with different collar widths
    for cap_pct in [20, 25, 30, 35]:
        cap = 1 + cap_pct / 100
        floor = 2 - cap
        scenarios.append(make_params(f"PI_collar±{cap_pct}%",
            loan_type="PI", buffer_cap=cap, buffer_floor=floor))

    # ── LEVER 2: Profit Share Frequency (3yr vs 5yr) ──
    for ps_pct in [0.15, 0.20, 0.25, 0.30, 0.35]:
        # Every 5 years (current)
        scenarios.append(make_params(f"PS={ps_pct*100:.0f}%_every5yr",
            profit_share_pct=ps_pct, profit_share_years=5))
        # Every 3 years (new)
        scenarios.append(make_params(f"PS={ps_pct*100:.0f}%_every3yr",
            profit_share_pct=ps_pct, profit_share_years=3))

    # Lower PS% at higher frequency might yield similar total but better cash flow
    for ps_pct in [0.10, 0.12, 0.15, 0.18]:
        scenarios.append(make_params(f"PS={ps_pct*100:.0f}%_every3yr_low",
            profit_share_pct=ps_pct, profit_share_years=3))

    # ── LEVER 3: Annuity Term ──
    for term in [5, 7, 10, 12, 15]:
        if term == 10:
            continue  # already in baseline
        scenarios.append(make_params(f"Annuity_{term}yr",
            annuity_term=term))
        # Also test with P&I
        scenarios.append(make_params(f"Annuity_{term}yr_PI",
            annuity_term=term, loan_type="PI"))

    # Different annuity amounts (same total payout)
    # Baseline: $25K × 10yr = $250K total
    # Alternatives: spread $250K over different terms
    for term in [5, 7, 12, 15, 20]:
        pa = int(250_000 / term)
        scenarios.append(make_params(f"Annuity_${pa/1000:.0f}K×{term}yr",
            annuity_pa=pa, annuity_term=term))

    # ── LEVER 4: Holiday Entry/Exit Thresholds (fine grid) ──
    for entry in [0.80, 0.85, 0.88, 0.90, 0.92, 0.94, 0.95, 0.96, 0.98, 1.00, 1.02, 1.05]:
        if abs(entry - 0.90) < 0.005:
            continue  # already in baseline
        exit_lvl = entry * HOLIDAY_RATIO
        scenarios.append(make_params(f"Holiday_entry={entry:.2f}",
            holiday_entry=entry, holiday_exit=exit_lvl))

    # Test asymmetric exit ratios
    for entry in [0.90, 0.95, 1.00]:
        for exit_mult in [1.3, 1.5, 1.62, 1.8, 2.0]:
            exit_lvl = entry * exit_mult
            if abs(entry - 0.90) < 0.005 and abs(exit_mult - HOLIDAY_RATIO) < 0.05:
                continue
            scenarios.append(make_params(f"Holiday_{entry:.2f}×{exit_mult:.1f}",
                holiday_entry=entry, holiday_exit=exit_lvl))

    # No holidays
    scenarios.append(make_params("NO_holidays",
        holiday_entry=0.0, holiday_exit=99.0))

    # ── LEVER 5: Profit Share % (refined grid) ──
    for ps in [0.05, 0.08, 0.10, 0.12, 0.15, 0.18, 0.20, 0.22, 0.25, 0.28, 0.30, 0.35, 0.40]:
        if abs(ps - 0.25) < 0.005:
            continue
        scenarios.append(make_params(f"PS={ps*100:.0f}%",
            profit_share_pct=ps))

    # ── LEVER 6: Collar Width ──
    for cap_pct in [15, 18, 20, 22, 25, 28, 30, 33, 35, 40]:
        if cap_pct == 20:
            continue
        cap = 1 + cap_pct / 100
        floor = 2 - cap
        scenarios.append(make_params(f"Collar±{cap_pct}%",
            buffer_cap=cap, buffer_floor=floor))

    # ── LEVER 7: FP Margin ──
    for fm in [0.001, 0.0015, 0.002, 0.0025, 0.003, 0.0035, 0.004, 0.005]:
        if abs(fm - 0.0025) < 0.0001:
            continue
        scenarios.append(make_params(f"FM={fm*100:.2f}%",
            fp_margin=fm))

    return scenarios


def build_phase2_scenarios(phase1_results):
    """
    Phase 2: Combined optimisation.
    Takes best values from each lever and creates a grid of combinations.
    """
    scenarios = []

    # Best loan types
    loan_types = ["IO", "PI"]

    # Best PS configs (from phase 1 analysis)
    ps_configs = [
        (0.25, 5),  # baseline
        (0.25, 3),  # same % but more frequent
        (0.20, 3),  # lower % but more frequent
        (0.15, 3),  # much lower but frequent
        (0.30, 5),  # higher PS, standard frequency
        (0.20, 5),  # lower PS
    ]

    # Best annuity terms
    annuity_terms = [7, 10, 12]

    # Best collar widths
    collars = [
        (1.25, 0.75),  # ±25%
        (1.30, 0.70),  # ±30%
        (1.35, 0.65),  # ±35%
    ]

    # Best holiday entries
    holiday_entries = [0.95, 1.00, 1.05]

    # Best FP margins
    fp_margins = [0.0015, 0.002, 0.0025]

    # Combined grid: loan_type × ps_config × collar × holiday
    for lt in loan_types:
        for ps_pct, ps_yrs in ps_configs:
            for cap, floor in collars:
                for he in holiday_entries:
                    hx = he * HOLIDAY_RATIO
                    label = (f"{lt}_PS={ps_pct*100:.0f}%q{ps_yrs}_"
                             f"C±{(cap-1)*100:.0f}%_HE={he:.2f}")
                    scenarios.append(make_params(label,
                        loan_type=lt,
                        profit_share_pct=ps_pct,
                        profit_share_years=ps_yrs,
                        buffer_cap=cap, buffer_floor=floor,
                        holiday_entry=he, holiday_exit=hx))

    # Annuity term variations at best combo points
    for term in annuity_terms:
        if term == 10:
            continue
        for lt in loan_types:
            for cap, floor in [(1.30, 0.70), (1.35, 0.65)]:
                for he in [0.95, 1.00]:
                    hx = he * HOLIDAY_RATIO
                    label = f"{lt}_A{term}yr_C±{(cap-1)*100:.0f}%_HE={he:.2f}"
                    scenarios.append(make_params(label,
                        annuity_term=term, loan_type=lt,
                        buffer_cap=cap, buffer_floor=floor,
                        holiday_entry=he, holiday_exit=hx))

    # FP margin sweep at best combos
    for fm in fp_margins:
        for cap, floor in [(1.30, 0.70), (1.35, 0.65)]:
            for he in [0.95, 1.00]:
                hx = he * HOLIDAY_RATIO
                label = f"FM={fm*100:.2f}%_C±{(cap-1)*100:.0f}%_HE={he:.2f}"
                scenarios.append(make_params(label,
                    fp_margin=fm,
                    buffer_cap=cap, buffer_floor=floor,
                    holiday_entry=he, holiday_exit=hx))

    return scenarios


# ============================================================
# ANALYSIS HELPERS
# ============================================================
def find_pareto(results):
    """Find Pareto-optimal scenarios (maximize revenue, minimize PoD)."""
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


def print_comparison_table(label, results, baseline_result):
    """Print a comparison table against baseline."""
    bl = baseline_result
    print(f"\n--- {label} ---")
    print(f"  {'Config':45s}  {'PoD%':>6s}  {'Mean Surp':>12s}  {'FP Rev':>12s}  "
          f"{'Sharpe':>7s}  {'P1':>12s}  {'Premium':>10s}")
    print("  " + "-" * 110)
    for r in results:
        marker = " ★" if r.label == bl.label else ""
        print(f"  {r.label:45s}  {r.pod_yr30:5.1f}%  ${r.mean_surplus_yr30:>11,.0f}  "
              f"${r.mean_total_fp_revenue:>11,.0f}  {r.sharpe_like:6.3f}  "
              f"${r.p1_surplus:>11,.0f}  ${r.fair_premium_loaded:>9,.0f}{marker}")


def print_lever_analysis(title, results, baseline, sort_key=None):
    """Print analysis for a single lever sweep."""
    if sort_key:
        results = sorted(results, key=sort_key)
    print(f"\n{'='*80}")
    print(f"  {title}")
    print(f"{'='*80}")
    print_comparison_table(title, results, baseline)

    # Delta vs baseline
    print(f"\n  Delta vs v14a Baseline:")
    print(f"  {'Config':45s}  {'ΔPoD':>8s}  {'ΔSurplus':>12s}  {'ΔFP Rev':>12s}  {'ΔSharpe':>8s}")
    print("  " + "-" * 95)
    for r in results:
        if r.label == baseline.label:
            continue
        dpod = r.pod_yr30 - baseline.pod_yr30
        dsurp = r.mean_surplus_yr30 - baseline.mean_surplus_yr30
        drev = r.mean_total_fp_revenue - baseline.mean_total_fp_revenue
        dsharpe = r.sharpe_like - baseline.sharpe_like
        print(f"  {r.label:45s}  {dpod:>+7.1f}pp  ${dsurp:>+11,.0f}  "
              f"${drev:>+11,.0f}  {dsharpe:>+7.3f}")


# ============================================================
# MAIN
# ============================================================
def main():
    print("=" * 80)
    print("EPM v14a COMPREHENSIVE PARAMETER OPTIMISATION")
    print("=" * 80)
    print("\nNew levers: P&I vs IO, Profit Share Frequency, Annuity Term")
    print("Refined: Holiday Thresholds, Profit Share %, Collar Width, FP Margin")

    # Generate shared random numbers
    rng = np.random.default_rng(SEED)
    z1_10k = rng.standard_normal((10_000, TENURE_YEARS))
    z2r_10k = rng.standard_normal((10_000, TENURE_YEARS))
    rho = CASH_RATE_EQUITY_CORR
    z2_10k = rho * z1_10k + np.sqrt(1 - rho**2) * z2r_10k

    # ================================================================
    # PHASE 1: Individual Lever Analysis
    # ================================================================
    print("\n" + "=" * 80)
    print("PHASE 1: INDIVIDUAL LEVER ANALYSIS (10,000 paths each)")
    print("=" * 80)

    phase1 = build_phase1_scenarios()
    print(f"\nTotal Phase 1 scenarios: {len(phase1)}")

    start = time.time()
    results_p1 = []
    for i, p in enumerate(phase1):
        if (i + 1) % 25 == 0 or i == 0:
            print(f"  [{i+1}/{len(phase1)}] {p.label}")
        results_p1.append(run_scenario(p, z1_10k, z2_10k))

    t1 = time.time() - start
    print(f"  Phase 1 completed in {t1:.1f}s ({t1/len(phase1)*1000:.0f}ms/scenario)")

    # Find baseline result
    baseline = next(r for r in results_p1 if r.label == "v14a_BASELINE")

    # ── Analysis by lever ──

    # 1. Loan Type
    lt_results = [r for r in results_p1 if 'PI_' in r.label or r.label == 'v14a_BASELINE']
    print_lever_analysis("LEVER 1: LOAN TYPE (P&I vs Interest-Only)", lt_results, baseline)

    # 2. Profit Share Frequency
    psf_results = [r for r in results_p1 if 'every3yr' in r.label or 'every5yr' in r.label]
    psf_results.append(baseline)
    print_lever_analysis("LEVER 2: PROFIT SHARE FREQUENCY (3yr vs 5yr)",
                        psf_results, baseline,
                        sort_key=lambda r: (r.profit_share_years, r.profit_share_pct))

    # 3. Annuity Term
    at_results = [r for r in results_p1 if 'Annuity_' in r.label]
    at_results.append(baseline)
    print_lever_analysis("LEVER 3: ANNUITY TERM", at_results, baseline,
                        sort_key=lambda r: r.annuity_term)

    # 4. Holiday Thresholds
    hol_results = [r for r in results_p1 if 'Holiday_' in r.label or 'NO_holidays' in r.label]
    hol_results.append(baseline)
    print_lever_analysis("LEVER 4: HOLIDAY ENTRY/EXIT THRESHOLDS", hol_results, baseline,
                        sort_key=lambda r: r.holiday_entry)

    # 5. Profit Share %
    ps_results = [r for r in results_p1 if r.label.startswith('PS=') and 'every' not in r.label]
    ps_results.append(baseline)
    print_lever_analysis("LEVER 5: PROFIT SHARE %", ps_results, baseline,
                        sort_key=lambda r: r.profit_share_pct)

    # 6. Collar Width
    col_results = [r for r in results_p1 if r.label.startswith('Collar±')]
    col_results.append(baseline)
    print_lever_analysis("LEVER 6: COLLAR WIDTH", col_results, baseline,
                        sort_key=lambda r: r.buffer_cap)

    # 7. FP Margin
    fm_results = [r for r in results_p1 if r.label.startswith('FM=')]
    fm_results.append(baseline)
    print_lever_analysis("LEVER 7: FP MARGIN", fm_results, baseline,
                        sort_key=lambda r: r.fp_margin)

    # ================================================================
    # PHASE 2: Combined Optimisation
    # ================================================================
    print("\n\n" + "=" * 80)
    print("PHASE 2: COMBINED OPTIMISATION (10,000 paths each)")
    print("=" * 80)

    phase2 = build_phase2_scenarios(results_p1)
    print(f"\nTotal Phase 2 scenarios: {len(phase2)}")

    start2 = time.time()
    results_p2 = []
    for i, p in enumerate(phase2):
        if (i + 1) % 50 == 0 or i == 0:
            print(f"  [{i+1}/{len(phase2)}] {p.label}")
        results_p2.append(run_scenario(p, z1_10k, z2_10k))

    t2 = time.time() - start2
    print(f"  Phase 2 completed in {t2:.1f}s ({t2/len(phase2)*1000:.0f}ms/scenario)")

    # Combine all results
    all_results = results_p1 + results_p2

    # Pareto front
    pareto = find_pareto(all_results)
    print(f"\n  Pareto-optimal across all {len(all_results)} scenarios: {len(pareto)}")

    # Top by composite score
    for r in all_results:
        r._composite = r.revenue_per_unit_risk * r.sharpe_like

    top_composite = sorted(all_results, key=lambda r: r._composite, reverse=True)
    top_sharpe = sorted(all_results, key=lambda r: r.sharpe_like, reverse=True)
    lowest_pod = sorted(all_results, key=lambda r: r.pod_yr30)
    highest_rev = sorted(all_results, key=lambda r: r.mean_total_fp_revenue, reverse=True)

    print(f"\n--- TOP 20 by Composite Score (Revenue/Risk × Sharpe) ---")
    print(f"  {'#':>3}  {'Label':50s}  {'PoD%':>6}  {'FP Rev':>12}  {'Sharpe':>7}  "
          f"{'Mean Surp':>12}  {'P1':>12}")
    print("  " + "-" * 120)
    for i, r in enumerate(top_composite[:20]):
        print(f"  {i+1:3d}  {r.label:50s}  {r.pod_yr30:5.1f}%  ${r.mean_total_fp_revenue:>11,.0f}  "
              f"{r.sharpe_like:6.3f}  ${r.mean_surplus_yr30:>11,.0f}  ${r.p1_surplus:>11,.0f}")

    print(f"\n--- TOP 20 SAFEST (Lowest PoD) ---")
    print(f"  {'#':>3}  {'Label':50s}  {'PoD%':>6}  {'FP Rev':>12}  {'Sharpe':>7}  "
          f"{'Mean Surp':>12}  {'P1':>12}")
    print("  " + "-" * 120)
    for i, r in enumerate(lowest_pod[:20]):
        print(f"  {i+1:3d}  {r.label:50s}  {r.pod_yr30:5.1f}%  ${r.mean_total_fp_revenue:>11,.0f}  "
              f"{r.sharpe_like:6.3f}  ${r.mean_surplus_yr30:>11,.0f}  ${r.p1_surplus:>11,.0f}")

    print(f"\n--- PARETO FRONT ({len(pareto)} scenarios) ---")
    print(f"  {'#':>3}  {'Label':50s}  {'PoD%':>6}  {'FP Rev':>12}  {'Sharpe':>7}  "
          f"{'Mean Surp':>12}  {'P1':>12}  {'Prem':>10}")
    print("  " + "-" * 140)
    for i, r in enumerate(pareto):
        marker = " ★" if "BASELINE" in r.label else ""
        print(f"  {i+1:3d}  {r.label:50s}  {r.pod_yr30:5.1f}%  ${r.mean_total_fp_revenue:>11,.0f}  "
              f"{r.sharpe_like:6.3f}  ${r.mean_surplus_yr30:>11,.0f}  "
              f"${r.p1_surplus:>11,.0f}  ${r.fair_premium_loaded:>9,.0f}{marker}")

    # ================================================================
    # PHASE 3: 50K Validation of Top Candidates
    # ================================================================
    print("\n\n" + "=" * 80)
    print("PHASE 3: 50,000-PATH VALIDATION")
    print("=" * 80)

    # Select top candidates
    candidates = set()
    candidates.add("v14a_BASELINE")
    candidates.add("PREV_RECOMMENDED")
    for r in pareto[:10]:
        candidates.add(r.label)
    for r in top_composite[:10]:
        candidates.add(r.label)
    for r in top_sharpe[:5]:
        candidates.add(r.label)
    for r in lowest_pod[:5]:
        candidates.add(r.label)
    for r in highest_rev[:5]:
        candidates.add(r.label)

    # Build param lookup
    all_params = {p.label: p for p in phase1 + phase2}
    validate_labels = [l for l in candidates if l in all_params]

    print(f"\nValidating {len(validate_labels)} candidates at 50,000 paths")

    rng2 = np.random.default_rng(SEED)
    z1_50k = rng2.standard_normal((50_000, TENURE_YEARS))
    z2r_50k = rng2.standard_normal((50_000, TENURE_YEARS))
    z2_50k = rho * z1_50k + np.sqrt(1 - rho**2) * z2r_50k

    results_50k = []
    for i, label in enumerate(validate_labels):
        p = all_params[label]
        print(f"  [{i+1}/{len(validate_labels)}] {label}")
        results_50k.append(run_scenario(p, z1_50k, z2_50k))

    # Re-compute pareto on 50K
    pareto_50k = find_pareto(results_50k)

    # Find recommended
    for r in results_50k:
        r._composite = r.revenue_per_unit_risk * r.sharpe_like
    recommended = max(results_50k, key=lambda r: r._composite)

    bl_50k = next((r for r in results_50k if r.label == "v14a_BASELINE"), None)
    prev_rec_50k = next((r for r in results_50k if r.label == "PREV_RECOMMENDED"), None)

    print(f"\n--- PARETO FRONT (50K validated, {len(pareto_50k)} scenarios) ---")
    print(f"  {'#':>3}  {'Label':50s}  {'PoD%':>6}  {'FP Rev':>12}  {'Sharpe':>7}  "
          f"{'Mean Surp':>12}  {'P1':>12}  {'Prem':>10}")
    print("  " + "-" * 140)
    for i, r in enumerate(pareto_50k):
        marker = " ★" if r.label == recommended.label else ""
        marker = marker or (" •" if "BASELINE" in r.label else "")
        print(f"  {i+1:3d}  {r.label:50s}  {r.pod_yr30:5.1f}%  ${r.mean_total_fp_revenue:>11,.0f}  "
              f"{r.sharpe_like:6.3f}  ${r.mean_surplus_yr30:>11,.0f}  "
              f"${r.p1_surplus:>11,.0f}  ${r.fair_premium_loaded:>9,.0f}{marker}")

    print(f"\n--- ALL 50K VALIDATED (sorted by composite score) ---")
    print(f"  {'#':>3}  {'Label':50s}  {'PoD%':>6}  {'Sharpe':>7}  {'FP Rev':>12}  "
          f"{'Mean Surp':>12}  {'P1':>12}  {'LoanType':>8}  {'PSFreq':>6}")
    print("  " + "-" * 165)
    for i, r in enumerate(sorted(results_50k, key=lambda r: r._composite, reverse=True)):
        marker = " ★" if r.label == recommended.label else ""
        print(f"  {i+1:3d}  {r.label:50s}  {r.pod_yr30:5.1f}%  {r.sharpe_like:6.3f}  "
              f"${r.mean_total_fp_revenue:>11,.0f}  ${r.mean_surplus_yr30:>11,.0f}  "
              f"${r.p1_surplus:>11,.0f}  {r.loan_type:>8s}  {r.profit_share_years:>4d}yr{marker}")

    # ================================================================
    # FINAL COMPARISON
    # ================================================================
    if bl_50k and recommended:
        print(f"\n{'='*80}")
        print("FINAL COMPARISON: v14a BASELINE vs RECOMMENDED")
        print(f"{'='*80}")

        print(f"\n  {'Metric':40s}  {'v14a Baseline':>15s}  {'Recommended':>15s}  {'Change':>12s}")
        print("  " + "-" * 90)

        comparisons = [
            ("Configuration", "", "", ""),
            ("  Loan Type", bl_50k.loan_type, recommended.loan_type, ""),
            ("  Profit Share %", f"{bl_50k.profit_share_pct*100:.0f}%", f"{recommended.profit_share_pct*100:.0f}%", ""),
            ("  PS Frequency", f"every {bl_50k.profit_share_years}yr", f"every {recommended.profit_share_years}yr", ""),
            ("  Annuity Term", f"{bl_50k.annuity_term}yr", f"{recommended.annuity_term}yr", ""),
            ("  Collar Width", f"±{(bl_50k.buffer_cap-1)*100:.0f}%", f"±{(recommended.buffer_cap-1)*100:.0f}%", ""),
            ("  Holiday Entry", f"{bl_50k.holiday_entry:.2f}", f"{recommended.holiday_entry:.2f}", ""),
            ("  FP Margin", f"{bl_50k.fp_margin*100:.2f}%", f"{recommended.fp_margin*100:.2f}%", ""),
            ("", "", "", ""),
            ("Risk Metrics", "", "", ""),
            ("  PoD at Year 30", f"{bl_50k.pod_yr30:.1f}%", f"{recommended.pod_yr30:.1f}%",
             f"{recommended.pod_yr30 - bl_50k.pod_yr30:+.1f}pp"),
            ("  PoD at Year 15", f"{bl_50k.pod_yr15:.1f}%", f"{recommended.pod_yr15:.1f}%",
             f"{recommended.pod_yr15 - bl_50k.pod_yr15:+.1f}pp"),
            ("  PoD at Year 10", f"{bl_50k.pod_yr10:.1f}%", f"{recommended.pod_yr10:.1f}%",
             f"{recommended.pod_yr10 - bl_50k.pod_yr10:+.1f}pp"),
            ("  Mean Surplus Yr30", f"${bl_50k.mean_surplus_yr30:>12,.0f}", f"${recommended.mean_surplus_yr30:>12,.0f}",
             f"{(recommended.mean_surplus_yr30/max(bl_50k.mean_surplus_yr30,1) - 1)*100:+.0f}%"),
            ("  Median Surplus", f"${bl_50k.median_surplus:>12,.0f}", f"${recommended.median_surplus:>12,.0f}",
             f"{(recommended.median_surplus/max(bl_50k.median_surplus,1) - 1)*100:+.0f}%"),
            ("  P1 Surplus (worst)", f"${bl_50k.p1_surplus:>12,.0f}", f"${recommended.p1_surplus:>12,.0f}", ""),
            ("  P10 Surplus", f"${bl_50k.p10_surplus:>12,.0f}", f"${recommended.p10_surplus:>12,.0f}", ""),
            ("  Sharpe-like", f"{bl_50k.sharpe_like:.3f}", f"{recommended.sharpe_like:.3f}",
             f"{(recommended.sharpe_like/bl_50k.sharpe_like - 1)*100:+.0f}%"),
            ("  Cond. Expected Deficit", f"${bl_50k.cond_expected_deficit:>12,.0f}", f"${recommended.cond_expected_deficit:>12,.0f}", ""),
            ("  Insurance Premium", f"${bl_50k.fair_premium_loaded:>12,.0f}", f"${recommended.fair_premium_loaded:>12,.0f}",
             f"{(recommended.fair_premium_loaded/max(bl_50k.fair_premium_loaded,1) - 1)*100:+.0f}%"),
            ("", "", "", ""),
            ("Revenue Metrics", "", "", ""),
            ("  FP Total Revenue", f"${bl_50k.mean_total_fp_revenue:>12,.0f}", f"${recommended.mean_total_fp_revenue:>12,.0f}",
             f"{(recommended.mean_total_fp_revenue/bl_50k.mean_total_fp_revenue - 1)*100:+.0f}%"),
            ("    - Profit Share", f"${bl_50k.mean_total_profit_share:>12,.0f}", f"${recommended.mean_total_profit_share:>12,.0f}", ""),
            ("    - FP Margin", f"${bl_50k.mean_fp_margin_income:>12,.0f}", f"${recommended.mean_fp_margin_income:>12,.0f}", ""),
            ("  Funder Surplus Share", f"${bl_50k.mean_funder_surplus_share:>12,.0f}", f"${recommended.mean_funder_surplus_share:>12,.0f}",
             f"{(recommended.mean_funder_surplus_share/max(bl_50k.mean_funder_surplus_share,1) - 1)*100:+.0f}%"),
            ("  Revenue/Risk", f"${bl_50k.revenue_per_unit_risk:>12,.0f}", f"${recommended.revenue_per_unit_risk:>12,.0f}", ""),
            ("", "", "", ""),
            ("Borrower Metrics", "", "", ""),
            ("  Total Annuity Received", f"${bl_50k.total_annuity_received:>12,.0f}", f"${recommended.total_annuity_received:>12,.0f}", ""),
            ("  Final Loan Balance", f"${bl_50k.mean_final_loan_balance:>12,.0f}", f"${recommended.mean_final_loan_balance:>12,.0f}", ""),
            ("  Equity Protection", f"{bl_50k.mean_borrower_equity_return:.1f}%", f"{recommended.mean_borrower_equity_return:.1f}%", ""),
        ]

        for label, v1, v2, chg in comparisons:
            if not label:
                print()
            elif not v1 and not v2:
                print(f"\n  {label}")
            else:
                print(f"  {label:40s}  {v1:>15s}  {v2:>15s}  {chg:>12s}")

        print(f"\n  ★ Recommended: {recommended.label}")

    # Also compare with previous recommended
    if prev_rec_50k and bl_50k:
        print(f"\n\n--- Previous Recommended ({prev_rec_50k.label}) ---")
        print(f"  PoD: {prev_rec_50k.pod_yr30:.1f}%  |  FP Rev: ${prev_rec_50k.mean_total_fp_revenue:>11,.0f}  |  "
              f"Sharpe: {prev_rec_50k.sharpe_like:.3f}  |  Premium: ${prev_rec_50k.fair_premium_loaded:>9,.0f}")

    # ================================================================
    # KEY FINDINGS SUMMARY
    # ================================================================
    print(f"\n\n{'='*80}")
    print("KEY FINDINGS SUMMARY")
    print(f"{'='*80}")

    # P&I vs IO
    pi_baseline = next((r for r in results_p1 if r.label == "PI_at_baseline"), None)
    if pi_baseline:
        print(f"\n  1. LOAN TYPE (P&I vs IO):")
        print(f"     IO baseline: PoD={baseline.pod_yr30:.1f}%, Surplus=${baseline.mean_surplus_yr30:>11,.0f}")
        print(f"     P&I baseline: PoD={pi_baseline.pod_yr30:.1f}%, Surplus=${pi_baseline.mean_surplus_yr30:>11,.0f}")
        if pi_baseline.pod_yr30 < baseline.pod_yr30:
            print(f"     → P&I REDUCES risk by {baseline.pod_yr30 - pi_baseline.pod_yr30:.1f}pp")
        else:
            print(f"     → IO is better for risk (P&I adds {pi_baseline.pod_yr30 - baseline.pod_yr30:.1f}pp)")

    # PS Frequency
    ps25_3yr = next((r for r in results_p1 if r.label == "PS=25%_every3yr"), None)
    ps25_5yr = next((r for r in results_p1 if r.label == "PS=25%_every5yr"), None)
    if ps25_3yr and ps25_5yr:
        print(f"\n  2. PROFIT SHARE FREQUENCY:")
        print(f"     25% every 5yr: PoD={ps25_5yr.pod_yr30:.1f}%, FP Rev=${ps25_5yr.mean_total_fp_revenue:>11,.0f}")
        print(f"     25% every 3yr: PoD={ps25_3yr.pod_yr30:.1f}%, FP Rev=${ps25_3yr.mean_total_fp_revenue:>11,.0f}")
        if ps25_3yr.mean_total_fp_revenue > ps25_5yr.mean_total_fp_revenue:
            print(f"     → 3yr frequency generates ${ps25_3yr.mean_total_fp_revenue - ps25_5yr.mean_total_fp_revenue:>,.0f} more FP revenue")

    # Annuity term
    print(f"\n  3. ANNUITY TERM:")
    for term in [5, 7, 12, 15]:
        at_r = next((r for r in results_p1 if r.label == f"Annuity_{term}yr"), None)
        if at_r:
            print(f"     {term}yr: PoD={at_r.pod_yr30:.1f}%, Surplus=${at_r.mean_surplus_yr30:>11,.0f}, "
                  f"Annuity=${at_r.total_annuity_received:>9,.0f}")
    print(f"     10yr (baseline): PoD={baseline.pod_yr30:.1f}%, Surplus=${baseline.mean_surplus_yr30:>11,.0f}, "
          f"Annuity=${baseline.total_annuity_received:>9,.0f}")

    # ================================================================
    # SAVE RESULTS
    # ================================================================
    output = {
        'metadata': {
            'phase1_scenarios': len(results_p1),
            'phase2_scenarios': len(results_p2),
            'phase3_scenarios': len(results_50k),
            'phase1_paths': 10_000,
            'phase3_paths': 50_000,
            'seed': SEED,
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
            'total_time_seconds': round(time.time() - start + t1, 1),
            'new_levers': ['loan_type (P&I vs IO)', 'profit_share_frequency (3yr vs 5yr)',
                          'annuity_term', 'holiday_thresholds_fine'],
        },
        'baseline': asdict(bl_50k) if bl_50k else None,
        'recommended': asdict(recommended),
        'previous_recommended': asdict(prev_rec_50k) if prev_rec_50k else None,
        'pareto_front_50k': [asdict(r) for r in pareto_50k],
        'all_50k_validated': [asdict(r) for r in sorted(results_50k,
                              key=lambda r: r._composite, reverse=True)],
        'phase1_lever_results': {},
    }

    # Save lever analysis results
    lever_groups = {
        'loan_type': [r for r in results_p1 if 'PI_' in r.label or r.label == 'v14a_BASELINE'],
        'ps_frequency': [r for r in results_p1 if 'every3yr' in r.label or 'every5yr' in r.label],
        'annuity_term': [r for r in results_p1 if 'Annuity_' in r.label],
        'holiday_thresholds': [r for r in results_p1 if 'Holiday_' in r.label],
        'profit_share_pct': [r for r in results_p1 if r.label.startswith('PS=') and 'every' not in r.label],
        'collar_width': [r for r in results_p1 if r.label.startswith('Collar±')],
        'fp_margin': [r for r in results_p1 if r.label.startswith('FM=')],
    }
    for lever_name, lever_results in lever_groups.items():
        output['phase1_lever_results'][lever_name] = [asdict(r) for r in lever_results]

    # Clean up non-serializable attrs
    def clean_composite(d):
        d.pop('_composite', None)
        return d

    for key in ['recommended', 'baseline', 'previous_recommended']:
        if output.get(key):
            clean_composite(output[key])
    for lst_key in ['pareto_front_50k', 'all_50k_validated']:
        for d in output.get(lst_key, []):
            clean_composite(d)
    for lever_name in output.get('phase1_lever_results', {}):
        for d in output['phase1_lever_results'][lever_name]:
            clean_composite(d)

    with open('optimisation_v14a_comprehensive_results.json', 'w') as f:
        json.dump(output, f, indent=2)
    print(f"\n\nResults saved to optimisation_v14a_comprehensive_results.json")
    print(f"Total scenarios run: {len(results_p1) + len(results_p2) + len(results_50k)}")


if __name__ == '__main__':
    main()
