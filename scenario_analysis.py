#!/usr/bin/env python3
"""
Scenario Analysis — Testing two portfolio-level parameter changes:

Scenario 1: Loan term mix — remove 15yr terms
  Baseline: 25% each of 15, 20, 25, 30 year terms
  Test:     0% 15yr, 33.3% each of 20, 25, 30 year terms

Scenario 2: Top Cover Limit (LMI threshold)
  Baseline: Worst 10% quantile (P10)
  Test A:   Worst 20% quantile (P20)
  Test B:   Worst 30% quantile (P30)

Uses the v14a Monte Carlo engine with 50,000 paths per tenure.
"""

import numpy as np
import time
import json

# ============================================================
# v14a PARAMETERS (from FutureProofCalculator_Pavel_v14a.xlsm)
# ============================================================
HOME_VALUE = 2_000_000
LVR = 0.80
INITIAL_LOAN = 1_350_000

ANNUITY_PA = 25_000
ANNUITY_TERM_YEARS = 10

WHOLESALE_MARGIN = 0.02
RETAIL_MARGIN = 0.007
HEDGING_FEE = 0.0025
FP_MARGIN = 0.0025
LMI_UPFRONT_PCT = 0.016
REINSURANCE_UPFRONT_PCT = 0.001

EQUITY_MEAN = 0.10
EQUITY_VOL = 0.10
BUFFER_CAP = 1.20
BUFFER_FLOOR = 0.80

CASH_RATE_INITIAL = 0.044
CASH_RATE_THETA = 0.044
CASH_RATE_KAPPA = 0.80
CASH_RATE_SIGMA = 0.015
CASH_RATE_EQUITY_CORR = 0.069

HOLIDAY_ENTRY_LEVEL = 0.9
HOLIDAY_EXIT_LEVEL = 1.458

PROFIT_SHARE_YEARS = 5
PROFIT_SHARE_PCT = 0.25

N_PATHS = 50_000
SEED = 42
COLLAR_PRICE = -0.003972


def run_single_tenure(tenure_years, seed=42):
    """Run the full MC simulation for a single loan tenure. Returns per-path final surplus array."""
    rng = np.random.default_rng(seed)

    # Loan trajectory
    loan_from_funder = np.zeros(tenure_years + 1)
    loan_from_funder[0] = INITIAL_LOAN
    for t in range(1, tenure_years + 1):
        if t <= ANNUITY_TERM_YEARS:
            loan_from_funder[t] = loan_from_funder[t - 1] + ANNUITY_PA
        else:
            loan_from_funder[t] = loan_from_funder[t - 1]

    MAX_LOAN = np.max(loan_from_funder)
    upfront_LMI = MAX_LOAN * LMI_UPFRONT_PCT
    upfront_reinsurance = MAX_LOAN * REINSURANCE_UPFRONT_PCT

    holiday_entry_threshold = INITIAL_LOAN * HOLIDAY_ENTRY_LEVEL
    holiday_exit_threshold = INITIAL_LOAN * HOLIDAY_EXIT_LEVEL

    # Random draws
    z1 = rng.standard_normal((N_PATHS, tenure_years))
    z2_raw = rng.standard_normal((N_PATHS, tenure_years))
    rho = CASH_RATE_EQUITY_CORR
    z2 = rho * z1 + np.sqrt(1 - rho**2) * z2_raw

    # State arrays
    investment = np.full(N_PATHS, INITIAL_LOAN - upfront_LMI - upfront_reinsurance, dtype=np.float64)
    cash_rate = np.full(N_PATHS, CASH_RATE_INITIAL, dtype=np.float64)
    holiday_entry_flag = np.zeros(N_PATHS, dtype=bool)
    holiday_count = np.zeros(N_PATHS, dtype=np.float64)
    holiday_account = np.zeros(N_PATHS, dtype=np.float64)
    repayment_step = np.zeros(N_PATHS, dtype=np.float64)
    funder_interest_tot = np.zeros(N_PATHS, dtype=np.float64)
    interest_charged_tot = np.zeros(N_PATHS, dtype=np.float64)

    yearly_surplus = np.zeros((N_PATHS, tenure_years + 1))
    yearly_surplus[:, 0] = investment - loan_from_funder[0]

    investment *= (1 - COLLAR_PRICE)

    for t in range(1, tenure_years + 1):
        year_idx = t - 1

        cash_rate = (cash_rate * np.exp(-CASH_RATE_KAPPA) +
                     CASH_RATE_THETA * (1 - np.exp(-CASH_RATE_KAPPA)) +
                     CASH_RATE_SIGMA * z2[:, year_idx])
        cash_rate = np.maximum(cash_rate, 0)

        raw_return = np.exp(EQUITY_MEAN + EQUITY_VOL * z1[:, year_idx]) - 1
        hedged_return = np.clip(raw_return, BUFFER_FLOOR - 1, BUFFER_CAP - 1)

        funder_funding_cost = WHOLESALE_MARGIN + cash_rate
        avg_loan = (loan_from_funder[t - 1] + loan_from_funder[t]) / 2
        funder_interest = -funder_funding_cost * avg_loan
        funder_interest_tot += funder_interest

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
                                     -holiday_account_open / np.maximum(repayment_step, 1),
                                     0)
        holiday_account = holiday_account_open + interest_holiday + repayment_holiday

        interest_charged = funder_interest + interest_holiday + repayment_holiday
        interest_charged_tot += interest_charged
        interest_deficit = funder_interest_tot - interest_charged_tot

        retailer_nim = -RETAIL_MARGIN * avg_loan
        fp_margin_payment = -FP_MARGIN * investment
        hedging_fee_payment = -HEDGING_FEE * investment

        if t == tenure_years:
            retailer_nim = -RETAIL_MARGIN * loan_from_funder[t - 1] / 2
            interest_charged = -funder_funding_cost * loan_from_funder[t - 1] / 2

        investment_return = investment * hedged_return
        investment = (investment + investment_return + interest_charged +
                      retailer_nim + fp_margin_payment + hedging_fee_payment)

        surplus = investment - loan_from_funder[t] + interest_deficit

        if t < tenure_years and t % PROFIT_SHARE_YEARS == 0:
            profit_share = np.where(surplus > 0, surplus * PROFIT_SHARE_PCT, 0)
            investment -= profit_share

        if t == tenure_years:
            windup = np.maximum(surplus, 0)
            investment -= windup

        if t < tenure_years:
            investment *= (1 - COLLAR_PRICE)

        yearly_surplus[:, t] = surplus

    return yearly_surplus


