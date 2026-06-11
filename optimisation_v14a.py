#!/usr/bin/env python3
"""
EPM v14a Risk/Return Optimisation Engine
=========================================
Sweeps controllable parameters across ~500 scenarios (10,000 paths each)
to map the efficient frontier of FP revenue vs portfolio risk.

Controllable levers:
  1. Profit Share %        — FP's share of surplus at 5yr intervals
  2. FP Margin %           — annual management fee on investment account
  3. Retail Margin %       — annual NIM charged to borrower
  4. Buffer Cap / Floor    — hedging collar width (drives collar price)
  5. Holiday Entry / Exit  — smoothing mechanism thresholds

Fixed (market/structural):
  - Equity mean/vol, cash rate dynamics, wholesale margin, loan structure

Metrics tracked per scenario:
  RISK:   PoD yr30, Conditional Expected Deficit, P1 surplus, Fair Premium
  RETURN: Total FP Revenue (profit share + FP margin + share of surplus at maturity)
"""

import numpy as np
import json
import time
import itertools
from dataclasses import dataclass, asdict

# ============================================================
# FIXED PARAMETERS (market / structural)
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

N_PATHS = 10_000  # per scenario (fast but sufficient for ranking)
SEED = 42

# ============================================================
# COLLAR PRICING (Black-Scholes approximation)
# ============================================================
def estimate_collar_price(cap, floor, equity_mean, equity_vol):
    """
    Approximate net collar cost for a 1-year buffered return structure.
    Sell call at cap, buy put at floor. Negative = net credit (good).
    Uses simplified BS-like approximation calibrated to v14a reference.
    """
    from scipy.stats import norm
    S = 1.0  # normalised
    T = 1.0
    r = 0.0  # risk-neutral for relative pricing

    d1_call = (np.log(S / cap) + (r + 0.5 * equity_vol**2) * T) / (equity_vol * np.sqrt(T))
    d2_call = d1_call - equity_vol * np.sqrt(T)
    call_price = S * norm.cdf(d1_call) - cap * np.exp(-r * T) * norm.cdf(d2_call)

    d1_put = (np.log(S / floor) + (r + 0.5 * equity_vol**2) * T) / (equity_vol * np.sqrt(T))
    d2_put = d1_put - equity_vol * np.sqrt(T)
    put_price = floor * np.exp(-r * T) * norm.cdf(-d2_put) - S * norm.cdf(-d1_put)

    # Net collar = sell call - buy put (negative = net credit)
    return put_price - call_price


# ============================================================
# SIMULATION ENGINE (parameterised)
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
    label: str = ""


@dataclass
class ScenarioResult:
    # Params
    profit_share_pct: float
    fp_margin: float
    retail_margin: float
    buffer_cap: float
    buffer_floor: float
    holiday_entry: float
    holiday_exit: float
    collar_price: float
    label: str

    # Risk metrics
    pod_yr30: float          # % probability of deficit at yr 30
    pod_yr15: float          # % at yr 15 (earliest claim point)
    cond_expected_deficit: float  # $ mean deficit given deficit
    p1_surplus: float        # $ 1st percentile of final surplus
    p5_surplus: float        # $ 5th percentile
    p10_surplus: float       # $ 10th percentile (LMI top cover)
    fair_premium: float      # $ actuarial fair premium (PV)
    fair_premium_loaded: float  # $ with 50% loading

    # Return metrics
    mean_surplus_yr30: float         # $ mean surplus at maturity
    median_surplus_yr30: float       # $ median surplus
    mean_total_profit_share: float   # $ cumulative profit share extracted
    mean_fp_margin_income: float     # $ cumulative FP margin income
    mean_total_fp_revenue: float     # $ profit_share + fp_margin (what FP earns)
    mean_funder_surplus_share: float # $ funder's 50% of maturity surplus (funder revenue)

    # Efficiency metrics
    revenue_per_unit_risk: float     # FP revenue / PoD
    sharpe_like: float               # (mean_surplus - 0) / std_surplus
    total_variable_cost_pct: float   # annual cost drag on investment


