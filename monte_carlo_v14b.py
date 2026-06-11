#!/usr/bin/env python3
"""
50,000-path Monte Carlo simulation of the FutureProof EPM v14b (Fixed) model.

Key changes from v14a:
  - Equity return: 9.3% (was 10.0%)
  - Equity vol: 12.0% (was 10.0%)
  - Buffer cap: 130% (was 120%)
  - Annuity: $24,000/yr (was $25,000)
  - Initial Loan: $1,360,000 (was $1,350,000)
  - Profit share: 10% / 5yr (was 25%/5yr or 20%/3yr optimised)
  - Holiday entry: 0.90 (was 1.05 optimised)
  - Holiday exit: 1.458 (was 1.701 optimised)
  - Correlation: 0.21 (was 0.069)
  - Loan type: Principal + Interest (amortises Year 11-30)
  - LMI upfront: 2.0% (was 1.6%)
  - Insurance for tail risk: 0.05% annual
  - Top cover limit: 10th percentile (explicit LMI/reinsurance boundary)
  - Hedging program fee: 0.25% (explicit)

Insurance structure explicitly models:
  - LMI: covers individual mortgage deficit up to top cover limit
  - Tail risk reinsurance: covers deficit beyond top cover limit
"""

import numpy as np
import time
import json

# ============================================================
# v14b PARAMETERS (from FutureProofCalculator_Pavel_v14b (Fixed).xlsm)
# ============================================================
HOME_VALUE = 2_000_000
LVR = 0.80
INITIAL_LOAN = 1_360_000
LOAN_TYPE = "PI"  # Principal + Interest

TENURE_YEARS = 30
ANNUITY_PA = 24_000
ANNUITY_TERM_YEARS = 10

# Costs
WHOLESALE_MARGIN = 0.02
RETAIL_MARGIN = 0.007
HEDGING_FEE = 0.0025
FP_MARGIN = 0.0025
LMI_UPFRONT_PCT = 0.02
TAIL_RISK_ANNUAL_PCT = 0.0005

# Investment (GBM annual + buffer)
EQUITY_MEAN = 0.093        # was 0.10
EQUITY_VOL = 0.12          # was 0.10
BUFFER_CAP = 1.30          # was 1.20
BUFFER_FLOOR = 0.80

# Cash rate (Ornstein-Uhlenbeck)
CASH_RATE_INITIAL = 0.044
CASH_RATE_THETA = 0.044
CASH_RATE_KAPPA = 0.80
CASH_RATE_SIGMA = 0.015
CASH_RATE_EQUITY_CORR = 0.21   # was 0.069

# Holiday mechanism
HOLIDAY_ENTRY_LEVEL = 0.90     # was 1.05 optimised
HOLIDAY_EXIT_LEVEL = 1.458     # was 1.701 optimised

# Profit share
PROFIT_SHARE_YEARS = 5
PROFIT_SHARE_PCT = 0.10        # was 0.25

# Simulation
N_PATHS = 50_000
SEED = 42

# ============================================================
# LOAN TRAJECTORY (PI amortisation)
# ============================================================
def compute_loan_trajectory():
    """PI loan: builds up during annuity term, then amortises linearly to 0."""
    loan = np.zeros(TENURE_YEARS + 1)
    loan[0] = INITIAL_LOAN

    # Phase 1: Annuity adds to mortgage
    for t in range(1, TENURE_YEARS + 1):
        if t <= ANNUITY_TERM_YEARS:
            loan[t] = loan[t - 1] + ANNUITY_PA
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