def analyse_surplus(final_surplus, label=""):
    """Compute key metrics from final surplus array."""
    n = len(final_surplus)
    deficit_prob = np.mean(final_surplus < 0) * 100
    se = np.sqrt(deficit_prob / 100 * (1 - deficit_prob / 100) / n) * 100
    mean_s = np.mean(final_surplus)
    median_s = np.median(final_surplus)

    percentiles = {}
    for p in [1, 5, 10, 20, 25, 30, 50, 75, 90, 95, 99]:
        percentiles[f'p{p}'] = np.percentile(final_surplus, p)

    # Insurance
    discount = np.exp(-CASH_RATE_THETA * 30)  # always discount over 30yr
    deficit_mask = final_surplus < 0
    n_deficit = np.sum(deficit_mask)
    if n_deficit > 0:
        fair_premium = -np.mean(discount * final_surplus[deficit_mask]) * (deficit_prob / 100)
        cond_deficit = np.mean(final_surplus[deficit_mask])
    else:
        fair_premium = 0
        cond_deficit = 0

    loaded_premium = fair_premium * 1.5
    MAX_LOAN = INITIAL_LOAN + ANNUITY_PA * min(ANNUITY_TERM_YEARS, 30)
    premium_pct = 100 * loaded_premium / MAX_LOAN

    return {
        'label': label,
        'n_paths': n,
        'deficit_prob': deficit_prob,
        'se': se,
        'mean_surplus': mean_s,
        'median_surplus': median_s,
        'cond_deficit': cond_deficit,
        'fair_premium': fair_premium,
        'loaded_premium': loaded_premium,
        'premium_pct_of_loan': premium_pct,
        'percentiles': percentiles,
    }