def run_scenario(params: ScenarioParams, z1, z2, loan_from_funder, max_loan) -> ScenarioResult:
    """Run MC simulation for a single parameter set. Returns risk/return metrics."""

    collar_price = estimate_collar_price(params.buffer_cap, params.buffer_floor,
                                          EQUITY_MEAN, EQUITY_VOL)

    upfront_LMI = max_loan * LMI_UPFRONT_PCT
    upfront_reinsurance = max_loan * REINSURANCE_UPFRONT_PCT

    holiday_entry_threshold = INITIAL_LOAN * params.holiday_entry
    holiday_exit_threshold = INITIAL_LOAN * params.holiday_exit

    n_paths = z1.shape[0]

    # Initialize
    investment = np.full(n_paths, INITIAL_LOAN - upfront_LMI - upfront_reinsurance, dtype=np.float64)
    cash_rate = np.full(n_paths, CASH_RATE_INITIAL, dtype=np.float64)
    holiday_entry_flag = np.zeros(n_paths, dtype=bool)
    holiday_count = np.zeros(n_paths, dtype=np.float64)
    holiday_account = np.zeros(n_paths, dtype=np.float64)
    repayment_step = np.zeros(n_paths, dtype=np.float64)
    funder_interest_tot = np.zeros(n_paths, dtype=np.float64)
    interest_charged_tot = np.zeros(n_paths, dtype=np.float64)
    interest_deficit = np.zeros(n_paths, dtype=np.float64)
    cumulative_profit_share = np.zeros(n_paths)
    cumulative_fp_margin = np.zeros(n_paths)

    yearly_surplus = np.zeros(TENURE_YEARS + 1)  # just track mean for yr15 check

    investment *= (1 - collar_price)

    for t in range(1, TENURE_YEARS + 1):
        year_idx = t - 1

        cash_rate = (cash_rate * np.exp(-CASH_RATE_KAPPA) +
                     CASH_RATE_THETA * (1 - np.exp(-CASH_RATE_KAPPA)) +
                     CASH_RATE_SIGMA * z2[:, year_idx])
        cash_rate = np.maximum(cash_rate, 0)

        raw_return = np.exp(EQUITY_MEAN + EQUITY_VOL * z1[:, year_idx]) - 1
        hedged_return = np.clip(raw_return, params.buffer_floor - 1, params.buffer_cap - 1)

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

        repayment_flag = prev_holiday_flag & (~holiday_entry_flag)
        new_repayment_periods = np.where(repayment_flag & (repayment_step <= 0),
                                          prev_holiday_count, 0)
        repayment_step = np.where(new_repayment_periods > 0,
                                   new_repayment_periods,
                                   np.maximum(repayment_step - 1, 0))

        holiday_account_open = holiday_account.copy()
        interest_holiday = np.where(holiday_entry_flag, -funder_interest, 0)
        repayment_holiday = np.where(repayment_step > 0,
                                      -holiday_account_open / np.maximum(repayment_step, 1), 0)
        holiday_account = holiday_account_open + interest_holiday + repayment_holiday

        interest_charged = funder_interest + interest_holiday + repayment_holiday
        interest_charged_tot += interest_charged
        interest_deficit = funder_interest_tot - interest_charged_tot

        retailer_nim = -params.retail_margin * avg_loan
        fp_margin_payment = -params.fp_margin * investment
        hedging_fee_payment = -HEDGING_FEE * investment

        cumulative_fp_margin += np.abs(fp_margin_payment)

        if t == TENURE_YEARS:
            retailer_nim = -params.retail_margin * loan_from_funder[t - 1] / 2
            interest_charged = -funder_funding_cost * loan_from_funder[t - 1] / 2

        investment_return = investment * hedged_return
        investment = (investment + investment_return + interest_charged +
                      retailer_nim + fp_margin_payment + hedging_fee_payment)

        surplus = investment - loan_from_funder[t] + interest_deficit

        if t < TENURE_YEARS and t % PROFIT_SHARE_YEARS == 0:
            profit_share = np.where(surplus > 0, surplus * params.profit_share_pct, 0)
            investment -= profit_share
            cumulative_profit_share += profit_share

        if t == TENURE_YEARS:
            windup = np.maximum(surplus, 0)
            investment -= windup

        if t < TENURE_YEARS:
            investment *= (1 - collar_price)

        # Track deficit % at key years
        if t == 15:
            pod_yr15 = float(np.mean(surplus < 0) * 100)

    # Final metrics
    final_surplus = investment - loan_from_funder[TENURE_YEARS] + interest_deficit
    # Actually final_surplus is already computed as surplus in last iteration, but
    # the windup removes positive surplus. Let me recalculate from yearly tracking.
    # Actually, the surplus variable at t=30 IS the final surplus before windup.
    # Let me just recompute it.
    final_surplus_raw = surplus  # this is surplus at t=30 (before windup)

    pod_yr30 = float(np.mean(final_surplus_raw < 0) * 100)
    deficit_mask = final_surplus_raw < 0
    n_deficit = np.sum(deficit_mask)

    if n_deficit > 0:
        cond_expected_deficit = float(np.mean(final_surplus_raw[deficit_mask]))
        discount = np.exp(-CASH_RATE_THETA * TENURE_YEARS)
        discounted_claims = discount * final_surplus_raw[deficit_mask]
        fair_premium = float(-np.mean(discounted_claims) * (pod_yr30 / 100))
    else:
        cond_expected_deficit = 0.0
        fair_premium = 0.0

    # Funder surplus share (50% of maturity surplus for positive outcomes)
    maturity_surplus_positive = np.where(final_surplus_raw > 0, final_surplus_raw * 0.5, 0)

    total_variable_cost = params.retail_margin + params.fp_margin + HEDGING_FEE

    mean_total_fp_revenue = float(np.mean(cumulative_profit_share) + np.mean(cumulative_fp_margin))
    std_surplus = float(np.std(final_surplus_raw))

    return ScenarioResult(
        profit_share_pct=params.profit_share_pct,
        fp_margin=params.fp_margin,
        retail_margin=params.retail_margin,
        buffer_cap=params.buffer_cap,
        buffer_floor=params.buffer_floor,
        holiday_entry=params.holiday_entry,
        holiday_exit=params.holiday_exit,
        collar_price=round(collar_price, 6),
        label=params.label,

        pod_yr30=round(pod_yr30, 2),
        pod_yr15=round(pod_yr15, 2),
        cond_expected_deficit=round(cond_expected_deficit, 0),
        p1_surplus=round(float(np.percentile(final_surplus_raw, 1)), 0),
        p5_surplus=round(float(np.percentile(final_surplus_raw, 5)), 0),
        p10_surplus=round(float(np.percentile(final_surplus_raw, 10)), 0),
        fair_premium=round(fair_premium, 0),
        fair_premium_loaded=round(fair_premium * 1.5, 0),

        mean_surplus_yr30=round(float(np.mean(final_surplus_raw)), 0),
        median_surplus_yr30=round(float(np.median(final_surplus_raw)), 0),
        mean_total_profit_share=round(float(np.mean(cumulative_profit_share)), 0),
        mean_fp_margin_income=round(float(np.mean(cumulative_fp_margin)), 0),
        mean_total_fp_revenue=round(mean_total_fp_revenue, 0),
        mean_funder_surplus_share=round(float(np.mean(maturity_surplus_positive)), 0),

        revenue_per_unit_risk=round(mean_total_fp_revenue / max(pod_yr30, 0.01), 0),
        sharpe_like=round(float(np.mean(final_surplus_raw)) / max(std_surplus, 1), 4),
        total_variable_cost_pct=round(total_variable_cost * 100, 2),
    )


