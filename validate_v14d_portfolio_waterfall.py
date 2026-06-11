#!/usr/bin/env python3
"""
v14d Optimised — INTERIM Python parallel implementation of Pavel's MC.

STATUS (2026-05-04, end of first attempt): VALIDATION FAILED.

Per-mortgage validation against Pavel's published 50k-path JSON outputs:
    Metric          Pavel (50k)         Python parallel (50k)        Diff
    PoD year-30     5.55%               38.18%                       33 pp too high
    mean surplus    $1,001,705          $2,233,776                   2.2x too high
    median surplus  $886,760            $1,055,212                   ~close
    p10 surplus     $181,044            -$2,612,801                  4-sigma off
    p90 surplus     $1,985,163          $8,394,450                   4x too wide

Diagnosis:
    The distribution my engine produces is much wider than Pavel's. The median
    is approximately right but the tails are 4x too extreme. This points at one
    or more of:
      (a) The asymmetric collar implementation — Pavel may apply it per-quarter
          differently from my [floor^(1/4), cap^(1/4)] interpretation; OR he
          applies it to a different quantity (e.g. cumulative return, not
          quarterly multiplier).
      (b) The cash-flow mechanics between loan / invest / annuity — multiple
          plausible interpretations exist for who pays what when. I tried two:
            - Loan capitalises freely; invest grows freely; net at year 30
            - Invest pays loan interest each quarter
          Neither matched.
      (c) The holiday mechanism — Pavel's holiday/repayment logic may be more
          aggressive at preventing tail losses than what's documented.
      (d) The equity model may mix in a fixed-income component; or the
          mean-reversion drift formulation may differ from mine.

Without a faithful per-mortgage engine, the portfolio-after-waterfall result
is not trustworthy. STOPPED. Holding for one of:
    - Pavel's 50k-path portfolio sim (the authoritative answer)
    - Pavel sharing the per-mortgage engine spec to allow parallel validation

This file is preserved as a starting point if/when more spec becomes available.
The portfolio simulation logic (Payments Waterfall implementation) is correct
in concept — it just feeds off the broken per-mortgage outputs at present.

Approach (intended):
    1. Load v14d Optimised parameters from monte_carlo_v14d_optimised_results.json
    2. Implement a vectorised numpy per-mortgage engine (quarterly steps)
    3. Validate per-mortgage outputs against Pavel's published 50k-path JSON
    4. If validation matches within ~10%, extend to portfolio with vintage staggering
    5. Apply Payments Waterfall at year 30 (cross-subsidy from open mortgages)
    6. Report portfolio-after-waterfall PoC
"""

import json
import os
import time
import numpy as np

ROOT = os.path.dirname(os.path.abspath(__file__))
JSON_PATH = os.path.join(ROOT, 'monte_carlo_v14d_optimised_results.json')

# Reproducibility
SEED = 42

# Simulation grid
N_PATHS_VALIDATE = 50_000      # for per-mortgage validation
N_PATHS_PORTFOLIO = 50_000     # for portfolio after-waterfall PoC
QUARTERS_PER_YEAR = 4
YEARS = 30
N_QUARTERS = YEARS * QUARTERS_PER_YEAR  # 120

# Portfolio composition
VINTAGES = 30                  # one cohort per year for 30 years
MORTGAGES_PER_VINTAGE = 1_000  # → 30,000 mortgages per portfolio


def load_parameters():
    with open(JSON_PATH) as f:
        data = json.load(f)
    return data


def load_v14d_targets():
    """Pavel's published v14d Optimised per-mortgage 50k-path outputs (the validation targets)."""
    with open(JSON_PATH) as f:
        d = json.load(f)
    return {
        'deficit_prob': d['deficit_prob'],     # 5.55 (%)
        'mean_surplus': d['mean_surplus'],     # 1,001,705
        'median_surplus': d['median_surplus'], # 886,760
        'p1': d['p1'],
        'p10': d['p10'],
        'p90': d['p90'],
        'p99': d['p99'],
        'n_paths': d['n_paths'],
    }