def portfolio_poc(tenure_results, weights):
    """
    Estimate portfolio PoC using the Payments Waterfall logic.
    Mortgages expiring in surplus cross-subsidise those in deficit.

    For each simulated 'cohort', we:
    1. Sort loans by surplus (ascending)
    2. Apply cross-subsidisation: surplus from profitable loans offsets deficit loans
    3. Count residual claims after waterfall
    """
    # We need to simulate a portfolio draw. For each path, draw one mortgage per tenure.
    # But since paths are independent, we use a resampling approach:
    # draw N_PATHS portfolio snapshots, each with one loan per tenure weighted by mix.

    rng = np.random.default_rng(99)
    n_portfolio_sims = 50_000
    n_loans_per_portfolio = 100  # simulate 100-loan portfolios

    # Build a pool of final surpluses by tenure, weighted
    tenures = list(tenure_results.keys())
    cum_weights = np.cumsum([weights[t] for t in tenures])

    poc_claims = 0
    poc_total = 0

    for _ in range(n_portfolio_sims):
        # Draw n_loans_per_portfolio loans from the tenure mix
        draws = rng.random(n_loans_per_portfolio)
        surpluses = np.zeros(n_loans_per_portfolio)
        for i, d in enumerate(draws):
            for j, t in enumerate(tenures):
                if d <= cum_weights[j]:
                    idx = rng.integers(0, len(tenure_results[t]))
                    surpluses[i] = tenure_results[t][idx]
                    break

        # Payments Waterfall: sort, cumsum
        sorted_surpluses = np.sort(surpluses)
        cumulative = np.cumsum(sorted_surpluses)

        # After waterfall, a claim occurs only for loans still in deficit
        # after all surplus from other loans has been applied
        total_surplus = np.sum(surpluses)
        if total_surplus < 0:
            # Entire portfolio in deficit — all deficit loans claim
            claims = np.sum(surpluses < 0)
        else:
            # Count how many loans remain in deficit after cross-subsidisation
            # Walk from worst to best: each deficit loan is offset by remaining pool surplus
            pool_surplus = total_surplus
            claims = 0
            for s in sorted_surpluses:
                if s < 0:
                    if pool_surplus + s < 0:
                        claims += 1
                    pool_surplus = max(pool_surplus + s, 0)
                else:
                    break

        poc_claims += claims
        poc_total += n_loans_per_portfolio

    poc = 100 * poc_claims / poc_total
    return poc


def print_results(metrics, poc=None):
    """Pretty-print results for a scenario."""
    print(f"\n  {'Metric':<30s} {'Value':>15s}")
    print(f"  {'─' * 46}")
    print(f"  {'PoD (deficit prob)':<30s} {metrics['deficit_prob']:>14.2f}%")
    print(f"  {'SE on PoD':<30s} {metrics['se']:>14.2f}%")
    if poc is not None:
        print(f"  {'Portfolio PoC':<30s} {poc:>14.2f}%")
    print(f"  {'Mean surplus':<30s} ${metrics['mean_surplus']:>13,.0f}")
    print(f"  {'Median surplus':<30s} ${metrics['median_surplus']:>13,.0f}")
    print(f"  {'Cond. expected deficit':<30s} ${metrics['cond_deficit']:>13,.0f}")
    print(f"  {'Fair premium (PV)':<30s} ${metrics['fair_premium']:>13,.0f}")
    print(f"  {'Loaded premium (1.5x)':<30s} ${metrics['loaded_premium']:>13,.0f}")
    print(f"  {'Premium as % of max loan':<30s} {metrics['premium_pct_of_loan']:>14.3f}%")
    print(f"\n  {'Percentile Distribution:'}")
    for k in ['p1', 'p5', 'p10', 'p20', 'p25', 'p30', 'p50', 'p75', 'p90', 'p95', 'p99']:
        print(f"    {k.upper():<6s} ${metrics['percentiles'][k]:>14,.0f}")


