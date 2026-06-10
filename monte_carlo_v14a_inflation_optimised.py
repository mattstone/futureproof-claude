#!/usr/bin/env python3
"""
Inflation-Indexed Annuity Analysis — FutureProof EPM v14a OPTIMISED
(Principal & Interest, Holiday Entry 1.05, Profit Share 20%/3yr)

Compares FLAT annuity ($25,000/year for 10 years) vs INFLATION-INDEXED annuity
using the optimised parameter set from constrained_v2 optimisation.

Both scenarios use identical random paths (same seed) for clean comparison.
"""

import numpy as np
import time
import json

# ============================================================
# v14a OPTIMISED PARAMETERS
# ============================================================
HOME_VALUE = 2_000_000
LVR = 0.80
INITIAL_LOAN = 1_350_000

TENURE_YEARS = 30
ANNUITY_PA = 25_000
ANNUITY_TERM_YEARS = 10
LOAN_TYPE = "PI"  # Principal & Interest (amortises after annuity term)

# Inflation scenarios
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

# OPTIMISED Holiday mechanism (higher entry = more protective)
HOLIDAY_ENTRY_LEVEL = 1.05   # was 0.9 in baseline
HOLIDAY_EXIT_LEVEL = 1.701   # was 1.458 in baseline

# OPTIMISED Profit share
PROFIT_SHARE_YEARS = 3       # was 5 in baseline
PROFIT_SHARE_PCT = 0.20      # was 0.25 in baseline

# Collar price for optimised buffer ±19%
COLLAR_PRICE = -0.001074     # was -0.003972 in baseline

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
    """Compute PI loan trajectory: builds up during annuity term, then amortises to 0."""
    loan = np.zeros(TENURE_YEARS + 1)
    loan[0] = INITIAL_LOAN

    # Phase 1: Annuity adds to mortgage
    for t in range(1, TENURE_YEARS + 1):
        if t <= ANNUITY_TERM_YEARS:
            loan[t] = loan[t - 1] + annuity_payments[t]
        else:
            loan[t] = loan[t - 1]

    # Phase 2: PI amortisation — linear paydown from peak to 0
    peak = loan[ANNUITY_TERM_YEARS]
    remaining_years = TENURE_YEARS - ANNUITY_TERM_YEARS  # 20 years
    if remaining_years > 0:
        annual_principal = peak / remaining_years
        for t in range(ANNUITY_TERM_YEARS + 1, TENURE_YEARS + 1):
            loan[t] = max(loan[t - 1] - annual_principal, 0)

    return loan