# ---------------------------------------------------------------------------
# v14d Optimised parameters (from JSON)
# ---------------------------------------------------------------------------
PARAMS = {
    # Mortgage
    'home_value':        1_500_000,
    'lvr':               0.80,
    'max_loan':          1_200_000,
    'initial_loan':      900_000,
    'tenure_years':      30,
    'annuity_pa':        30_000,
    'annuity_term':      10,        # years over which annuity is drawn
    # Equity model (GBM with mean-reversion drift, asymmetric collar)
    'equity_mean':       0.092,
    'equity_vol':        0.166,
    'equity_mean_rev':   0.163,     # mean-reversion speed of drift
    'buffer_cap':        1.4,       # cap on quarterly return multiplier (= +40% per year scaled)
    'buffer_floor':      0.8,       # floor (= -20%)
    # Cash rate (OU)
    'cash_rate_initial': 0.0421,
    'cash_rate_theta':   0.0213,
    'cash_rate_kappa':   0.24,
    'cash_rate_sigma':   0.0122,
    # Costs
    'wholesale_margin':  0.020,
    'retail_margin':     0.007,
    'hedging_fee':       0.0025,
    'fp_margin':         0.005,
    'lmi_upfront_pct':   0.0125,
    # Holiday
    'holiday_entry':     0.75,
    'holiday_exit':      1.458,
    # Correlation
    'correlation':       0.30,      # equity / cash rate
    # Profit share
    'profit_share_pct':  0.10,
    'profit_share_yrs':  3,
}


# ---------------------------------------------------------------------------
# Simulation building blocks (all vectorised over n_paths)
# ---------------------------------------------------------------------------

def simulate_cash_rate(n_paths, n_steps, dt, params, rng):
    """OU process for the cash rate (vectorised over paths). Exact discretisation."""
    theta = params['cash_rate_theta']
    kappa = params['cash_rate_kappa']
    sigma = params['cash_rate_sigma']
    r0 = params['cash_rate_initial']

    rate = np.empty((n_paths, n_steps + 1))
    rate[:, 0] = r0

    decay = np.exp(-kappa * dt)
    long_term = theta * (1 - decay)
    vol_step = sigma * np.sqrt((1 - np.exp(-2 * kappa * dt)) / (2 * kappa))

    z = rng.standard_normal(size=(n_paths, n_steps))
    for t in range(n_steps):
        rate[:, t + 1] = rate[:, t] * decay + long_term + vol_step * z[:, t]
    return rate, z


def simulate_equity(n_paths, n_steps, dt, params, rng, z_cash):
    """
    GBM with mean-reverting drift, correlated to cash rate via z_cash.
    Drift μ_t mean-reverts toward equity_mean at speed equity_mean_rev (γ).
    Quarterly returns are clipped to the asymmetric collar [floor, cap]^(1/4) per quarter.
    Returns: array of equity multipliers per quarter, shape (n_paths, n_steps).
    """
    mu_lt = params['equity_mean']
    sigma = params['equity_vol']
    gamma = params['equity_mean_rev']
    cap = params['buffer_cap']
    floor = params['buffer_floor']
    rho = params['correlation']

    # Drift OU-like at quarterly steps
    mu_decay = np.exp(-gamma * dt)
    mu_lt_step = mu_lt * (1 - mu_decay)
    mu_vol = 0.005 * np.sqrt(dt)  # drift-shock vol; small (Pavel's exact value not in JSON, this is a placeholder)

    # Correlated equity shocks
    z_indep = rng.standard_normal(size=(n_paths, n_steps))
    z_eq = rho * z_cash + np.sqrt(1 - rho ** 2) * z_indep

    # Path-level drift
    mu_t = np.full(n_paths, mu_lt)
    log_returns = np.empty((n_paths, n_steps))
    drift_shocks = rng.standard_normal(size=(n_paths, n_steps))

    for t in range(n_steps):
        # Step the drift
        mu_t = mu_t * mu_decay + mu_lt_step + mu_vol * drift_shocks[:, t]
        # Quarterly log return
        log_returns[:, t] = (mu_t - 0.5 * sigma ** 2) * dt + sigma * np.sqrt(dt) * z_eq[:, t]

    # Apply asymmetric collar to quarterly multiplier
    # Cap (1.4) and Floor (0.8) interpreted as ANNUAL bounds; quarter bounds = bound^(1/4)
    annual_mult = np.exp(log_returns * 4)  # annualised multiplier
    annual_mult_clipped = np.clip(annual_mult, floor, cap)
    log_returns_clipped = np.log(annual_mult_clipped) / 4

    multipliers = np.exp(log_returns_clipped)
    return multipliers


