#!/usr/bin/env python3
"""
50,000-path Monte Carlo simulation of the FutureProof EPM v14a model.
Updated parameters from FutureProofCalculator_Pavel_v14a.xlsm:
  - Retail Margin: 0.70% (was 0.75%)
  - Variable Costs: 3.20% (was 3.25%)
  - LMI Upfront: 1.6% (was 1.5%)
  - Profit Share: 25% (was 10%)
  - Equity-Rate Correlation: 0.069 (was 0.002)
  - Hedging cost: -0.00397 (calculated, was -0.004)
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

TENURE_YEARS = 30
ANNUITY_PA = 25_000
ANNUITY_TERM_YEARS = 10

# Costs (updated v14a)
WHOLESALE_MARGIN = 0.02
RETAIL_MARGIN = 0.007        # was 0.0075
HEDGING_FEE = 0.0025
FP_MARGIN = 0.0025
LMI_UPFRONT_PCT = 0.016      # was 0.015
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
CASH_RATE_EQUITY_CORR = 0.069    # was 0.002

# Holiday mechanism
HOLIDAY_ENTRY_LEVEL = 0.9
HOLIDAY_EXIT_LEVEL = 1.458

# Profit share (updated v14a)
PROFIT_SHARE_YEARS = 5
PROFIT_SHARE_PCT = 0.25          # was 0.10

# Simulation
N_PATHS = 50_000
SEED = 42

# ============================================================
# SIMULATION ENGINE
# ============================================================

def run_simulation():
    print(f"Running {N_PATHS:,} path Monte Carlo simulation...")
    print(f"Parameters: v14a — Loan=${INITIAL_LOAN:,}, ProfitShare=25%, Corr=0.069, RetailMargin=0.70%")
    start = time.time()

    rng = np.random.default_rng(SEED)

    # Pre-compute loan trajectory (deterministic)
    # Annuity adds to loan for first 10 years
    loan_from_funder = np.zeros(TENURE_YEARS + 1)
    loan_from_funder[0] = INITIAL_LOAN
    for t in range(1, TENURE_YEARS + 1):
        if t <= ANNUITY_TERM_YEARS:
            loan_from_funder[t] = loan_from_funder[t - 1] + ANNUITY_PA
        else:
            loan_from_funder[t] = loan_from_funder[t - 1]

    MAX_LOAN = np.max(loan_from_funder)  # 1,600,000
    upfront_LMI = MAX_LOAN * LMI_UPFRONT_PCT
    upfront_reinsurance = MAX_LOAN * REINSURANCE_UPFRONT_PCT

    # Holiday thresholds (constant, based on initial loan)
    holiday_entry_threshold = INITIAL_LOAN * HOLIDAY_ENTRY_LEVEL   # 1,215,000
    holiday_exit_threshold = INITIAL_LOAN * HOLIDAY_EXIT_LEVEL     # 1,968,300

    print(f"Max loan: ${MAX_LOAN:,.0f}")
    print(f"Upfront LMI: ${upfront_LMI:,.0f}")
    print(f"Holiday entry: ${holiday_entry_threshold:,.0f}, exit: ${holiday_exit_threshold:,.0f}")
    print(f"Initial investment: ${INITIAL_LOAN - upfront_LMI - upfront_reinsurance:,.0f}")

    # Generate random numbers for all paths and years
    # z1 = equity returns, z2_raw = cash rate shocks
    z1 = rng.standard_normal((N_PATHS, TENURE_YEARS))
    z2_raw = rng.standard_normal((N_PATHS, TENURE_YEARS))
    # Correlate: z2 = rho * z1 + sqrt(1-rho^2) * z2_raw
    rho = CASH_RATE_EQUITY_CORR
    z2 = rho * z1 + np.sqrt(1 - rho**2) * z2_raw

    # ============================================================
    # Initialize arrays
    # ============================================================
    investment = np.full(N_PATHS, INITIAL_LOAN - upfront_LMI - upfront_reinsurance, dtype=np.float64)
    cash_rate = np.full(N_PATHS, CASH_RATE_INITIAL, dtype=np.float64)

    # Holiday state
    holiday_entry_flag = np.zeros(N_PATHS, dtype=bool)  # currently on holiday
    holiday_count = np.zeros(N_PATHS, dtype=np.float64)  # consecutive holiday years
    holiday_account = np.zeros(N_PATHS, dtype=np.float64)  # accumulated deferred interest
    repayment_step = np.zeros(N_PATHS, dtype=np.float64)  # remaining repayment periods
    funder_interest_tot = np.zeros(N_PATHS, dtype=np.float64)
    interest_charged_tot = np.zeros(N_PATHS, dtype=np.float64)

    # Tracking arrays
    yearly_surplus = np.zeros((N_PATHS, TENURE_YEARS + 1))
    yearly_investment = np.zeros((N_PATHS, TENURE_YEARS + 1))
    yearly_holidays = np.zeros((N_PATHS, TENURE_YEARS))
    cumulative_profit_share = np.zeros(N_PATHS)
    profit_share_by_period = np.zeros((N_PATHS, 6))  # years 5,10,15,20,25,30

    # Initial surplus
    interest_deficit = np.zeros(N_PATHS)
    yearly_surplus[:, 0] = investment - loan_from_funder[0] + interest_deficit
    yearly_investment[:, 0] = investment.copy()

    # Apply initial collar price (BS collar: sell cap call, buy floor put)
    # Collar price is NEGATIVE (~-0.004): selling the 120% call earns more
    # premium than buying the 80% put costs. So (1 - CollarPrice) > 1 → adds value.
    collar_price = -0.003972  # calculated from v14a model (was -0.004)
    investment *= (1 - collar_price)  # = investment * 1.004

    for t in range(1, TENURE_YEARS + 1):
        year_idx = t - 1  # 0-indexed for z arrays

        # ----- 1. Cash rate: Ornstein-Uhlenbeck -----
        # r(t) = r(t-1)*exp(-kappa) + theta*(1-exp(-kappa)) + sigma*Z
        cash_rate = (cash_rate * np.exp(-CASH_RATE_KAPPA) +
                     CASH_RATE_THETA * (1 - np.exp(-CASH_RATE_KAPPA)) +
                     CASH_RATE_SIGMA * z2[:, year_idx])
        cash_rate = np.maximum(cash_rate, 0)

        # ----- 2. Investment returns with buffer -----
        # Annual lognormal: return = exp(mu + vol*Z) - 1
        raw_return = np.exp(EQUITY_MEAN + EQUITY_VOL * z1[:, year_idx]) - 1
        # Apply buffer cap/floor on (1+return)
        hedged_return = np.clip(raw_return, BUFFER_FLOOR - 1, BUFFER_CAP - 1)

        # ----- 3. Funder interest charged -----
        funder_funding_cost = WHOLESALE_MARGIN + cash_rate
        avg_loan = (loan_from_funder[t - 1] + loan_from_funder[t]) / 2
        funder_interest = -funder_funding_cost * avg_loan  # negative (cost)
        funder_interest_tot += funder_interest

        # ----- 4. Holiday mechanism -----
        prev_holiday_flag = holiday_entry_flag.copy()
        prev_holiday_count = holiday_count.copy()

        # Entry: investment < threshold AND not already on holiday
        entering = (~prev_holiday_flag) & (investment < holiday_entry_threshold)
        # Exit: investment > exit threshold AND on holiday
        exiting = prev_holiday_flag & (investment > holiday_exit_threshold)
        # Stay on holiday: on holiday and not exiting
        staying = prev_holiday_flag & (~exiting)

        holiday_entry_flag = entering | staying

        # Update holiday count
        holiday_count = np.where(holiday_entry_flag, prev_holiday_count + 1, 0)
        yearly_holidays[:, year_idx] = holiday_entry_flag.astype(float)

        # Repayment flag: was on holiday, now off
        repayment_flag = prev_holiday_flag & (~holiday_entry_flag)
        # Set repayment periods when transitioning off holiday
        new_repayment_periods = np.where(repayment_flag & (repayment_step <= 0),
                                          prev_holiday_count, 0)
        repayment_step = np.where(new_repayment_periods > 0,
                                   new_repayment_periods,
                                   np.maximum(repayment_step - 1, 0))

        # Holiday account
        holiday_account_open = holiday_account.copy()

        # Interest holiday: during holiday, offset the funder interest
        interest_holiday = np.where(holiday_entry_flag, -funder_interest, 0)

        # Repayment holiday: pay back accumulated holiday account
        repayment_holiday = np.where(repayment_step > 0,
                                      -holiday_account_open / np.maximum(repayment_step, 1),
                                      0)

        holiday_account = holiday_account_open + interest_holiday + repayment_holiday

        # ----- 5. Net interest charged from investment -----
        interest_charged = funder_interest + interest_holiday + repayment_holiday
        interest_charged_tot += interest_charged
        interest_deficit = funder_interest_tot - interest_charged_tot

        # ----- 6. Other costs from investment -----
        retailer_nim = -RETAIL_MARGIN * avg_loan  # negative
        fp_margin_payment = -FP_MARGIN * investment  # negative, based on current investment
        hedging_fee_payment = -HEDGING_FEE * investment  # negative

        # Special case: last year
        if t == TENURE_YEARS:
            retailer_nim = -RETAIL_MARGIN * loan_from_funder[t - 1] / 2
            interest_charged = -funder_funding_cost * loan_from_funder[t - 1] / 2

        # ----- 7. Investment return -----
        investment_return = investment * hedged_return

        # ----- 8. Update investment account -----
        investment = (investment + investment_return + interest_charged +
                      retailer_nim + fp_margin_payment + hedging_fee_payment)

        # ----- 9. Balance surplus -----
        surplus = investment - loan_from_funder[t] + interest_deficit

        # ----- 10. Profit share (every 5 years, not at maturity) -----
        if t < TENURE_YEARS and t % PROFIT_SHARE_YEARS == 0:
            profit_share = np.where(surplus > 0, surplus * PROFIT_SHARE_PCT, 0)
            investment -= profit_share
            cumulative_profit_share += profit_share
            period_idx = (t // PROFIT_SHARE_YEARS) - 1
            if period_idx < 6:
                profit_share_by_period[:, period_idx] = profit_share

        # At maturity: remove surplus from investment (wind up)
        if t == TENURE_YEARS:
            windup = np.maximum(surplus, 0)
            investment -= windup

        # ----- 11. Apply collar price for next period (net income) -----
        if t < TENURE_YEARS:
            investment *= (1 - collar_price)  # = investment * 1.004

        # ----- 12. Record -----
        yearly_surplus[:, t] = surplus
        yearly_investment[:, t] = investment

    elapsed = time.time() - start
    print(f"Simulation completed in {elapsed:.1f} seconds")

    # ============================================================
    # RESULTS
    # ============================================================
    print("\n" + "="*70)
    print("RESULTS — 50,000 PATH MONTE CARLO SIMULATION (v14a PARAMETERS)")
    print("="*70)

    final_surplus = yearly_surplus[:, -1]

    # Deficit probability by year
    print("\n--- Deficit Probability by Year ---")
    deficit_by_year = []
    for yr in range(1, TENURE_YEARS + 1):
        dp = np.mean(yearly_surplus[:, yr] < 0) * 100
        deficit_by_year.append(dp)
        if yr in [1, 5, 10, 15, 20, 25, 30]:
            print(f"  Year {yr:2d}: {dp:.2f}%")

    # Final stats
    final_deficit_prob = np.mean(final_surplus < 0) * 100
    se_deficit = np.sqrt(final_deficit_prob/100 * (1 - final_deficit_prob/100) / N_PATHS) * 100
    mean_surplus = np.mean(final_surplus)
    median_surplus = np.median(final_surplus)
    p1 = np.percentile(final_surplus, 1)
    p5 = np.percentile(final_surplus, 5)
    p10 = np.percentile(final_surplus, 10)
    p25 = np.percentile(final_surplus, 25)
    p75 = np.percentile(final_surplus, 75)
    p90 = np.percentile(final_surplus, 90)
    p95 = np.percentile(final_surplus, 95)
    p99 = np.percentile(final_surplus, 99)

    print(f"\n--- Final Surplus Distribution (Year 30) ---")
    print(f"  Deficit probability: {final_deficit_prob:.2f}% (SE: {se_deficit:.2f}%)")
    print(f"  Mean surplus:   ${mean_surplus:>14,.0f}")
    print(f"  Median surplus: ${median_surplus:>14,.0f}")
    print(f"  1st percentile: ${p1:>14,.0f}")
    print(f"  5th percentile: ${p5:>14,.0f}")
    print(f"  10th percentile:${p10:>14,.0f}")
    print(f"  25th percentile:${p25:>14,.0f}")
    print(f"  75th percentile:${p75:>14,.0f}")
    print(f"  90th percentile:${p90:>14,.0f}")
    print(f"  95th percentile:${p95:>14,.0f}")
    print(f"  99th percentile:${p99:>14,.0f}")

    # Insurance pricing
    # Discount factor: exp(-theta * T)
    discount = np.exp(-CASH_RATE_THETA * TENURE_YEARS)
    deficit_mask = final_surplus < 0
    n_deficit = np.sum(deficit_mask)
    if n_deficit > 0:
        discounted_claims = discount * final_surplus[deficit_mask]  # negative values
        fair_premium = -np.mean(discounted_claims) * (final_deficit_prob / 100)
        mean_deficit = np.mean(final_surplus[deficit_mask])
        cond_expected_deficit = mean_deficit
    else:
        cond_expected_deficit = 0
        fair_premium = 0

    fair_premium_loaded = fair_premium * 1.5
    se_premium = fair_premium * se_deficit / max(final_deficit_prob, 0.01)

    print(f"\n--- Insurance Pricing ---")
    print(f"  Paths in deficit: {n_deficit} ({final_deficit_prob:.2f}%)")
    print(f"  Cond. expected deficit: ${cond_expected_deficit:>12,.0f}")
    print(f"  Fair premium (PV): ${fair_premium:>12,.0f}")
    print(f"  SE on premium: ${se_premium:>12,.0f} ({100*se_premium/max(fair_premium,1):.1f}%)")
    print(f"  Fair + 50% loading: ${fair_premium_loaded:>12,.0f}")
    print(f"  As % of max loan: {100*fair_premium_loaded/MAX_LOAN:.3f}%")

    # Holiday stats
    print(f"\n--- Holiday Mechanism ---")
    mean_holidays_per_year = np.mean(yearly_holidays, axis=0)
    for yr in [0, 4, 9, 14, 19, 24, 29]:
        if yr < TENURE_YEARS:
            print(f"  Year {yr+1:2d}: mean {mean_holidays_per_year[yr]:.3f} on holiday")

    # Profit share
    print(f"\n--- Profit Share (25% every 5 years) ---")
    for i, yr in enumerate([5, 10, 15, 20, 25, 30]):
        if i < 5:  # only 5 profit share events (not at maturity)
            mean_ps = np.mean(profit_share_by_period[:, i])
            median_ps = np.median(profit_share_by_period[:, i])
            print(f"  Year {yr:2d}: mean ${mean_ps:>12,.0f}, median ${median_ps:>12,.0f}")

    print(f"\n  Total mean profit share: ${np.mean(cumulative_profit_share):>12,.0f}")

    # Investment account stats
    print(f"\n--- Investment Account ---")
    for yr in [1, 5, 10, 15, 20, 25, 29]:
        inv = yearly_investment[:, yr]
        print(f"  Year {yr:2d}: mean ${np.mean(inv):>12,.0f}, median ${np.median(inv):>12,.0f}")

    # Percentile table by year
    print(f"\n--- Surplus Percentiles by Year ---")
    print(f"  {'Year':>4s}  {'Deficit%':>8s}  {'P1':>12s}  {'P10':>12s}  {'Median':>12s}  {'P90':>12s}  {'P99':>12s}")
    for yr in [1, 5, 10, 15, 20, 25, 30]:
        s = yearly_surplus[:, yr]
        dp = np.mean(s < 0) * 100
        print(f"  {yr:4d}  {dp:7.2f}%  ${np.percentile(s,1):>11,.0f}  ${np.percentile(s,10):>11,.0f}  "
              f"${np.median(s):>11,.0f}  ${np.percentile(s,90):>11,.0f}  ${np.percentile(s,99):>11,.0f}")

    # Compare with spreadsheet
    print(f"\n--- Comparison with Spreadsheet (1,000 paths) ---")
    ss_deficit = [0.509, 0.509, 0.49, 0.473, 0.478, 0.47, 0.453, 0.428, 0.417, 0.408,
                  0.37, 0.34, 0.317, 0.306, 0.279, 0.244, 0.235, 0.224, 0.203, 0.192,
                  0.179, None, None, None, None, None, None, None, None, 0.101]
    print(f"  {'Year':>4s}  {'SS Deficit%':>11s}  {'MC Deficit%':>11s}  {'Diff':>8s}")
    for yr in [1, 5, 10, 15, 20, 30]:
        ss = ss_deficit[yr-1]
        mc = deficit_by_year[yr-1]
        if ss is not None:
            print(f"  {yr:4d}  {ss*100:10.1f}%  {mc:10.2f}%  {mc - ss*100:>+7.1f}pp")

    # Save results for PDF generation
    results = {
        'n_paths': N_PATHS,
        'deficit_prob': round(final_deficit_prob, 2),
        'deficit_se': round(se_deficit, 2),
        'mean_surplus': round(float(mean_surplus), 0),
        'median_surplus': round(float(median_surplus), 0),
        'p1': round(float(p1), 0),
        'p5': round(float(p5), 0),
        'p10': round(float(p10), 0),
        'p25': round(float(p25), 0),
        'p75': round(float(p75), 0),
        'p90': round(float(p90), 0),
        'p95': round(float(p95), 0),
        'p99': round(float(p99), 0),
        'fair_premium': round(float(fair_premium), 0),
        'fair_premium_loaded': round(float(fair_premium_loaded), 0),
        'premium_se': round(float(se_premium), 0),
        'cond_expected_deficit': round(float(cond_expected_deficit), 0),
        'n_deficit': int(n_deficit),
        'deficit_by_year': [round(d, 2) for d in deficit_by_year],
        'mean_holidays_per_year': [round(float(h), 3) for h in mean_holidays_per_year],
        'profit_share_means': [round(float(np.mean(profit_share_by_period[:, i])), 0) for i in range(5)],
        'surplus_percentiles_by_year': {},
        'mean_investment_by_year': {},
    }

    for yr in range(1, 31):
        s = yearly_surplus[:, yr]
        results['surplus_percentiles_by_year'][str(yr)] = {
            'deficit_pct': round(float(np.mean(s < 0) * 100), 2),
            'p1': round(float(np.percentile(s, 1)), 0),
            'p10': round(float(np.percentile(s, 10)), 0),
            'median': round(float(np.median(s)), 0),
            'mean': round(float(np.mean(s)), 0),
            'p90': round(float(np.percentile(s, 90)), 0),
            'p99': round(float(np.percentile(s, 99)), 0),
        }
        results['mean_investment_by_year'][str(yr)] = round(float(np.mean(yearly_investment[:, yr])), 0)

    with open('monte_carlo_v14a_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to monte_carlo_v14a_results.json")

    return results


if __name__ == '__main__':
    results = run_simulation()