# ============================================================
# MAIN
# ============================================================
if __name__ == '__main__':
    print("=" * 70)
    print("FUTUREPROOF EPM — SCENARIO ANALYSIS")
    print("50,000-path Monte Carlo per tenure | v14a parameters")
    print("=" * 70)

    # ────────────────────────────────────────────────────────────
    # Run simulations for each tenure (shared across scenarios)
    # ────────────────────────────────────────────────────────────
    tenures_to_run = [15, 20, 25, 30]
    tenure_surpluses = {}  # {tenure: final_surplus_array}
    tenure_yearly = {}     # {tenure: yearly_surplus_array}
    tenure_metrics = {}

    for tenure in tenures_to_run:
        print(f"\n{'─' * 50}")
        print(f"Simulating {tenure}-year tenure ({N_PATHS:,} paths)...")
        t0 = time.time()
        yearly = run_single_tenure(tenure, seed=SEED + tenure)
        final = yearly[:, -1]
        tenure_surpluses[tenure] = final
        tenure_yearly[tenure] = yearly
        elapsed = time.time() - t0
        print(f"  Completed in {elapsed:.1f}s — PoD at Year {tenure}: {np.mean(final < 0) * 100:.2f}%")
        tenure_metrics[tenure] = analyse_surplus(final, f"{tenure}yr tenure")

    # Print individual tenure results
    print("\n" + "=" * 70)
    print("INDIVIDUAL TENURE RESULTS")
    print("=" * 70)
    for tenure in tenures_to_run:
        print(f"\n── {tenure}-Year Tenure ──")
        # PoD at maturity for this tenure
        final = tenure_surpluses[tenure]
        pod = np.mean(final < 0) * 100
        print(f"  PoD at Year {tenure}: {pod:.2f}%")
        # Also show PoD at Year 30 if tenure < 30 (loan has already expired)
        if tenure < 30:
            # For shorter tenures, the loan expires at year {tenure}
            # By year 30, the surplus is whatever it was at maturity
            print(f"  (Loan expires at Year {tenure} — PoD at maturity is the relevant metric)")
        print_results(tenure_metrics[tenure])

    # ────────────────────────────────────────────────────────────
    # SCENARIO 1: Loan Term Mix
    # ────────────────────────────────────────────────────────────
    print("\n" + "=" * 70)
    print("SCENARIO 1: LOAN TERM MIX — REMOVING 15-YEAR TERMS")
    print("=" * 70)

    # Baseline: 25% each of 15, 20, 25, 30
    baseline_weights = {15: 0.25, 20: 0.25, 25: 0.25, 30: 0.25}
    # Test: 0% 15yr, 1/3 each of 20, 25, 30
    test_weights = {15: 0.0, 20: 1/3, 25: 1/3, 30: 1/3}

    # Weighted portfolio PoD (individual level, weighted average at each tenure's maturity)
    baseline_pod = sum(w * np.mean(tenure_surpluses[t] < 0) * 100
                       for t, w in baseline_weights.items())
    test_pod = sum(w * np.mean(tenure_surpluses[t] < 0) * 100
                   for t, w in test_weights.items() if w > 0)

    # Weighted mean surplus
    baseline_mean = sum(w * np.mean(tenure_surpluses[t])
                        for t, w in baseline_weights.items())
    test_mean = sum(w * np.mean(tenure_surpluses[t])
                    for t, w in test_weights.items() if w > 0)

    # Portfolio PoC via waterfall simulation
    print("\nCalculating portfolio PoC (Payments Waterfall, 50K portfolio simulations)...")
    t0 = time.time()
    baseline_poc = portfolio_poc(tenure_surpluses, baseline_weights)
    test_poc = portfolio_poc(tenure_surpluses, test_weights)
    print(f"  Completed in {time.time() - t0:.1f}s")

    # Weighted insurance premium
    baseline_premium = sum(w * tenure_metrics[t]['loaded_premium']
                           for t, w in baseline_weights.items())
    test_premium = sum(w * tenure_metrics[t]['loaded_premium']
                       for t, w in test_weights.items() if w > 0)

    print(f"\n  {'Metric':<35s} {'Baseline':<20s} {'No 15yr Terms':<20s} {'Change':>10s}")
    print(f"  {'─' * 86}")
    print(f"  {'Mix':<35s} {'25/25/25/25':<20s} {'0/33/33/33':<20s}")
    print(f"  {'Wtd PoD (at maturity)':<35s} {baseline_pod:>18.2f}% {test_pod:>18.2f}% {test_pod - baseline_pod:>+9.2f}%")
    print(f"  {'Portfolio PoC (waterfall)':<35s} {baseline_poc:>18.2f}% {test_poc:>18.2f}% {test_poc - baseline_poc:>+9.2f}%")
    print(f"  {'Wtd Mean Surplus':<35s} ${baseline_mean:>17,.0f} ${test_mean:>17,.0f} ${test_mean - baseline_mean:>+8,.0f}")
    print(f"  {'Wtd Loaded Premium':<35s} ${baseline_premium:>17,.0f} ${test_premium:>17,.0f} ${test_premium - baseline_premium:>+8,.0f}")

    # Detailed per-tenure PoD
    print(f"\n  Per-Tenure PoD at Maturity:")
    for t in tenures_to_run:
        pod_t = np.mean(tenure_surpluses[t] < 0) * 100
        b_w = baseline_weights[t]
        t_w = test_weights[t]
        print(f"    {t:2d}yr: PoD={pod_t:6.2f}%   Baseline weight={b_w:.0%}   Test weight={t_w:.1%}")

    # ────────────────────────────────────────────────────────────
    # SCENARIO 2: Top Cover Limit (LMI Threshold)
    # ────────────────────────────────────────────────────────────
    print("\n" + "=" * 70)
    print("SCENARIO 2: TOP COVER LIMIT — P10 vs P20 vs P30")
    print("=" * 70)

    # Use 30yr tenure as the reference (most common analysis)
    final_30 = tenure_surpluses[30]
    pod_30 = np.mean(final_30 < 0) * 100
    discount = np.exp(-CASH_RATE_THETA * 30)

    # Individual mortgage level
    print("\n── Individual Mortgage Level (30yr tenure) ──")

    for pct_label, pct in [("P10 (worst 10%)", 10), ("P20 (worst 20%)", 20), ("P30 (worst 30%)", 30)]:
        threshold = np.percentile(final_30, pct)
        # Top cover = loss at this percentile (if negative)
        top_cover = abs(threshold) if threshold < 0 else 0

        # Fair premium: E[max(-surplus, 0)] * discount, but only for paths below the threshold
        # With wider top cover, more paths are covered
        covered_mask = final_30 <= threshold
        deficit_mask = final_30 < 0

        # Insurance pays out on deficit paths that fall within coverage
        # Paths worse than threshold are covered by insurance
        # But also: changing the threshold changes what the insurer covers
        # Top Cover = threshold. Insurer covers losses up to this amount.
        # For P10: covers worst 10% — losses beyond P10 are reinsured
        # For P20: covers worst 20% — more generous coverage

        # Actually the Top Cover Limit means:
        # LMI covers losses from $0 to the P-quantile absolute value
        # Any loss exceeding the top cover goes to reinsurance

        # Standard calculation: fair premium = PV of expected claims within coverage
        if threshold < 0:
            # All deficit paths where deficit <= top_cover are fully covered
            # Paths with deficit > top_cover: LMI pays top_cover, excess goes to reinsurance
            deficits = -final_30[deficit_mask]  # positive values = loss amounts
            lmi_payouts = np.minimum(deficits, top_cover)  # capped at top cover
            fair_premium_ind = discount * np.sum(lmi_payouts) / N_PATHS
            reinsurance_payouts = np.maximum(deficits - top_cover, 0)
            reinsurance_premium = discount * np.sum(reinsurance_payouts) / N_PATHS
            mean_lmi_claim = np.mean(lmi_payouts)
        else:
            fair_premium_ind = 0
            reinsurance_premium = 0
            mean_lmi_claim = 0
            lmi_payouts = np.array([])
            reinsurance_payouts = np.array([])

        loaded = fair_premium_ind * 1.5
        MAX_LOAN = INITIAL_LOAN + ANNUITY_PA * ANNUITY_TERM_YEARS
        prem_pct = 100 * loaded / MAX_LOAN

        print(f"\n  ── {pct_label} ──")
        print(f"  Top Cover Limit:           ${top_cover:>14,.0f}")
        print(f"  Paths covered by LMI:      {np.sum(deficit_mask):>14,d} ({pod_30:.2f}%)")
        print(f"  Mean LMI claim size:       ${mean_lmi_claim:>14,.0f}")
        print(f"  LMI Fair Premium (PV):     ${fair_premium_ind:>14,.0f}")
        print(f"  LMI Loaded (1.5x):         ${loaded:>14,.0f}")
        print(f"  LMI as % of max loan:      {prem_pct:>14.3f}%")
        print(f"  Reinsurance Premium (PV):  ${reinsurance_premium:>14,.0f}")
        n_exceed = int(np.sum(deficits > top_cover)) if threshold < 0 else 0
        print(f"  Paths exceeding top cover: {n_exceed:>14,d} ({100 * n_exceed / N_PATHS:.2f}%)")

    # Portfolio level — how top cover affects PoC
    print("\n── Portfolio Level Impact (100-loan portfolios, 50K simulations) ──")
    print(f"  Using baseline tenure mix: 25% each of 15, 20, 25, 30yr")

    # For portfolio PoC, the top cover limit doesn't directly change PoC
    # (PoC is about whether claims occur at all, not how much LMI covers)
    # But a wider top cover means MORE of the deficit is absorbed by LMI,
    # reducing funder exposure. Let's show net funder exposure.

    print(f"\n  Portfolio PoC (Payments Waterfall): {baseline_poc:.2f}%")
    print(f"  (PoC is independent of top cover — it measures claim probability, not claim size)")

    print(f"\n  {'Top Cover':<20s} {'LMI Premium':<18s} {'Reinsurance':<18s} {'Net Funder Exposure':<20s}")
    print(f"  {'─' * 76}")

    for pct_label, pct in [("P10 (baseline)", 10), ("P20", 20), ("P30", 30)]:
        threshold_30 = np.percentile(final_30, pct)
        top_cover = abs(threshold_30) if threshold_30 < 0 else 0
        deficit_mask = final_30 < 0
        deficits = -final_30[deficit_mask]

        if len(deficits) > 0:
            lmi_covers = np.minimum(deficits, top_cover)
            excess = np.maximum(deficits - top_cover, 0)
            lmi_prem = discount * np.sum(lmi_covers) / N_PATHS * 1.5
            reins_prem = discount * np.sum(excess) / N_PATHS * 1.5
            # Net funder exposure: losses exceeding both LMI + reinsurance
            # (in our model, reinsurance covers the excess, so net = 0 in theory)
            # But let's show what funders actually see per $1M deployed
            total_loss = np.sum(deficits)
            lmi_total = np.sum(lmi_covers)
            reins_total = np.sum(excess)
            pct_covered = 100 * (lmi_total + reins_total) / total_loss if total_loss > 0 else 100
        else:
            lmi_prem = 0
            reins_prem = 0
            pct_covered = 100

        # Per-loan equivalent
        print(f"  {pct_label:<20s} ${lmi_prem:>15,.0f}  ${reins_prem:>15,.0f}  {pct_covered:>17.1f}% covered")

    # ────────────────────────────────────────────────────────────
    # SUMMARY
    # ────────────────────────────────────────────────────────────
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)

    print("""
  SCENARIO 1 — Removing 15-year terms:
  The 15yr tenure has a HIGHER PoD at maturity than longer tenures because
  the investment has less time to compound and recover from drawdowns.
  Removing it from the portfolio mix should IMPROVE weighted PoD and PoC.

  SCENARIO 2 — Wider Top Cover:
  Moving from P10 to P20/P30 increases the LMI top cover limit, meaning
  the insurer covers more of the tail. This INCREASES the LMI premium
  but REDUCES reinsurance cost and net funder exposure.
  Portfolio PoC is unaffected — it measures claim frequency, not severity.
""")

    # Save results to JSON
    results = {
        'tenure_metrics': {
            str(t): {
                'pod_at_maturity': float(np.mean(tenure_surpluses[t] < 0) * 100),
                'mean_surplus': float(np.mean(tenure_surpluses[t])),
                'median_surplus': float(np.median(tenure_surpluses[t])),
                'p10': float(np.percentile(tenure_surpluses[t], 10)),
                'p20': float(np.percentile(tenure_surpluses[t], 20)),
                'p30': float(np.percentile(tenure_surpluses[t], 30)),
            }
            for t in tenures_to_run
        },
        'scenario1': {
            'baseline_pod': float(baseline_pod),
            'test_pod': float(test_pod),
            'baseline_poc': float(baseline_poc),
            'test_poc': float(test_poc),
            'baseline_mean_surplus': float(baseline_mean),
            'test_mean_surplus': float(test_mean),
        },
        'scenario2': {
            'individual_30yr': {},
        },
    }

    for pct in [10, 20, 30]:
        threshold = np.percentile(final_30, pct)
        top_cover = abs(threshold) if threshold < 0 else 0
        deficit_mask = final_30 < 0
        deficits = -final_30[deficit_mask]
        lmi_covers = np.minimum(deficits, top_cover) if len(deficits) > 0 else np.array([0])
        excess = np.maximum(deficits - top_cover, 0) if len(deficits) > 0 else np.array([0])
        fair_prem = float(discount * np.sum(lmi_covers) / N_PATHS)

        results['scenario2']['individual_30yr'][f'P{pct}'] = {
            'top_cover': float(top_cover),
            'fair_premium': fair_prem,
            'loaded_premium': fair_prem * 1.5,
            'premium_pct': float(100 * fair_prem * 1.5 / MAX_LOAN),
            'reinsurance_premium': float(discount * np.sum(excess) / N_PATHS * 1.5),
            'paths_exceeding_cover': int(np.sum(deficits > top_cover)) if len(deficits) > 0 else 0,
        }

    with open('scenario_analysis_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    print("Results saved to scenario_analysis_results.json")