def simulate_per_mortgage(n_paths, params, rng_seed=SEED):
    """
    Vectorised per-mortgage simulation. Returns year-30 surplus distribution.

    Cash flow model (per-quarter):
      Year 0: invest = initial_loan ($900K), loan = initial_loan ($900K)

      Years 1-10 (annuity drawdown):
        - Loan grows by annuity_per_q (annuity drawn — added to loan principal)
        - Loan accrues interest at (cash_rate + spread) / 4
        - Invest pays the loan interest each quarter (invest -= interest)
        - Invest grows at equity_mult
        - Holiday: if invest/loan < 0.75 (entry) or < 1.458 (exit), pause annuity

      Years 11-30 (P&I amortisation):
        - Loan accrues interest at (cash_rate + spread) / 4
        - Invest pays the full P&I each quarter (invest -= principal + interest)
        - Loan reduces by principal portion
        - Invest grows at equity_mult

      Year 30: surplus = invest - loan_balance (loan should be ~0 after amort)
    """
    rng = np.random.default_rng(rng_seed)
    dt = 1.0 / QUARTERS_PER_YEAR

    cash_rate, z_cash = simulate_cash_rate(n_paths, N_QUARTERS, dt, params, rng)
    equity_mult = simulate_equity(n_paths, N_QUARTERS, dt, params, rng, z_cash)

    # Cash flow model (best interpretation given available info; differs from Pavel's
    # likely model — flagged in summary):
    #   - Year 0: loan = initial_loan ($900K), invest = initial_loan ($900K)
    #   - Each quarter: loan accrues interest (CAPITALISED into loan), invest grows at equity multiplier
    #   - Years 1-10: annuity drawn → loan grows by annuity (interest accrues separately on top)
    #   - Years 11-30: NO additional drawdown; loan amortises if invest can pay; otherwise loan keeps compounding
    #   - At year 30: surplus = invest - loan_balance
    # NB: in this model invest is NEVER deducted to pay loan interest or P&I — interest just capitalises.
    # This is the "loan compounds freely; invest grows freely; net at maturity" model.

    loan = np.full(n_paths, float(params['initial_loan']))
    invest = np.full(n_paths, float(params['initial_loan']))

    annuity_per_q = params['annuity_pa'] / QUARTERS_PER_YEAR
    annuity_quarters = params['annuity_term'] * QUARTERS_PER_YEAR

    # All-in loan spread above cash rate
    loan_spread = (params['wholesale_margin'] + params['retail_margin']
                   + params['hedging_fee'] + params['fp_margin'])

    # Upfront LMI deducted from invest
    lmi_premium = params['lmi_upfront_pct'] * params['max_loan']
    invest = invest - lmi_premium

    on_holiday = np.zeros(n_paths, dtype=bool)

    for q in range(N_QUARTERS):
        r_q = cash_rate[:, q]
        loan_rate_q = (r_q + loan_spread) / QUARTERS_PER_YEAR

        # Loan accrues interest (capitalised)
        loan = loan * (1 + loan_rate_q)

        # Invest grows at equity multiplier
        invest = invest * equity_mult[:, q]

        # Annuity drawdown during years 1-10
        if q < annuity_quarters:
            ratio = invest / np.maximum(loan, 1.0)
            on_holiday = np.where(on_holiday, ratio < params['holiday_exit'], ratio < params['holiday_entry'])
            draw = np.where(on_holiday, 0.0, annuity_per_q)
            loan = loan + draw

    surplus = invest - loan
    return {
        'surplus': surplus,
        'final_loan': loan,
        'final_invest': invest,
    }


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