# ============================================================
# SIMULATION ENGINE
# ============================================================
def run_simulation():
    print(f"Running {N_PATHS:,} path Monte Carlo simulation (v14b)...")
    print(f"Parameters: Loan=${INITIAL_LOAN:,}, Annuity=${ANNUITY_PA:,}/yr, PI amortisation")
    print(f"  Equity: mean={EQUITY_MEAN*100:.1f}%, vol={EQUITY_VOL*100:.1f}%, Cap={BUFFER_CAP*100:.0f}%, Floor={BUFFER_FLOOR*100:.0f}%")
    print(f"  Profit share: {PROFIT_SHARE_PCT*100:.0f}% every {PROFIT_SHARE_YEARS} years")
    print(f"  Holiday: entry={HOLIDAY_ENTRY_LEVEL}, exit={HOLIDAY_EXIT_LEVEL}")
    print(f"  Correlation: {CASH_RATE_EQUITY_CORR}")
    start = time.time()

    rng = np.random.default_rng(SEED)

    # Loan trajectory
    loan_from_funder = compute_loan_trajectory()
    MAX_LOAN = np.max(loan_from_funder)

    upfront_LMI = MAX_LOAN * LMI_UPFRONT_PCT

    # Holiday thresholds
    holiday_entry_threshold = INITIAL_LOAN * HOLIDAY_ENTRY_LEVEL
    holiday_exit_threshold = INITIAL_LOAN * HOLIDAY_EXIT_LEVEL

    print(f"\n  Max loan (Year 10): ${MAX_LOAN:,.0f}")
    print(f"  Loan at Year 30: ${loan_from_funder[TENURE_YEARS]:,.0f}")
    print(f"  Annual principal repayment (Yr 11-30): ${MAX_LOAN / 20:,.0f}")
    print(f"  Upfront LMI: ${upfront_LMI:,.0f}")
    print(f"  Holiday entry: ${holiday_entry_threshold:,.0f}, exit: ${holiday_exit_threshold:,.0f}")

    initial_investment = INITIAL_LOAN - upfront_LMI
    print(f"  Initial investment: ${initial_investment:,.0f}")

    # Generate random numbers
    z1 = rng.standard_normal((N_PATHS, TENURE_YEARS))
    z2_raw = rng.standard_normal((N_PATHS, TENURE_YEARS))
    rho = CASH_RATE_EQUITY_CORR
    z2 = rho * z1 + np.sqrt(1 - rho**2) * z2_raw

    # Initialize
    investment = np.full(N_PATHS, initial_investment, dtype=np.float64)
    cash_rate = np.full(N_PATHS, CASH_RATE_INITIAL, dtype=np.float64)

    # Holiday state
    holiday_entry_flag = np.zeros(N_PATHS, dtype=bool)
    holiday_count = np.zeros(N_PATHS, dtype=np.float64)
    holiday_account = np.zeros(N_PATHS, dtype=np.float64)
    repayment_step = np.zeros(N_PATHS, dtype=np.float64)
    funder_interest_tot = np.zeros(N_PATHS, dtype=np.float64)
    interest_charged_tot = np.zeros(N_PATHS, dtype=np.float64)

    # Tracking
    yearly_surplus = np.zeros((N_PATHS, TENURE_YEARS + 1))
    yearly_investment = np.zeros((N_PATHS, TENURE_YEARS + 1))
    yearly_holidays = np.zeros((N_PATHS, TENURE_YEARS))
    yearly_loan = np.zeros(TENURE_YEARS + 1)
    cumulative_profit_share = np.zeros(N_PATHS)
    profit_share_by_period = np.zeros((N_PATHS, 6))

    # Funder received (interest payments to wholesale funder)
    yearly_funder_received = np.zeros((N_PATHS, TENURE_YEARS))
    # Lender NIM received
    yearly_lender_nim = np.zeros((N_PATHS, TENURE_YEARS))
    # FP margin received
    yearly_fp_margin = np.zeros((N_PATHS, TENURE_YEARS))

    # Initial state
    interest_deficit = np.zeros(N_PATHS)
    yearly_surplus[:, 0] = investment - loan_from_funder[0] + interest_deficit
    yearly_investment[:, 0] = investment.copy()
    yearly_loan[0] = loan_from_funder[0]

    # Collar price (calculated from v14b: -0.001340)
    collar_price = -0.001340
    investment *= (1 - collar_price)

    for t in range(1, TENURE_YEARS + 1):
        year_idx = t - 1

        # 1. Cash rate: Ornstein-Uhlenbeck
        cash_rate = (cash_rate * np.exp(-CASH_RATE_KAPPA) +
                     CASH_RATE_THETA * (1 - np.exp(-CASH_RATE_KAPPA)) +
                     CASH_RATE_SIGMA * z2[:, year_idx])
        cash_rate = np.maximum(cash_rate, 0)

        # 2. Investment returns with buffer
        raw_return = np.exp(EQUITY_MEAN + EQUITY_VOL * z1[:, year_idx]) - 1
        hedged_return = np.clip(raw_return, BUFFER_FLOOR - 1, BUFFER_CAP - 1)

        # 3. Funder interest charged
        funder_funding_cost = WHOLESALE_MARGIN + cash_rate
        avg_loan = (loan_from_funder[t - 1] + loan_from_funder[t]) / 2
        funder_interest = -funder_funding_cost * avg_loan
        funder_interest_tot += funder_interest

        # 4. Holiday mechanism
        prev_holiday_flag = holiday_entry_flag.copy()
        prev_holiday_count = holiday_count.copy()

        entering = (~prev_holiday_flag) & (investment < holiday_entry_threshold)
        exiting = prev_holiday_flag & (investment > holiday_exit_threshold)
        staying = prev_holiday_flag & (~exiting)
        holiday_entry_flag = entering | staying
        holiday_count = np.where(holiday_entry_flag, prev_holiday_count + 1, 0)
        yearly_holidays[:, year_idx] = holiday_entry_flag.astype(float)

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

        # 5. Net interest charged
        interest_charged = funder_interest + interest_holiday + repayment_holiday
        interest_charged_tot += interest_charged
        interest_deficit = funder_interest_tot - interest_charged_tot

        # 6. Other costs
        retailer_nim = -RETAIL_MARGIN * avg_loan
        fp_margin_payment = -FP_MARGIN * investment
        hedging_fee_payment = -HEDGING_FEE * investment
        tail_risk_premium = -TAIL_RISK_ANNUAL_PCT * investment

        # Track payments
        yearly_funder_received[:, year_idx] = -interest_charged  # positive = funder receives
        yearly_lender_nim[:, year_idx] = -retailer_nim
        yearly_fp_margin[:, year_idx] = -fp_margin_payment

        # Last year special handling
        if t == TENURE_YEARS:
            retailer_nim = -RETAIL_MARGIN * loan_from_funder[t - 1] / 2
            interest_charged = -funder_funding_cost * loan_from_funder[t - 1] / 2

        # 7. Investment return
        investment_return = investment * hedged_return

        # 8. Principal repayment (PI: deducted from investment after annuity term)
        principal_repayment = 0
        if t > ANNUITY_TERM_YEARS and LOAN_TYPE == "PI":
            pp = -(loan_from_funder[t - 1] - loan_from_funder[t])  # negative (cost)
            principal_repayment = pp

        # 9. Update investment
        investment = (investment + investment_return + interest_charged +
                      retailer_nim + fp_margin_payment + hedging_fee_payment +
                      tail_risk_premium + principal_repayment)

        # 10. Balance surplus
        surplus = investment - loan_from_funder[t] + interest_deficit
        yearly_loan[t] = loan_from_funder[t]

        # 11. Profit share
        if t < TENURE_YEARS and t % PROFIT_SHARE_YEARS == 0:
            profit_share = np.where(surplus > 0, surplus * PROFIT_SHARE_PCT, 0)
            investment -= profit_share
            cumulative_profit_share += profit_share
            period_idx = (t // PROFIT_SHARE_YEARS) - 1
            if period_idx < 6:
                profit_share_by_period[:, period_idx] = profit_share

        # At maturity: remove surplus
        if t == TENURE_YEARS:
            windup = np.maximum(surplus, 0)
            investment -= windup

        # 12. Collar for next period
        if t < TENURE_YEARS:
            investment *= (1 - collar_price)

        # Record
        yearly_surplus[:, t] = surplus
        yearly_investment[:, t] = investment

    elapsed = time.time() - start
    print(f"\nSimulation completed in {elapsed:.1f} seconds")

    # ============================================================
    # RESULTS
    # ============================================================
    print("\n" + "="*70)
    print("RESULTS — v14b (Fixed) — 50,000 PATH MONTE CARLO")
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
    print(f"  Deficit probability (PoC): {final_deficit_prob:.2f}% (SE: {se_deficit:.2f}%)")
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

    # ============================================================
    # INSURANCE PRICING — LMI + TAIL RISK REINSURANCE
    # ============================================================
    discount = np.exp(-CASH_RATE_THETA * TENURE_YEARS)
    deficit_mask = final_surplus < 0
    n_deficit = np.sum(deficit_mask)

    # Top cover limit: 10th percentile of the DEFICIT distribution
    # (i.e., the worst 10% of deficit paths trigger tail risk reinsurance)
    top_cover_quantile = 0.10
    deficit_values = final_surplus[deficit_mask]
    if n_deficit > 0:
        # 10th percentile ascending = the boundary for worst 10% of deficits
        top_cover_limit = np.percentile(deficit_values, top_cover_quantile * 100)
    else:
        top_cover_limit = 0

    # LMI: covers ALL deficits — pays the full deficit up to |top_cover_limit|
    # For paths with deficit > top_cover_limit (less severe): LMI pays full deficit
    # For paths with deficit < top_cover_limit (more severe): LMI pays up to |top_cover_limit|
    lmi_claims_mild = np.where(deficit_mask & (final_surplus >= top_cover_limit),
                                -final_surplus, 0)
    lmi_claims_severe = np.where(deficit_mask & (final_surplus < top_cover_limit),
                                  -top_cover_limit, 0)  # capped at top cover
    total_lmi_claims = lmi_claims_mild + lmi_claims_severe

    lmi_fair_premium_pv = discount * np.mean(total_lmi_claims)
    lmi_poc = np.mean(deficit_mask) * 100
    lmi_cond_deficit = np.mean(final_surplus[deficit_mask]) if n_deficit > 0 else 0

    # Tail risk reinsurance: covers the EXCESS deficit beyond top cover limit
    deep_deficit_mask = deficit_mask & (final_surplus < top_cover_limit)
    tail_claims = np.where(deep_deficit_mask, -(final_surplus - top_cover_limit), 0)
    tail_fair_premium_pv = discount * np.mean(tail_claims)
    tail_poc = np.mean(deep_deficit_mask) * 100

    # Combined (total = LMI + tail = covers all deficit)
    total_fair_premium = lmi_fair_premium_pv + tail_fair_premium_pv
    total_fair_loaded = total_fair_premium * 1.5

    print(f"\n--- Insurance Structure ---")
    print(f"  Top cover limit (P{top_cover_quantile*100:.0f}): ${top_cover_limit:>14,.0f}")
    print(f"")
    print(f"  LMI (covers up to top cover limit):")
    print(f"    PoC (Year 30):        {lmi_poc:.2f}%")
    print(f"    Cond. expected deficit: ${lmi_cond_deficit:>12,.0f}")
    print(f"    Fair premium (PV):    ${lmi_fair_premium_pv:>12,.0f}")
    print(f"    Fair + 50% loading:   ${lmi_fair_premium_pv * 1.5:>12,.0f}")
    print(f"    As % of max loan:     {100*lmi_fair_premium_pv*1.5/MAX_LOAN:.3f}%")
    print(f"")
    print(f"  Tail Risk Reinsurance (beyond top cover limit):")
    print(f"    PoC (Year 30):        {tail_poc:.2f}%")
    print(f"    Fair premium (PV):    ${tail_fair_premium_pv:>12,.0f}")
    print(f"    Fair + 50% loading:   ${tail_fair_premium_pv * 1.5:>12,.0f}")
    print(f"    As % of max loan:     {100*tail_fair_premium_pv*1.5/MAX_LOAN:.3f}%")
    print(f"")
    print(f"  Combined:")
    print(f"    Total fair premium:   ${total_fair_premium:>12,.0f}")
    print(f"    Total loaded premium: ${total_fair_loaded:>12,.0f}")
    print(f"    As % of max loan:     {100*total_fair_loaded/MAX_LOAN:.3f}%")

    # Holiday stats
    print(f"\n--- Holiday Mechanism ---")
    mean_holidays_per_year = np.mean(yearly_holidays, axis=0)
    for yr in [0, 4, 9, 14, 19, 24, 29]:
        if yr < TENURE_YEARS:
            print(f"  Year {yr+1:2d}: mean {mean_holidays_per_year[yr]:.3f} on holiday")

    total_holiday_years = np.sum(yearly_holidays, axis=1)
    print(f"  Mean total holiday years per path: {np.mean(total_holiday_years):.2f}")
    print(f"  Paths with zero holidays: {np.mean(total_holiday_years == 0)*100:.1f}%")

    # Profit share
    print(f"\n--- Profit Share ({PROFIT_SHARE_PCT*100:.0f}% every {PROFIT_SHARE_YEARS} years) ---")
    for i, yr in enumerate([5, 10, 15, 20, 25, 30]):
        if i < 5:
            mean_ps = np.mean(profit_share_by_period[:, i])
            median_ps = np.median(profit_share_by_period[:, i])
            print(f"  Year {yr:2d}: mean ${mean_ps:>12,.0f}, median ${median_ps:>12,.0f}")
    print(f"  Total mean profit share: ${np.mean(cumulative_profit_share):>12,.0f}")

    # Mortgage balance (PI)
    print(f"\n--- Mortgage Balance (PI Amortisation) ---")
    for yr in [0, 5, 10, 15, 20, 25, 30]:
        print(f"  Year {yr:2d}: ${loan_from_funder[yr]:>12,.0f}")

    # Investment account
    print(f"\n--- Investment Account ---")
    for yr in [1, 5, 10, 15, 20, 25, 30]:
        inv = yearly_investment[:, yr]
        print(f"  Year {yr:2d}: mean ${np.mean(inv):>12,.0f}, median ${np.median(inv):>12,.0f}, "
              f"P10 ${np.percentile(inv, 10):>12,.0f}")

    # Revenue streams
    print(f"\n--- Revenue Streams (mean per mortgage, undiscounted) ---")
    total_funder = np.mean(np.sum(yearly_funder_received, axis=1))
    total_lender = np.mean(np.sum(yearly_lender_nim, axis=1))
    total_fp = np.mean(np.sum(yearly_fp_margin, axis=1))
    total_ps = np.mean(cumulative_profit_share)
    mean_windup = np.mean(np.maximum(final_surplus, 0))
    fp_windup_share = mean_windup * 0.5  # 50% of end-of-term surplus

    print(f"  Funder interest received (30yr): ${total_funder:>14,.0f}")
    print(f"  Lender NIM received (30yr):      ${total_lender:>14,.0f}")
    print(f"  FP margin received (30yr):       ${total_fp:>14,.0f}")
    print(f"  FP profit share (30yr):          ${total_ps:>14,.0f}")
    print(f"  FP end-of-term surplus (50%):    ${fp_windup_share:>14,.0f}")
    print(f"  Total FP revenue per mortgage:   ${total_fp + total_ps + fp_windup_share:>14,.0f}")

    # Percentile table
    print(f"\n--- Surplus Percentiles by Year ---")
    print(f"  {'Year':>4s}  {'Deficit%':>8s}  {'P1':>12s}  {'P10':>12s}  {'Median':>12s}  {'P90':>12s}  {'P99':>12s}")
    for yr in [1, 5, 10, 15, 20, 25, 30]:
        s = yearly_surplus[:, yr]
        dp = np.mean(s < 0) * 100
        print(f"  {yr:4d}  {dp:7.2f}%  ${np.percentile(s,1):>11,.0f}  ${np.percentile(s,10):>11,.0f}  "
              f"${np.median(s):>11,.0f}  ${np.percentile(s,90):>11,.0f}  ${np.percentile(s,99):>11,.0f}")

    # Compare with spreadsheet (1000 paths)
    print(f"\n--- Comparison with v14b Spreadsheet (1,000 paths) ---")
    ss_poc_yr30 = 14.8  # from R3
    ss_mean_surplus_yr30 = 3_510_905  # from AL7 (different because only 1000 paths)
    ss_median_surplus_yr30 = 2_319_932  # from AL8
    ss_lmi_fair = 32_314  # from M3
    ss_lmi_loaded = 48_472  # from P3
    ss_tail_fair = 1_386  # from V3
    ss_tail_poc = 1.4  # from Y3

    print(f"  Metric                SS (1K)         MC (50K)")
    print(f"  PoC Year 30:          {ss_poc_yr30:.1f}%          {final_deficit_prob:.2f}%")
    print(f"  Mean surplus:         ${ss_mean_surplus_yr30:>12,.0f}  ${mean_surplus:>12,.0f}")
    print(f"  Median surplus:       ${ss_median_surplus_yr30:>12,.0f}  ${median_surplus:>12,.0f}")
    print(f"  LMI fair premium:     ${ss_lmi_fair:>12,.0f}  ${lmi_fair_premium_pv:>12,.0f}")
    print(f"  LMI loaded premium:   ${ss_lmi_loaded:>12,.0f}  ${lmi_fair_premium_pv*1.5:>12,.0f}")
    print(f"  Tail risk fair:       ${ss_tail_fair:>12,.0f}  ${tail_fair_premium_pv:>12,.0f}")
    print(f"  Tail risk PoC:        {ss_tail_poc:.1f}%          {tail_poc:.2f}%")

    # ============================================================
    # SAVE RESULTS
    # ============================================================
    results = {
        'model_version': 'v14b',
        'n_paths': N_PATHS,
        'parameters': {
            'home_value': HOME_VALUE,
            'lvr': LVR,
            'initial_loan': INITIAL_LOAN,
            'loan_type': LOAN_TYPE,
            'tenure_years': TENURE_YEARS,
            'annuity_pa': ANNUITY_PA,
            'annuity_term_years': ANNUITY_TERM_YEARS,
            'equity_mean': EQUITY_MEAN,
            'equity_vol': EQUITY_VOL,
            'buffer_cap': BUFFER_CAP,
            'buffer_floor': BUFFER_FLOOR,
            'wholesale_margin': WHOLESALE_MARGIN,
            'retail_margin': RETAIL_MARGIN,
            'hedging_fee': HEDGING_FEE,
            'fp_margin': FP_MARGIN,
            'lmi_upfront_pct': LMI_UPFRONT_PCT,
            'tail_risk_annual_pct': TAIL_RISK_ANNUAL_PCT,
            'cash_rate_initial': CASH_RATE_INITIAL,
            'cash_rate_theta': CASH_RATE_THETA,
            'cash_rate_kappa': CASH_RATE_KAPPA,
            'cash_rate_sigma': CASH_RATE_SIGMA,
            'correlation': CASH_RATE_EQUITY_CORR,
            'holiday_entry_level': HOLIDAY_ENTRY_LEVEL,
            'holiday_exit_level': HOLIDAY_EXIT_LEVEL,
            'profit_share_years': PROFIT_SHARE_YEARS,
            'profit_share_pct': PROFIT_SHARE_PCT,
            'collar_price': collar_price,
        },
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
        'insurance': {
            'top_cover_quantile': top_cover_quantile,
            'top_cover_limit': round(float(top_cover_limit), 0),
            'lmi': {
                'poc': round(float(lmi_poc), 2),
                'fair_premium_pv': round(float(lmi_fair_premium_pv), 0),
                'loaded_premium': round(float(lmi_fair_premium_pv * 1.5), 0),
                'pct_max_loan': round(float(100*lmi_fair_premium_pv*1.5/MAX_LOAN), 4),
                'cond_expected_deficit': round(float(lmi_cond_deficit), 0),
            },
            'tail_risk': {
                'poc': round(float(tail_poc), 2),
                'fair_premium_pv': round(float(tail_fair_premium_pv), 0),
                'loaded_premium': round(float(tail_fair_premium_pv * 1.5), 0),
                'pct_max_loan': round(float(100*tail_fair_premium_pv*1.5/MAX_LOAN), 4),
            },
            'combined': {
                'total_fair_premium': round(float(total_fair_premium), 0),
                'total_loaded_premium': round(float(total_fair_loaded), 0),
                'pct_max_loan': round(float(100*total_fair_loaded/MAX_LOAN), 4),
            },
        },
        'deficit_by_year': [round(d, 2) for d in deficit_by_year],
        'mean_holidays_per_year': [round(float(h), 3) for h in mean_holidays_per_year],
        'mean_total_holiday_years': round(float(np.mean(total_holiday_years)), 2),
        'pct_zero_holidays': round(float(np.mean(total_holiday_years == 0)*100), 1),
        'profit_share_means': [round(float(np.mean(profit_share_by_period[:, i])), 0) for i in range(5)],
        'total_mean_profit_share': round(float(np.mean(cumulative_profit_share)), 0),
        'loan_trajectory': [round(float(l), 0) for l in loan_from_funder],
        'revenue': {
            'funder_interest_30yr': round(float(total_funder), 0),
            'lender_nim_30yr': round(float(total_lender), 0),
            'fp_margin_30yr': round(float(total_fp), 0),
            'fp_profit_share_30yr': round(float(total_ps), 0),
            'fp_windup_share_50pct': round(float(fp_windup_share), 0),
            'total_fp_revenue': round(float(total_fp + total_ps + fp_windup_share), 0),
        },
        'surplus_percentiles_by_year': {},
        'mean_investment_by_year': {},
    }

    for yr in range(1, 31):
        s = yearly_surplus[:, yr]
        inv = yearly_investment[:, yr]
        results['surplus_percentiles_by_year'][str(yr)] = {
            'deficit_pct': round(float(np.mean(s < 0) * 100), 2),
            'p1': round(float(np.percentile(s, 1)), 0),
            'p5': round(float(np.percentile(s, 5)), 0),
            'p10': round(float(np.percentile(s, 10)), 0),
            'median': round(float(np.median(s)), 0),
            'mean': round(float(np.mean(s)), 0),
            'p90': round(float(np.percentile(s, 90)), 0),
            'p95': round(float(np.percentile(s, 95)), 0),
            'p99': round(float(np.percentile(s, 99)), 0),
        }
        results['mean_investment_by_year'][str(yr)] = round(float(np.mean(inv)), 0)

    with open('monte_carlo_v14b_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to monte_carlo_v14b_results.json")

    return results


if __name__ == '__main__':
    results = run_simulation()