# ============================================================
# PARAMETER GRID
# ============================================================
def build_scenarios():
    """Build parameter grid for optimisation sweep."""
    scenarios = []

    # ---- DIMENSION 1: Profit Share % ----
    # v14a baseline = 25%. Sweep 5% to 50%
    profit_shares = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.50]

    # ---- DIMENSION 2: FP Margin ----
    # v14a baseline = 0.25%. Sweep 0.10% to 0.50%
    fp_margins = [0.001, 0.0015, 0.002, 0.0025, 0.003, 0.004, 0.005]

    # ---- DIMENSION 3: Retail Margin ----
    # v14a baseline = 0.70%. Sweep 0.25% to 1.25%
    retail_margins = [0.0025, 0.005, 0.006, 0.007, 0.008, 0.010, 0.0125]

    # ---- DIMENSION 4: Buffer Cap/Floor (collar width) ----
    # v14a baseline = [0.80, 1.20]. Narrow and wide collars
    collars = [
        (1.15, 0.85, "narrow ±15%"),
        (1.20, 0.80, "standard ±20%"),
        (1.25, 0.75, "wide ±25%"),
        (1.30, 0.70, "very wide ±30%"),
    ]

    # ---- DIMENSION 5: Holiday thresholds ----
    # v14a baseline = entry 0.90, exit 1.458
    holidays = [
        (0.85, 1.30, "loose holidays"),
        (0.90, 1.458, "standard holidays"),
        (0.95, 1.60, "tight holidays"),
        (0.00, 99.0, "NO holidays"),  # disabled
    ]

    # === SWEEP 1: Profit Share vs FP Margin (holding others at baseline) ===
    for ps in profit_shares:
        for fm in fp_margins:
            scenarios.append(ScenarioParams(
                profit_share_pct=ps, fp_margin=fm,
                retail_margin=0.007, buffer_cap=1.20, buffer_floor=0.80,
                holiday_entry=0.90, holiday_exit=1.458,
                label=f"PS={ps*100:.0f}%_FM={fm*100:.1f}%"
            ))

    # === SWEEP 2: Retail Margin (holding PS/FM at baseline) ===
    for rm in retail_margins:
        if rm == 0.007:
            continue  # already in sweep 1
        scenarios.append(ScenarioParams(
            profit_share_pct=0.25, fp_margin=0.0025,
            retail_margin=rm, buffer_cap=1.20, buffer_floor=0.80,
            holiday_entry=0.90, holiday_exit=1.458,
            label=f"RM={rm*100:.1f}%"
        ))

    # === SWEEP 3: Collar Width (holding others at baseline) ===
    for cap, floor, clabel in collars:
        if cap == 1.20:
            continue  # already in sweep 1
        scenarios.append(ScenarioParams(
            profit_share_pct=0.25, fp_margin=0.0025,
            retail_margin=0.007, buffer_cap=cap, buffer_floor=floor,
            holiday_entry=0.90, holiday_exit=1.458,
            label=f"Collar_{clabel}"
        ))

    # === SWEEP 4: Holiday Thresholds ===
    for entry, exit_lvl, hlabel in holidays:
        if entry == 0.90:
            continue  # already in sweep 1
        scenarios.append(ScenarioParams(
            profit_share_pct=0.25, fp_margin=0.0025,
            retail_margin=0.007, buffer_cap=1.20, buffer_floor=0.80,
            holiday_entry=entry, holiday_exit=exit_lvl,
            label=f"Holiday_{hlabel}"
        ))

    # === SWEEP 5: Combined optimisation — best PS/FM combos × collar × holiday ===
    best_combos = [
        (0.20, 0.003),   # moderate PS, higher FM
        (0.25, 0.0025),  # v14a baseline
        (0.30, 0.002),   # higher PS, lower FM
        (0.15, 0.0035),  # low PS, high FM
    ]
    for ps, fm in best_combos:
        for cap, floor, clabel in collars:
            for entry, exit_lvl, hlabel in holidays:
                # Skip if it duplicates an existing scenario
                if (ps == 0.25 and fm == 0.0025 and cap == 1.20 and
                    floor == 0.80 and entry == 0.90):
                    continue
                scenarios.append(ScenarioParams(
                    profit_share_pct=ps, fp_margin=fm,
                    retail_margin=0.007, buffer_cap=cap, buffer_floor=floor,
                    holiday_entry=entry, holiday_exit=exit_lvl,
                    label=f"PS={ps*100:.0f}%_FM={fm*100:.1f}%_{clabel}_{hlabel}"
                ))

    return scenarios