def validate_per_mortgage():
    print("=" * 70)
    print("PHASE 1 — Per-mortgage validation against Pavel's 50k-path JSON")
    print("=" * 70)

    targets = load_v14d_targets()
    print(f"\nPavel's targets (n_paths = {targets['n_paths']:,}):")
    for k in ['deficit_prob', 'mean_surplus', 'median_surplus', 'p10', 'p90']:
        v = targets[k]
        if k == 'deficit_prob':
            print(f"  {k:18s}: {v:>12.2f}%")
        else:
            print(f"  {k:18s}: ${v:>15,.0f}")

    print(f"\nRunning Python implementation at N = {N_PATHS_VALIDATE:,} paths...")
    t0 = time.time()
    out = simulate_per_mortgage(N_PATHS_VALIDATE, PARAMS)
    elapsed = time.time() - t0
    print(f"  ({elapsed:.1f}s elapsed)")

    surplus = out['surplus']
    pod = (surplus < 0).mean() * 100
    mean = surplus.mean()
    median = np.median(surplus)
    p10 = np.percentile(surplus, 10)
    p90 = np.percentile(surplus, 90)

    print("\nPython implementation outputs:")
    print(f"  {'PoD year-30':18s}: {pod:>12.2f}% (target {targets['deficit_prob']:.2f}%)")
    print(f"  {'mean surplus':18s}: ${mean:>15,.0f} (target ${targets['mean_surplus']:>12,.0f})")
    print(f"  {'median surplus':18s}: ${median:>15,.0f} (target ${targets['median_surplus']:>12,.0f})")
    print(f"  {'p10 surplus':18s}: ${p10:>15,.0f} (target ${targets['p10']:>12,.0f})")
    print(f"  {'p90 surplus':18s}: ${p90:>15,.0f} (target ${targets['p90']:>12,.0f})")

    # Validation tolerance
    pod_diff_abs = abs(pod - targets['deficit_prob'])
    mean_diff_pct = abs(mean - targets['mean_surplus']) / abs(targets['mean_surplus']) * 100

    print(f"\nValidation deltas:")
    print(f"  PoD absolute diff:  {pod_diff_abs:.2f} pp (tolerance: 2 pp)")
    print(f"  mean surplus diff:  {mean_diff_pct:.1f}% (tolerance: 20%)")

    return out, targets, (pod_diff_abs <= 2 and mean_diff_pct <= 20)


# ---------------------------------------------------------------------------
# Portfolio + waterfall
# ---------------------------------------------------------------------------