def run_scenario(inflation_rate, z1, z2, label):
    """Run optimised simulation for a given inflation rate."""
    annuity_payments = compute_annuity_schedule(inflation_rate)
    loan = compute_loan_trajectory(annuity_payments)

    total_annuity = sum(annuity_payments)
    MAX_LOAN = np.max(loan)
    upfront_LMI = MAX_LOAN * LMI_UPFRONT_PCT
    upfront_reinsurance = MAX_LOAN * REINSURANCE_UPFRONT_PCT

    # Holiday thresholds
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
    print(f"  Peak mortgage (Year 10): ${MAX_LOAN:,.0f}")
    print(f"  Mortgage at Year 30: ${loan[TENURE_YEARS]:,.0f}")
    print(f"  Annual principal repayment (Yr 11-30): ${MAX_LOAN / 20:,.0f}")
    print(f"  Upfront LMI: ${upfront_LMI:,.0f}")

    n = z1.shape[0]
    inv = np.full(n, INITIAL_LOAN - upfront_LMI - upfront_reinsurance, dtype=np.float64)
    cr = np.full(n, CASH_RATE_INITIAL, dtype=np.float64)

    hf = np.zeros(n, dtype=bool)
    hc = np.zeros(n, dtype=np.float64)
    ha = np.zeros(n, dtype=np.float64)
    rs = np.zeros(n, dtype=np.float64)
    fi_t = np.zeros(n, dtype=np.float64)
    ic_t = np.zeros(n, dtype=np.float64)

    yearly_surplus = np.zeros((n, TENURE_YEARS + 1))
    yearly_investment = np.zeros((n, TENURE_YEARS + 1))
    yearly_holidays = np.zeros((n, TENURE_YEARS))
    cum_ps = np.zeros(n)
    cum_fm = np.zeros(n)

    idef = np.zeros(n)
    yearly_surplus[:, 0] = inv - loan[0] + idef
    yearly_investment[:, 0] = inv.copy()

    inv *= (1 - COLLAR_PRICE)

    for t in range(1, TENURE_YEARS + 1):
        yi = t - 1

        # Cash rate: OU
        cr = (cr * np.exp(-CASH_RATE_KAPPA) +
              CASH_RATE_THETA * (1 - np.exp(-CASH_RATE_KAPPA)) +
              CASH_RATE_SIGMA * z2[:, yi])
        cr = np.maximum(cr, 0)

        # Investment returns with buffer
        raw = np.exp(EQUITY_MEAN + EQUITY_VOL * z1[:, yi]) - 1
        hedged = np.clip(raw, BUFFER_FLOOR - 1, BUFFER_CAP - 1)

        # Funder interest
        ffc = WHOLESALE_MARGIN + cr
        al = (loan[t - 1] + loan[t]) / 2
        fi = -ffc * al
        fi_t += fi

        # Holiday mechanism
        phf = hf.copy()
        phc = hc.copy()
        ent = (~phf) & (inv < holiday_entry_threshold)
        ext = phf & (inv > holiday_exit_threshold)
        sta = phf & (~ext)
        hf = ent | sta
        hc = np.where(hf, phc + 1, 0)
        yearly_holidays[:, yi] = hf.astype(float)

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

        rn = -RETAIL_MARGIN * al
        fp = -FP_MARGIN * inv
        hfee = -HEDGING_FEE * inv
        cum_fm += np.abs(fp)

        # Principal repayment (PI: after annuity term)
        pp = 0.0
        if t > ANNUITY_TERM_YEARS:
            pd = loan[t - 1] - loan[t]
            if pd > 0:
                pp = -pd  # deducted from investment

        if t == TENURE_YEARS:
            rn = -RETAIL_MARGIN * loan[t - 1] / 2
            ic = -ffc * loan[t - 1] / 2

        # Investment return
        ir = inv * hedged
        inv = inv + ir + ic + rn + fp + hfee + pp

        # Surplus
        surplus = inv - loan[t] + idef

        # Profit share (20% every 3 years)
        if t < TENURE_YEARS and t % PROFIT_SHARE_YEARS == 0:
            ps = np.where(surplus > 0, surplus * PROFIT_SHARE_PCT, 0)
            inv -= ps
            cum_ps += ps

        if t == TENURE_YEARS:
            wu = np.maximum(surplus, 0)
            inv -= wu

        if t < TENURE_YEARS:
            inv *= (1 - COLLAR_PRICE)

        yearly_surplus[:, t] = surplus
        yearly_investment[:, t] = inv

    # Compute results
    final_surplus = yearly_surplus[:, -1]
    final_deficit_prob = np.mean(final_surplus < 0) * 100
    se_deficit = np.sqrt(final_deficit_prob / 100 * (1 - final_deficit_prob / 100) / n) * 100

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
    print(f"  As % of peak mortgage: {100 * fair_premium_loaded / MAX_LOAN:.3f}%")

    print(f"\n  Profit share (total mean): ${np.mean(cum_ps):>12,.0f}")

    mean_holidays = np.mean(yearly_holidays, axis=0)

    # PoC by year table
    print(f"\n  --- PoC by Year ---")
    print(f"  {'Year':>4s}  {'PoC%':>8s}  {'P1':>12s}  {'P10':>12s}  {'Median':>12s}  {'P90':>12s}  {'P99':>12s}")
    for yr in [1, 5, 10, 15, 20, 25, 30]:
        s = yearly_surplus[:, yr]
        dp = np.mean(s < 0) * 100
        print(f"  {yr:4d}  {dp:7.2f}%  ${np.percentile(s, 1):>11,.0f}  ${np.percentile(s, 10):>11,.0f}  "
              f"${np.median(s):>11,.0f}  ${np.percentile(s, 90):>11,.0f}  ${np.percentile(s, 99):>11,.0f}")

    # Mortgage balance by year
    print(f"\n  --- Mortgage Balance (PI Amortisation) ---")
    for yr in [0, 5, 10, 15, 20, 25, 30]:
        print(f"  Year {yr:2d}: ${loan[yr]:>12,.0f}")

    return {
        'inflation_rate': inflation_rate,
        'label': label,
        'total_annuity': round(float(total_annuity), 0),
        'max_loan': round(float(MAX_LOAN), 0),
        'final_loan': round(float(loan[TENURE_YEARS]), 0),
        'annuity_schedule': [round(float(annuity_payments[t]), 0) for t in range(TENURE_YEARS + 1)],
        'loan_schedule': [round(float(loan[t]), 0) for t in range(TENURE_YEARS + 1)],
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
        'mean_profit_share': round(float(np.mean(cum_ps)), 0),
        'deficit_by_year': [round(d, 2) for d in deficit_by_year],
        'mean_holidays_per_year': [round(float(h), 3) for h in mean_holidays],
    }