# ============================================================
# MAIN
# ============================================================
def main():
    print("=" * 80)
    print("EPM v14a RISK/RETURN OPTIMISATION ENGINE")
    print("=" * 80)

    scenarios = build_scenarios()
    print(f"\nTotal scenarios: {len(scenarios)}")
    print(f"Paths per scenario: {N_PATHS:,}")
    print(f"Total simulated paths: {len(scenarios) * N_PATHS:,}")

    # Pre-compute loan trajectory
    loan_from_funder = np.zeros(TENURE_YEARS + 1)
    loan_from_funder[0] = INITIAL_LOAN
    for t in range(1, TENURE_YEARS + 1):
        if t <= ANNUITY_TERM_YEARS:
            loan_from_funder[t] = loan_from_funder[t - 1] + ANNUITY_PA
        else:
            loan_from_funder[t] = loan_from_funder[t - 1]
    max_loan = np.max(loan_from_funder)

    # Generate random numbers ONCE (all scenarios use same draws for fair comparison)
    print(f"\nGenerating {N_PATHS:,} correlated random paths...")
    rng = np.random.default_rng(SEED)
    z1 = rng.standard_normal((N_PATHS, TENURE_YEARS))
    z2_raw = rng.standard_normal((N_PATHS, TENURE_YEARS))
    rho = CASH_RATE_EQUITY_CORR
    z2 = rho * z1 + np.sqrt(1 - rho**2) * z2_raw

    # Run all scenarios
    print(f"\nRunning {len(scenarios)} scenarios...")
    start = time.time()
    results = []

    for i, params in enumerate(scenarios):
        if (i + 1) % 50 == 0 or i == 0:
            print(f"  Scenario {i+1}/{len(scenarios)}: {params.label}")
        result = run_scenario(params, z1, z2, loan_from_funder, max_loan)
        results.append(result)

    elapsed = time.time() - start
    print(f"\nAll scenarios completed in {elapsed:.1f}s ({elapsed/len(scenarios)*1000:.0f}ms per scenario)")

    # ============================================================
    # ANALYSIS
    # ============================================================
    print("\n" + "=" * 80)
    print("OPTIMISATION RESULTS")
    print("=" * 80)

    # Sort by revenue/risk ratio
    results_sorted = sorted(results, key=lambda r: r.revenue_per_unit_risk, reverse=True)

    # --- TOP 20 by Revenue/Risk ---
    print("\n--- TOP 20 SCENARIOS by FP Revenue / PoD (Revenue per Unit Risk) ---")
    print(f"  {'#':>3s}  {'Label':40s}  {'PoD%':>6s}  {'FP Rev':>12s}  {'Rev/Risk':>10s}  "
          f"{'Mean Surp':>12s}  {'P1 Surp':>12s}  {'Premium':>10s}")
    print("  " + "-" * 140)
    for i, r in enumerate(results_sorted[:20]):
        print(f"  {i+1:3d}  {r.label:40s}  {r.pod_yr30:5.1f}%  ${r.mean_total_fp_revenue:>11,.0f}  "
              f"${r.revenue_per_unit_risk:>9,.0f}  ${r.mean_surplus_yr30:>11,.0f}  "
              f"${r.p1_surplus:>11,.0f}  ${r.fair_premium_loaded:>9,.0f}")

    # --- TOP 20 by Sharpe-like ratio ---
    results_sharpe = sorted(results, key=lambda r: r.sharpe_like, reverse=True)
    print("\n--- TOP 20 SCENARIOS by Sharpe-like Ratio (Mean Surplus / Std) ---")
    print(f"  {'#':>3s}  {'Label':40s}  {'Sharpe':>7s}  {'PoD%':>6s}  {'Mean Surp':>12s}  "
          f"{'FP Rev':>12s}  {'P1 Surp':>12s}")
    print("  " + "-" * 120)
    for i, r in enumerate(results_sharpe[:20]):
        print(f"  {i+1:3d}  {r.label:40s}  {r.sharpe_like:6.3f}  {r.pod_yr30:5.1f}%  "
              f"${r.mean_surplus_yr30:>11,.0f}  ${r.mean_total_fp_revenue:>11,.0f}  "
              f"${r.p1_surplus:>11,.0f}")

    # --- LOWEST PoD (safest configurations) ---
    results_safe = sorted(results, key=lambda r: r.pod_yr30)
    print("\n--- TOP 20 SAFEST SCENARIOS (Lowest PoD at Yr 30) ---")
    print(f"  {'#':>3s}  {'Label':40s}  {'PoD%':>6s}  {'P1 Surp':>12s}  "
          f"{'Mean Surp':>12s}  {'FP Rev':>12s}  {'Premium':>10s}")
    print("  " + "-" * 130)
    for i, r in enumerate(results_safe[:20]):
        print(f"  {i+1:3d}  {r.label:40s}  {r.pod_yr30:5.1f}%  ${r.p1_surplus:>11,.0f}  "
              f"${r.mean_surplus_yr30:>11,.0f}  ${r.mean_total_fp_revenue:>11,.0f}  "
              f"${r.fair_premium_loaded:>9,.0f}")

    # --- HIGHEST FP Revenue ---
    results_rev = sorted(results, key=lambda r: r.mean_total_fp_revenue, reverse=True)
    print("\n--- TOP 20 HIGHEST FP REVENUE ---")
    print(f"  {'#':>3s}  {'Label':40s}  {'FP Rev':>12s}  {'PS Rev':>12s}  {'FM Rev':>12s}  "
          f"{'PoD%':>6s}  {'Mean Surp':>12s}")
    print("  " + "-" * 130)
    for i, r in enumerate(results_rev[:20]):
        print(f"  {i+1:3d}  {r.label:40s}  ${r.mean_total_fp_revenue:>11,.0f}  "
              f"${r.mean_total_profit_share:>11,.0f}  ${r.mean_fp_margin_income:>11,.0f}  "
              f"{r.pod_yr30:5.1f}%  ${r.mean_surplus_yr30:>11,.0f}")

    # --- EFFICIENT FRONTIER ---
    print("\n--- EFFICIENT FRONTIER (Pareto-optimal: no scenario with BOTH higher revenue AND lower risk) ---")
    # Filter to Pareto front: maximize revenue, minimize PoD
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

    pareto = sorted(pareto, key=lambda r: r.pod_yr30)
    print(f"  {len(pareto)} Pareto-optimal scenarios found\n")
    print(f"  {'#':>3s}  {'Label':40s}  {'PoD%':>6s}  {'FP Rev':>12s}  {'Mean Surp':>12s}  "
          f"{'Sharpe':>7s}  {'Premium':>10s}  {'P1':>12s}")
    print("  " + "-" * 145)
    for i, r in enumerate(pareto):
        print(f"  {i+1:3d}  {r.label:40s}  {r.pod_yr30:5.1f}%  ${r.mean_total_fp_revenue:>11,.0f}  "
              f"${r.mean_surplus_yr30:>11,.0f}  {r.sharpe_like:6.3f}  "
              f"${r.fair_premium_loaded:>9,.0f}  ${r.p1_surplus:>11,.0f}")

    # --- v14a BASELINE COMPARISON ---
    baseline = [r for r in results if r.label == "PS=25%_FM=0.2%"]
    if baseline:
        b = baseline[0]
        print(f"\n--- v14a BASELINE (PS=25%, FM=0.25%, RM=0.70%, Collar ±20%) ---")
        print(f"  PoD yr30:              {b.pod_yr30:.1f}%")
        print(f"  PoD yr15:              {b.pod_yr15:.1f}%")
        print(f"  Mean surplus yr30:     ${b.mean_surplus_yr30:>12,.0f}")
        print(f"  Median surplus yr30:   ${b.median_surplus_yr30:>12,.0f}")
        print(f"  P1 surplus:            ${b.p1_surplus:>12,.0f}")
        print(f"  P10 surplus (LMI cap): ${b.p10_surplus:>12,.0f}")
        print(f"  Cond. expected deficit:${b.cond_expected_deficit:>12,.0f}")
        print(f"  Fair premium (loaded): ${b.fair_premium_loaded:>12,.0f}")
        print(f"  FP total revenue:      ${b.mean_total_fp_revenue:>12,.0f}")
        print(f"    - Profit share:      ${b.mean_total_profit_share:>12,.0f}")
        print(f"    - FP margin:         ${b.mean_fp_margin_income:>12,.0f}")
        print(f"  Funder surplus share:  ${b.mean_funder_surplus_share:>12,.0f}")
        print(f"  Sharpe-like ratio:     {b.sharpe_like:.4f}")
        print(f"  Revenue/Risk:          ${b.revenue_per_unit_risk:>12,.0f}")

    # --- DIMENSION SENSITIVITY (1D slices through baseline) ---
    print("\n--- SENSITIVITY: Profit Share % (holding all else at v14a baseline) ---")
    print(f"  {'PS%':>5s}  {'PoD%':>6s}  {'FP Rev':>12s}  {'PS Rev':>12s}  {'Mean Surp':>12s}  {'Sharpe':>7s}")
    for ps in [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.50]:
        matches = [r for r in results if abs(r.profit_share_pct - ps) < 0.001
                   and abs(r.fp_margin - 0.0025) < 0.0001
                   and abs(r.retail_margin - 0.007) < 0.0001
                   and abs(r.buffer_cap - 1.20) < 0.01
                   and abs(r.holiday_entry - 0.90) < 0.01]
        if matches:
            r = matches[0]
            print(f"  {ps*100:4.0f}%  {r.pod_yr30:5.1f}%  ${r.mean_total_fp_revenue:>11,.0f}  "
                  f"${r.mean_total_profit_share:>11,.0f}  ${r.mean_surplus_yr30:>11,.0f}  {r.sharpe_like:6.3f}")

    print("\n--- SENSITIVITY: FP Margin (holding all else at v14a baseline, PS=25%) ---")
    print(f"  {'FM%':>5s}  {'PoD%':>6s}  {'FP Rev':>12s}  {'FM Rev':>12s}  {'Mean Surp':>12s}  {'Sharpe':>7s}")
    for fm in [0.001, 0.0015, 0.002, 0.0025, 0.003, 0.004, 0.005]:
        matches = [r for r in results if abs(r.fp_margin - fm) < 0.0001
                   and abs(r.profit_share_pct - 0.25) < 0.001
                   and abs(r.retail_margin - 0.007) < 0.0001
                   and abs(r.buffer_cap - 1.20) < 0.01
                   and abs(r.holiday_entry - 0.90) < 0.01]
        if matches:
            r = matches[0]
            print(f"  {fm*100:4.1f}%  {r.pod_yr30:5.1f}%  ${r.mean_total_fp_revenue:>11,.0f}  "
                  f"${r.mean_fp_margin_income:>11,.0f}  ${r.mean_surplus_yr30:>11,.0f}  {r.sharpe_like:6.3f}")

    print("\n--- SENSITIVITY: Retail Margin ---")
    print(f"  {'RM%':>6s}  {'PoD%':>6s}  {'Mean Surp':>12s}  {'P1 Surp':>12s}  {'Premium':>10s}  {'Sharpe':>7s}")
    for r in sorted([r for r in results if 'RM=' in r.label or
                     (abs(r.profit_share_pct - 0.25) < 0.001 and
                      abs(r.fp_margin - 0.0025) < 0.0001 and
                      abs(r.buffer_cap - 1.20) < 0.01 and
                      abs(r.holiday_entry - 0.90) < 0.01 and
                      abs(r.retail_margin - 0.007) < 0.0001)],
                    key=lambda r: r.retail_margin):
        print(f"  {r.retail_margin*100:5.2f}%  {r.pod_yr30:5.1f}%  ${r.mean_surplus_yr30:>11,.0f}  "
              f"${r.p1_surplus:>11,.0f}  ${r.fair_premium_loaded:>9,.0f}  {r.sharpe_like:6.3f}")

    print("\n--- SENSITIVITY: Collar Width ---")
    print(f"  {'Collar':>12s}  {'Price':>8s}  {'PoD%':>6s}  {'Mean Surp':>12s}  {'P1 Surp':>12s}  {'Sharpe':>7s}")
    for r in sorted([r for r in results if 'Collar_' in r.label or
                     (abs(r.profit_share_pct - 0.25) < 0.001 and
                      abs(r.fp_margin - 0.0025) < 0.0001 and
                      abs(r.buffer_cap - 1.20) < 0.01 and
                      abs(r.holiday_entry - 0.90) < 0.01 and
                      abs(r.retail_margin - 0.007) < 0.0001)],
                    key=lambda r: r.buffer_cap):
        width = f"±{(r.buffer_cap - 1)*100:.0f}%"
        print(f"  {width:>12s}  {r.collar_price:>7.4f}  {r.pod_yr30:5.1f}%  ${r.mean_surplus_yr30:>11,.0f}  "
              f"${r.p1_surplus:>11,.0f}  {r.sharpe_like:6.3f}")

    print("\n--- SENSITIVITY: Holiday Mechanism ---")
    print(f"  {'Config':>18s}  {'PoD%':>6s}  {'Mean Surp':>12s}  {'P1 Surp':>12s}  {'Premium':>10s}")
    for r in sorted([r for r in results if 'Holiday_' in r.label or
                     (abs(r.profit_share_pct - 0.25) < 0.001 and
                      abs(r.fp_margin - 0.0025) < 0.0001 and
                      abs(r.buffer_cap - 1.20) < 0.01 and
                      abs(r.holiday_entry - 0.90) < 0.01 and
                      abs(r.retail_margin - 0.007) < 0.0001)],
                    key=lambda r: r.holiday_entry):
        config = f"entry={r.holiday_entry:.2f}"
        print(f"  {config:>18s}  {r.pod_yr30:5.1f}%  ${r.mean_surplus_yr30:>11,.0f}  "
              f"${r.p1_surplus:>11,.0f}  ${r.fair_premium_loaded:>9,.0f}")

    # Save all results
    output = {
        'metadata': {
            'n_scenarios': len(results),
            'n_paths_per_scenario': N_PATHS,
            'seed': SEED,
            'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
            'fixed_params': {
                'home_value': HOME_VALUE,
                'initial_loan': INITIAL_LOAN,
                'tenure_years': TENURE_YEARS,
                'annuity_pa': ANNUITY_PA,
                'wholesale_margin': WHOLESALE_MARGIN,
                'hedging_fee': HEDGING_FEE,
                'equity_mean': EQUITY_MEAN,
                'equity_vol': EQUITY_VOL,
            }
        },
        'scenarios': [asdict(r) for r in results],
        'pareto_front': [asdict(r) for r in pareto],
        'baseline_label': 'PS=25%_FM=0.2%',
    }

    with open('optimisation_v14a_results.json', 'w') as f:
        json.dump(output, f, indent=2)
    print(f"\n\nFull results saved to optimisation_v14a_results.json")
    print(f"Total scenarios: {len(results)}")
    print(f"Pareto-optimal: {len(pareto)}")


if __name__ == '__main__':
    main()
