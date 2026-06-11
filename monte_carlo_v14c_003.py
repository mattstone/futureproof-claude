#!/usr/bin/env python3
"""
50,000-path Monte Carlo simulation of the FutureProof EPM v14c (003) model.

Key changes from v14b:
  - Equity model: GBM+MeanRev (Shevchenko paper Section 3)
  - Expected return: 9.2% (was 9.3% GBM)
  - Equity vol: 16.6% (was 12.0%)
  - Mean reversion speed: 0.163 (new)
  - Wholesale margin: 2.0% (unchanged from v14b)
  - NIM: 0.70%
  - FP margin: 0.50%
  - Buffer cap: 1.40 (+40% upside cap)
  - Buffer floor: 0.80 (unchanged)
  - Annuity: $30,000/yr
  - Initial Loan: $1,300,000 (= $1,600,000 - $30,000*10)
  - Put-call hedging cost: +0.00046 (40/80 collar — tiny net cost)
  - LMI upfront: 0.65%
  - Tail risk annual: 0.05%
  - Variable costs total: 3.50%
  - Holiday entry: 0.75
  - Cash rate: theta=2.13%, kappa=0.24, sigma=1.22% (lower speed, lower vol)
  - Correlation: 0.30 (was 0.21)
"""

import numpy as np
import time
import json

# ============================================================
# v14c (003) PARAMETERS
# ============================================================
HOME_VALUE = 2_000_000
LVR = 0.80
MAX_LOAN = HOME_VALUE * LVR  # $1,600,000
ANNUITY_PA = 30_000
ANNUITY_TERM_YEARS = 10
INITIAL_LOAN = int(MAX_LOAN - ANNUITY_PA * ANNUITY_TERM_YEARS)  # $1,300,000
LOAN_TYPE = "PI"

TENURE_YEARS = 30

# Costs
WHOLESALE_MARGIN = 0.02
RETAIL_MARGIN = 0.007
HEDGING_FEE = 0.0025
FP_MARGIN = 0.005
LMI_UPFRONT_PCT = 0.0065
TAIL_RISK_ANNUAL_PCT = 0.0005

# Investment — GBM+MeanRev (Shevchenko Section 3)
EQUITY_MEAN = 0.092      # expected return (GBM+MeanRev)
EQUITY_VOL = 0.166       # volatility (GBM+MeanRev)
EQUITY_MEAN_REV = 0.163  # mean reversion speed (gamma_B)
BUFFER_CAP = 1.40        # wide cap (+40% upside)
BUFFER_FLOOR = 0.80

# Cash rate (Ornstein-Uhlenbeck)
CASH_RATE_INITIAL = 0.0421
CASH_RATE_THETA = 0.0213
CASH_RATE_KAPPA = 0.24
CASH_RATE_SIGMA = 0.0122
CASH_RATE_EQUITY_CORR = 0.30

# Holiday mechanism
HOLIDAY_ENTRY_LEVEL = 0.75
HOLIDAY_EXIT_LEVEL = 1.458

# Profit share
PROFIT_SHARE_YEARS = 5
PROFIT_SHARE_PCT = 0.10

# Collar
COLLAR_PRICE = 0.00046   # put-call hedging cost (40/80 collar — tiny net cost)

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

    for t in range(1, TENURE_YEARS + 1):
        if t <= ANNUITY_TERM_YEARS:
            loan[t] = loan[t - 1] + ANNUITY_PA
        else:
            loan[t] = loan[t - 1]

    peak = loan[ANNUITY_TERM_YEARS]
    remaining_years = TENURE_YEARS - ANNUITY_TERM_YEARS
    if remaining_years > 0:
        annual_principal = peak / remaining_years
        for t in range(ANNUITY_TERM_YEARS + 1, TENURE_YEARS + 1):
            loan[t] = max(loan[t - 1] - annual_principal, 0)

    return loan