def main():
    print(f"Running OPTIMISED inflation-indexed annuity analysis — {N_PATHS:,} paths")
    print(f"Model: PI mortgage, Holiday Entry 1.05, Profit Share 20%/3yr")
    start = time.time()

    rng = np.random.default_rng(SEED)
    z1 = rng.standard_normal((N_PATHS, TENURE_YEARS))
    z2_raw = rng.standard_normal((N_PATHS, TENURE_YEARS))
    rho = CASH_RATE_EQUITY_CORR
    z2 = rho * z1 + np.sqrt(1 - rho ** 2) * z2_raw

    # Run baseline (flat)
    baseline = run_scenario(0, z1, z2, "OPTIMISED BASELINE — Flat $25,000/year (PI)")

    # Run inflation-indexed scenarios
    indexed_results = []
    for rate in INFLATION_RATES:
        result = run_scenario(rate, z1, z2, f"Optimised Inflation-Indexed at {rate*100:.1f}% (PI)")
        indexed_results.append(result)

    elapsed = time.time() - start

    # ============================================================
    # COMPARISON TABLE
    # ============================================================
    print(f"\n\n{'='*90}")
    print("COMPARISON: FLAT vs INFLATION-INDEXED — OPTIMISED PI MODEL")
    print(f"{'='*90}")

    all_scenarios = [baseline] + indexed_results

    # Key metrics
    print(f"\n--- Key Risk Metrics ---")
    print(f"  {'Metric':<30s}", end="")
    for s in all_scenarios:
        lbl = 'Flat' if s['inflation_rate'] == 0 else f"{s['inflation_rate']*100:.0f}%"
        print(f"  {lbl:>14s}", end="")
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
                print(f"  {val:>13.2f}%", end="")
            elif fmt == '$':
                print(f"  ${val:>12,.0f}", end="")
            elif fmt == '#':
                print(f"  {val:>14,d}", end="")
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

    # Mortgage balance comparison
    print(f"\n--- Peak Mortgage & Amortisation ---")
    print(f"  {'Scenario':<20s}  {'Peak (Yr 10)':>14s}  {'Year 20':>14s}  {'Year 30':>14s}")
    for s in all_scenarios:
        lbl = 'Flat' if s['inflation_rate'] == 0 else f"{s['inflation_rate']*100:.0f}% Indexed"
        print(f"  {lbl:<20s}  ${s['loan_schedule'][10]:>13,.0f}  ${s['loan_schedule'][20]:>13,.0f}  ${s['loan_schedule'][30]:>13,.0f}")

    print(f"\nCompleted in {elapsed:.1f} seconds")

    # Save results
    output = {
        'analysis': 'Inflation-Indexed Annuity Impact — OPTIMISED PI Model',
        'model_version': 'v14a_optimised',
        'model_type': 'Principal & Interest',
        'optimisation_params': {
            'holiday_entry': HOLIDAY_ENTRY_LEVEL,
            'holiday_exit': HOLIDAY_EXIT_LEVEL,
            'profit_share_pct': PROFIT_SHARE_PCT,
            'profit_share_years': PROFIT_SHARE_YEARS,
            'collar_price': COLLAR_PRICE,
        },
        'n_paths': N_PATHS,
        'baseline': baseline,
        'inflation_scenarios': indexed_results,
    }

    with open('inflation_analysis_optimised_results.json', 'w') as f:
        json.dump(output, f, indent=2)
    print(f"Results saved to inflation_analysis_optimised_results.json")


if __name__ == '__main__':
    main()