def simulate_portfolio_waterfall(n_paths, params, rng_seed=SEED + 1):
    """
    Portfolio sim with vintage staggering and Payments Waterfall.

    Each portfolio MC path uses ONE shared equity + cash rate sequence.
    Within that path, mortgages of different vintages experience different
    SUBSEQUENCES of the sequence (vintage v sees quarters [v*4, v*4+120]).

    To avoid running 50k paths × 30 vintages × 120 quarters in nested loops,
    we generate one long equity/cash sequence per path (covering 30+30=60 years)
    and slice per-vintage. This captures the right correlation structure.
    """
    print("\n" + "=" * 70)
    print(f"PHASE 2 — Portfolio with Payments Waterfall, N = {n_paths:,} paths")
    print("=" * 70)

    rng = np.random.default_rng(rng_seed)
    dt = 1.0 / QUARTERS_PER_YEAR

    # Total horizon: 30 years for the OLDEST vintage to mature, plus 30 years of new
    # vintages joining annually. So we need 60 years of underlying sequence.
    total_quarters = 60 * QUARTERS_PER_YEAR

    print(f"Generating shared equity/cash sequences ({n_paths:,} paths × {total_quarters} quarters)...")
    t0 = time.time()
    cash_rate, z_cash = simulate_cash_rate(n_paths, total_quarters, dt, params, rng)
    equity_mult = simulate_equity(n_paths, total_quarters, dt, params, rng, z_cash)
    print(f"  ({time.time() - t0:.1f}s elapsed)")

    # We snapshot the portfolio at year 30 of operation.
    # Vintages: each is started at calendar year v (v = 0..29).
    # At calendar year 30: vintage 0 is age 30 (maturing), vintage 29 is age 1 (early).
    print(f"Computing per-vintage outcomes at year-30 snapshot...")
    t0 = time.time()

    annuity_per_q = params['annuity_pa'] / QUARTERS_PER_YEAR
    annuity_quarters = params['annuity_term'] * QUARTERS_PER_YEAR
    amort_quarters = (YEARS - params['annuity_term']) * QUARTERS_PER_YEAR
    amort_per_q = params['max_loan'] / amort_quarters
    loan_spread = (params['wholesale_margin'] + params['retail_margin']
                   + params['hedging_fee'] + params['fp_margin']
                   + params['lmi_upfront_pct'] / 30.0)

    # For each vintage, compute (loan_balance, invest_balance) at calendar year 30
    vintage_loan = np.zeros((VINTAGES, n_paths))
    vintage_invest = np.zeros((VINTAGES, n_paths))

    for v in range(VINTAGES):
        age_quarters = (YEARS - v) * QUARTERS_PER_YEAR  # how many quarters this vintage has aged by yr30
        # Skip if vintage hasn't started yet (shouldn't happen with v in 0..29)
        if age_quarters <= 0:
            continue

        loan = np.full(n_paths, float(params['initial_loan']))
        invest = np.full(n_paths, float(params['initial_loan']))
        on_holiday = np.zeros(n_paths, dtype=bool)
        q_start = v * QUARTERS_PER_YEAR

        for q_age in range(age_quarters):
            q_calendar = q_start + q_age
            r_q = cash_rate[:, q_calendar]
            loan_rate_q = (r_q + loan_spread) / QUARTERS_PER_YEAR
            loan = loan * (1 + loan_rate_q)
            invest = invest * equity_mult[:, q_calendar]

            if q_age < annuity_quarters:
                on_holiday = on_holiday & (invest / np.maximum(loan, 1.0) < params['holiday_exit'])
                on_holiday = on_holiday | (invest / np.maximum(loan, 1.0) < params['holiday_entry'])
                draw = np.where(on_holiday, 0.0, annuity_per_q)
                loan = loan + draw

            if q_age >= annuity_quarters:
                loan = np.maximum(loan - amort_per_q, 0.0)

        vintage_loan[v] = loan
        vintage_invest[v] = invest

    print(f"  ({time.time() - t0:.1f}s elapsed)")

    # Per-mortgage surplus by vintage at year-30 snapshot
    vintage_surplus = vintage_invest - vintage_loan  # shape (VINTAGES, n_paths)

    # PORTFOLIO COMPOSITION: MORTGAGES_PER_VINTAGE per vintage
    # Aggregate balance per portfolio path = sum_v (count_v × surplus_v_p)
    counts = np.full(VINTAGES, MORTGAGES_PER_VINTAGE)
    aggregate_balance = (counts[:, None] * vintage_surplus).sum(axis=0)

    # Vintage 0 = the maturing vintage (only this one triggers claims at year 30)
    maturing_per_path = vintage_surplus[0] * MORTGAGES_PER_VINTAGE  # total surplus/deficit for maturing cohort

    # Open vintages (1-29): can be cross-subsidy donors
    open_vintage_surplus = vintage_surplus[1:]  # shape (29, n_paths)
    # Available cross-subsidy = sum of POSITIVE surpluses on open mortgages (capped by their actual surplus)
    available_subsidy_per_path = (np.maximum(open_vintage_surplus, 0) * MORTGAGES_PER_VINTAGE).sum(axis=0)

    # WATERFALL:
    # Step 1: Each maturing mortgage uses its own investment account first
    #         (this is already reflected in vintage_surplus[0])
    # Step 2: For vintage-0 mortgages with deficits, draw from available subsidy across open vintages
    maturing_deficit_per_path = -np.minimum(maturing_per_path, 0)  # positive = $ of deficit needing claim
    residual_deficit_per_path = np.maximum(maturing_deficit_per_path - available_subsidy_per_path, 0)

    # Portfolio after-waterfall PoC = paths where residual deficit > 0
    poc_after_waterfall = (residual_deficit_per_path > 0).mean() * 100

    # For comparison, also compute the simpler "aggregate balance < 0"
    poc_aggregate_negative = (aggregate_balance < 0).mean() * 100

    # And the per-maturing-cohort PoC (no cross-subsidy)
    poc_no_waterfall = (maturing_per_path < 0).mean() * 100

    print(f"\nResults:")
    print(f"  Per-mortgage PoD (vintage 0, maturing): {(vintage_surplus[0] < 0).mean() * 100:.2f}%")
    print(f"  PoC if maturing cohort treated alone (no waterfall): {poc_no_waterfall:.2f}%")
    print(f"  Portfolio aggregate balance < 0 at year 30: {poc_aggregate_negative:.2f}%")
    print(f"  Portfolio after-waterfall PoC (residual deficit > 0): {poc_after_waterfall:.2f}%")

    # Standard error
    se = np.sqrt(poc_after_waterfall / 100 * (1 - poc_after_waterfall / 100) / n_paths) * 100
    print(f"  Standard error on after-waterfall PoC at N={n_paths:,}: {se:.3f}%")
    print(f"  95% CI: [{poc_after_waterfall - 1.96*se:.2f}%, {poc_after_waterfall + 1.96*se:.2f}%]")

    return {
        'poc_after_waterfall': poc_after_waterfall,
        'poc_aggregate_negative': poc_aggregate_negative,
        'poc_no_waterfall': poc_no_waterfall,
        'se': se,
        'vintage_surplus': vintage_surplus,
        'aggregate_balance': aggregate_balance,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == '__main__':
    print(f"\nv14d Optimised — INTERIM Python validation of portfolio after-waterfall PoC")
    print(f"Random seed: {SEED}")
    print(f"This is a PARALLEL implementation. Pavel's number remains authoritative.\n")

    validation_out, targets, ok = validate_per_mortgage()

    if not ok:
        print("\n⚠️  Per-mortgage validation OUTSIDE tolerance.")
        print("    The Python engine differs materially from Pavel's. The portfolio")
        print("    result below should be treated as illustrative only.")
    else:
        print("\n✓ Per-mortgage validation within tolerance. Proceeding to portfolio sim.")

    portfolio_out = simulate_portfolio_waterfall(N_PATHS_PORTFOLIO, PARAMS)

    print("\n" + "=" * 70)
    print("SUMMARY (interim, internal sense-check only — NOT for external use)")
    print("=" * 70)
    print(f"Pavel's published per-mortgage PoD year-30 (50k paths):  {targets['deficit_prob']:.2f}%")
    print(f"Python parallel per-mortgage PoD year-30 (50k paths):    {(validation_out['surplus'] < 0).mean() * 100:.2f}%")
    print(f"Python parallel PORTFOLIO after-waterfall PoC (50k):     {portfolio_out['poc_after_waterfall']:.2f}%")
    print(f"  (95% CI: [{portfolio_out['poc_after_waterfall'] - 1.96*portfolio_out['se']:.2f}%, {portfolio_out['poc_after_waterfall'] + 1.96*portfolio_out['se']:.2f}%])")
    print(f"\nFor comparison:")
    print(f"  v14d xlsm Portfolio sheet (1k paths) shows ~3.0% portfolio aggregate deficit prob")
    print(f"  v14c reports historically claimed < 0.01% — but that was the v14c calibration")