# ============================================================
# SIMULATION ENGINE
# ============================================================
def run_simulation():
    print(f"Running {N_PATHS:,} path Monte Carlo simulation (v14c-003)...")
    print(f"Parameters: Loan=${INITIAL_LOAN:,}, Annuity=${ANNUITY_PA:,}/yr, PI amortisation")
    print(f"  Equity (GBM+MeanRev): mean={EQUITY_MEAN*100:.1f}%, vol={EQUITY_VOL*100:.1f}%, gamma={EQUITY_MEAN_REV}")
    print(f"  Buffer: Cap={BUFFER_CAP*100:.0f}%, Floor={BUFFER_FLOOR*100:.0f}%")
    print(f"  Costs: wholesale={WHOLESALE_MARGIN*100:.1f}%, NIM={RETAIL_MARGIN*100:.2f}%, hedge={HEDGING_FEE*100:.2f}%, FP={FP_MARGIN*100:.1f}%")
    print(f"  Total variable costs: {(WHOLESALE_MARGIN+RETAIL_MARGIN+HEDGING_FEE+FP_MARGIN)*100:.2f}%")
    print(f"  Cash rate: theta={CASH_RATE_THETA*100:.2f}%, kappa={CASH_RATE_KAPPA}, sigma={CASH_RATE_SIGMA*100:.2f}%")
    print(f"  Correlation: {CASH_RATE_EQUITY_CORR}")
    print(f"  Collar: {COLLAR_PRICE*100:.3f}%")
    start = time.time()

    rng = np.random.default_rng(SEED)

    loan_from_funder = compute_loan_trajectory()
    peak_loan = np.max(loan_from_funder)

    upfront_LMI = peak_loan * LMI_UPFRONT_PCT

    holiday_entry_threshold = INITIAL_LOAN * HOLIDAY_ENTRY_LEVEL
    holiday_exit_threshold = INITIAL_LOAN * HOLIDAY_EXIT_LEVEL

    print(f"\n  Peak loan (Year {ANNUITY_TERM_YEARS}): ${peak_loan:,.0f}")
    print(f"  Loan at Year 30: ${loan_from_funder[TENURE_YEARS]:,.0f}")
    print(f"  Annual principal repayment (Yr 11-30): ${peak_loan / 20:,.0f}")
    print(f"  Upfront LMI: ${upfront_LMI:,.0f}")
    print(f"  Holiday entry: ${holiday_entry_threshold:,.0f}, exit: ${holiday_exit_threshold:,.0f}")

    initial_investment = INITIAL_LOAN - upfront_LMI
    print(f"  Initial investment: ${initial_investment:,.0f}")

    # Generate correlated random numbers
    z1 = rng.standard_normal((N_PATHS, TENURE_YEARS))
    z2_raw = rng.standard_normal((N_PATHS, TENURE_YEARS))
    rho = CASH_RATE_EQUITY_CORR
    z2 = rho * z1 + np.sqrt(1 - rho**2) * z2_raw

    # Initialize
    investment = np.full(N_PATHS, initial_investment, dtype=np.float64)
    cash_rate = np.full(N_PATHS, CASH_RATE_INITIAL, dtype=np.float64)

    # GBM+MeanRev: track synthetic equity index per path
    equity_index = np.ones(N_PATHS, dtype=np.float64)
    equity_trend = np.ones(N_PATHS, dtype=np.float64)  # M(t) = deterministic trend

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

    yearly_funder_received = np.zeros((N_PATHS, TENURE_YEARS))
    yearly_lender_nim = np.zeros((N_PATHS, TENURE_YEARS))
    yearly_fp_margin = np.zeros((N_PATHS, TENURE_YEARS))

    interest_deficit = np.zeros(N_PATHS)
    yearly_surplus[:, 0] = investment - loan_from_funder[0] + interest_deficit
    yearly_investment[:, 0] = investment.copy()
    yearly_loan[0] = loan_from_funder[0]

    # Apply collar price at start
    investment *= (1 - COLLAR_PRICE)

    for t in range(1, TENURE_YEARS + 1):
        year_idx = t - 1

        # 1. Cash rate: Ornstein-Uhlenbeck (exact discretisation)
        w = np.exp(-CASH_RATE_KAPPA)
        v = CASH_RATE_SIGMA * np.sqrt((1 - w**2) / (2 * CASH_RATE_KAPPA))
        cash_rate = cash_rate * w + CASH_RATE_THETA * (1 - w) + v * z2[:, year_idx]
        cash_rate = np.maximum(cash_rate, 0)

        # 2. Equity returns: GBM+MeanRev (Shevchenko Section 3)
        # S(t+1) = S(t)(1 + μ + σε) + γ(M(t) - S(t))
        # where M(t) = deterministic trend growing at μ
        equity_trend *= (1 + EQUITY_MEAN)
        gbm_component = equity_index * (1 + EQUITY_MEAN + EQUITY_VOL * z1[:, year_idx])
        mean_rev_component = EQUITY_MEAN_REV * (equity_trend - equity_index)
        new_equity_index = gbm_component + mean_rev_component
        new_equity_index = np.maximum(new_equity_index, 0.01)  # floor at near-zero

        raw_return = new_equity_index / equity_index - 1
        equity_index = new_equity_index

        # Apply buffer cap/floor
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
        yearly_funder_received[:, year_idx] = -interest_charged
        yearly_lender_nim[:, year_idx] = -retailer_nim
        yearly_fp_margin[:, year_idx] = -fp_margin_payment

        # Last year special handling
        if t == TENURE_YEARS:
            retailer_nim = -RETAIL_MARGIN * loan_from_funder[t - 1] / 2
            interest_charged = -funder_funding_cost * loan_from_funder[t - 1] / 2

        # 7. Investment return
        investment_return = investment * hedged_return

        # 8. Principal repayment
        principal_repayment = 0
        if t > ANNUITY_TERM_YEARS and LOAN_TYPE == "PI":
            pp = -(loan_from_funder[t - 1] - loan_from_funder[t])
            principal_repayment = pp

        # 9. Update investment
        investment = (investment + investment_return + interest_charged +
                      retailer_nim + fp_margin_payment + hedging_fee_payment +
                      tail_risk_premium + principal_repayment)

        # 10. Surplus
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
            investment *= (1 - COLLAR_PRICE)

        yearly_surplus[:, t] = surplus
        yearly_investment[:, t] = investment

    elapsed = time.time() - start
    print(f"\nSimulation completed in {elapsed:.1f} seconds")

    # ============================================================
    # RESULTS
    # ============================================================
    print("\n" + "="*70)
    print("RESULTS — v14c (003) — 50,000 PATH MONTE CARLO")
    print("="*70)

    final_surplus = yearly_surplus[:, -1]

    deficit_by_year = []
    print("\n--- Deficit Probability by Year ---")
    for yr in range(1, TENURE_YEARS + 1):
        dp = np.mean(yearly_surplus[:, yr] < 0) * 100
        deficit_by_year.append(dp)
        if yr in [1, 5, 10, 15, 20, 25, 30]:
            print(f"  Year {yr:2d}: {dp:.2f}%")

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

    # ============================================================
    # INSURANCE
    # ============================================================
    discount = np.exp(-CASH_RATE_THETA * TENURE_YEARS)
    deficit_mask = final_surplus < 0
    n_deficit = np.sum(deficit_mask)

    top_cover_quantile = 0.20  # v14c uses 20th percentile (per reinsurance doc)
    deficit_values = final_surplus[deficit_mask]
    if n_deficit > 0:
        top_cover_limit = np.percentile(deficit_values, top_cover_quantile * 100)
    else:
        top_cover_limit = 0

    lmi_claims_mild = np.where(deficit_mask & (final_surplus >= top_cover_limit),
                                -final_surplus, 0)
    lmi_claims_severe = np.where(deficit_mask & (final_surplus < top_cover_limit),
                                  -top_cover_limit, 0)
    total_lmi_claims = lmi_claims_mild + lmi_claims_severe

    lmi_fair_premium_pv = discount * np.mean(total_lmi_claims)
    lmi_poc = np.mean(deficit_mask) * 100
    lmi_cond_deficit = np.mean(final_surplus[deficit_mask]) if n_deficit > 0 else 0

    deep_deficit_mask = deficit_mask & (final_surplus < top_cover_limit)
    tail_claims = np.where(deep_deficit_mask, -(final_surplus - top_cover_limit), 0)
    tail_fair_premium_pv = discount * np.mean(tail_claims)
    tail_poc = np.mean(deep_deficit_mask) * 100

    total_fair_premium = lmi_fair_premium_pv + tail_fair_premium_pv
    total_fair_loaded = total_fair_premium * 1.5

    print(f"\n--- Insurance Structure ---")
    print(f"  Top cover limit (P{top_cover_quantile*100:.0f}): ${top_cover_limit:>14,.0f}")
    print(f"  LMI:")
    print(f"    PoC (Year 30):        {lmi_poc:.2f}%")
    print(f"    Cond. expected deficit: ${lmi_cond_deficit:>12,.0f}")
    print(f"    Fair premium (PV):    ${lmi_fair_premium_pv:>12,.0f}")
    print(f"    Fair + 50% loading:   ${lmi_fair_premium_pv * 1.5:>12,.0f}")
    print(f"    As % of max loan:     {100*lmi_fair_premium_pv*1.5/peak_loan:.3f}%")
    print(f"  Tail Risk Reinsurance:")
    print(f"    PoC (Year 30):        {tail_poc:.2f}%")
    print(f"    Fair premium (PV):    ${tail_fair_premium_pv:>12,.0f}")
    print(f"    Fair + 50% loading:   ${tail_fair_premium_pv * 1.5:>12,.0f}")
    print(f"  Combined:")
    print(f"    Total fair premium:   ${total_fair_premium:>12,.0f}")
    print(f"    Total loaded premium: ${total_fair_loaded:>12,.0f}")
    print(f"    As % of max loan:     {100*total_fair_loaded/peak_loan:.3f}%")

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
    print(f"\n--- Profit Share ---")
    for i, yr in enumerate([5, 10, 15, 20, 25]):
        if i < 5:
            mean_ps = np.mean(profit_share_by_period[:, i])
            print(f"  Year {yr:2d}: mean ${mean_ps:>12,.0f}")
    print(f"  Total mean profit share: ${np.mean(cumulative_profit_share):>12,.0f}")

    # Revenue
    total_funder = np.mean(np.sum(yearly_funder_received, axis=1))
    total_lender = np.mean(np.sum(yearly_lender_nim, axis=1))
    total_fp = np.mean(np.sum(yearly_fp_margin, axis=1))
    total_ps = np.mean(cumulative_profit_share)
    mean_windup = np.mean(np.maximum(final_surplus, 0))
    fp_windup_share = mean_windup * 0.5

    print(f"\n--- Revenue Streams ---")
    print(f"  Funder interest received (30yr): ${total_funder:>14,.0f}")
    print(f"  Lender NIM received (30yr):      ${total_lender:>14,.0f}")
    print(f"  FP margin received (30yr):       ${total_fp:>14,.0f}")
    print(f"  FP profit share (30yr):          ${total_ps:>14,.0f}")
    print(f"  FP end-of-term surplus (50%):    ${fp_windup_share:>14,.0f}")
    print(f"  Total FP revenue per mortgage:   ${total_fp + total_ps + fp_windup_share:>14,.0f}")

    # ============================================================
    # SAVE RESULTS
    # ============================================================
    results = {
        'model_version': 'v14c-003',
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
            'equity_mean_rev': EQUITY_MEAN_REV,
            'equity_model': 'GBM+MeanRev',
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
            'collar_price': COLLAR_PRICE,
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
                'pct_max_loan': round(float(100*lmi_fair_premium_pv*1.5/peak_loan), 4),
                'cond_expected_deficit': round(float(lmi_cond_deficit), 0),
            },
            'tail_risk': {
                'poc': round(float(tail_poc), 2),
                'fair_premium_pv': round(float(tail_fair_premium_pv), 0),
                'loaded_premium': round(float(tail_fair_premium_pv * 1.5), 0),
                'pct_max_loan': round(float(100*tail_fair_premium_pv*1.5/peak_loan), 4),
            },
            'combined': {
                'total_fair_premium': round(float(total_fair_premium), 0),
                'total_loaded_premium': round(float(total_fair_loaded), 0),
                'pct_max_loan': round(float(100*total_fair_loaded/peak_loan), 4),
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

    outfile = 'monte_carlo_v14c_003_results.json'
    with open(outfile, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to {outfile}")

    return results


if __name__ == '__main__':
    results = run_simulation()
