#!/usr/bin/env python3
"""
50,000-path Monte Carlo simulation of the FutureProof EPM v14d (Optimised).

Reflects the v14d Optimised Parameters workbook (April 2026):
  - Home Value: $1,500,000
  - LVR: 80% => Max Loan $1,200,000
  - Annuity: $30,000/yr x 10yr => Initial Loan $900,000
    (was $26,250/yr / Initial $937,500 in v14c)
  - Retail Margin (NIM): 0.70%   (was 0.75% in v14c)
  - LMI Upfront: 1.25%           (was 0.80% in v14c)
  - Reinsurance tail (annual):  0.10% (was 0.05% in v14c)
  - Total variable costs: 3.45%  (was 3.50% in v14c)
  - Profit share: every 3 years, 10% (was 5 years / 10% in v14c)
  - All other parameters unchanged: mu=9.2%, sigma=16.6%, kappa=0.163,
    cap/floor 1.40/0.80, FP margin 0.50%, hedge 0.25%, wholesale 2.00%.
"""

import numpy as np
import time
import json

# ============================================================================
# ⛔ QUARANTINED 2026-06-01 — DO NOT RUN. CONFIRMED BUGGY ENGINE.
# This engine advances the equity mean-reversion trend by (1+mu) BEFORE applying
# the reversion term (equity_trend *= (1+eq_mu) then mean_rev_component = kappa *
# (equity_trend - equity_index)), so prices revert toward a target inflated by ~9%
# → optimistically biased PoD (~5.55% vs Pavel's authoritative xlsm 8.37% on
# identical inputs). Running it OVERWRITES monte_carlo_v14d_optimised_results.json —
# the file the live paper generators read — re-corrupting every headline number.
# USE THE VALIDATED ENGINE epm_engine_v14d.py INSTEAD (ties out to the xlsm).
# See deprecated_buggy_engines/README.md.
# ============================================================================
import sys as _sys
_sys.exit("QUARANTINED buggy trend-lag engine (PoD ~5.55% vs xlsm 8.37%). Do NOT run: "
          "it overwrites monte_carlo_v14d_optimised_results.json (read by the live "
          "generators). Use the validated epm_engine_v14d.py instead.")

# v14d OPTIMISED PARAMETERS
HOME_VALUE = 1_500_000
LVR = 0.80
MAX_LOAN = HOME_VALUE * LVR                      # $1,200,000
ANNUITY_PA = 30_000
ANNUITY_TERM_YEARS = 10
INITIAL_LOAN = int(MAX_LOAN - ANNUITY_PA * ANNUITY_TERM_YEARS)  # $900,000
LOAN_TYPE = "PI"

TENURE_YEARS = 30

# Costs
WHOLESALE_MARGIN = 0.02
RETAIL_MARGIN = 0.007       # v14d: 0.70%
HEDGING_FEE = 0.0025
FP_MARGIN = 0.005
LMI_UPFRONT_PCT = 0.0125    # v14d: 1.25%
TAIL_RISK_ANNUAL_PCT = 0.001  # v14d: 0.10%

# Investment — GBM with Stochastic Drift + Mean Reversion (Shevchenko, April 2026)
EQUITY_MEAN = 0.092
EQUITY_VOL = 0.166
EQUITY_MEAN_REV = 0.163
BUFFER_CAP = 1.40
BUFFER_FLOOR = 0.80

# Cash rate (Ornstein-Uhlenbeck)
CASH_RATE_INITIAL = 0.0421
CASH_RATE_THETA = 0.0213
CASH_RATE_KAPPA = 0.24
CASH_RATE_SIGMA = 0.0122
CASH_RATE_EQUITY_CORR = 0.30

# Holiday
HOLIDAY_ENTRY_LEVEL = 0.75
HOLIDAY_EXIT_LEVEL = 1.458

# Profit share — v14d: every 3 years
PROFIT_SHARE_YEARS = 3
PROFIT_SHARE_PCT = 0.10

# Collar
COLLAR_PRICE = 0.00046

# Simulation
N_PATHS = 50_000
SEED = 42


def compute_loan_trajectory():
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


def run_simulation(equity_mean_rev_override=None, equity_mean_override=None,
                   equity_vol_override=None, label=None):
    eq_kappa = equity_mean_rev_override if equity_mean_rev_override is not None else EQUITY_MEAN_REV
    eq_mu = equity_mean_override if equity_mean_override is not None else EQUITY_MEAN
    eq_sigma = equity_vol_override if equity_vol_override is not None else EQUITY_VOL

    if label is None:
        label = f"kappa={eq_kappa:.3f}, mu={eq_mu:.3f}, sigma={eq_sigma:.3f}"

    print(f"\nRunning {N_PATHS:,} path Monte Carlo (v14d-OPTIMISED) [{label}]...")
    print(f"  Home=${HOME_VALUE:,} LVR={LVR*100:.0f}% MaxLoan=${MAX_LOAN:,.0f}")
    print(f"  Annuity=${ANNUITY_PA:,}/yr x {ANNUITY_TERM_YEARS}yr  InitLoan=${INITIAL_LOAN:,}")
    print(f"  Equity: mu={eq_mu*100:.2f}%, sigma={eq_sigma*100:.2f}%, kappa={eq_kappa:.3f}")
    print(f"  Costs: WH={WHOLESALE_MARGIN*100:.2f}% NIM={RETAIL_MARGIN*100:.2f}% hedge={HEDGING_FEE*100:.2f}% FP={FP_MARGIN*100:.2f}%")
    print(f"  LMI upfront: {LMI_UPFRONT_PCT*100:.2f}%  Tail risk annual: {TAIL_RISK_ANNUAL_PCT*100:.3f}%")
    print(f"  Profit share: every {PROFIT_SHARE_YEARS}yr at {PROFIT_SHARE_PCT*100:.0f}% of surplus")
    start = time.time()

    rng = np.random.default_rng(SEED)
    loan_from_funder = compute_loan_trajectory()
    peak_loan = float(np.max(loan_from_funder))
    upfront_LMI = peak_loan * LMI_UPFRONT_PCT
    holiday_entry_threshold = INITIAL_LOAN * HOLIDAY_ENTRY_LEVEL
    holiday_exit_threshold = INITIAL_LOAN * HOLIDAY_EXIT_LEVEL
    initial_investment = INITIAL_LOAN - upfront_LMI

    z1 = rng.standard_normal((N_PATHS, TENURE_YEARS))
    z2_raw = rng.standard_normal((N_PATHS, TENURE_YEARS))
    rho = CASH_RATE_EQUITY_CORR
    z2 = rho * z1 + np.sqrt(1 - rho**2) * z2_raw

    investment = np.full(N_PATHS, initial_investment, dtype=np.float64)
    cash_rate = np.full(N_PATHS, CASH_RATE_INITIAL, dtype=np.float64)
    equity_index = np.ones(N_PATHS, dtype=np.float64)
    equity_trend = np.ones(N_PATHS, dtype=np.float64)

    holiday_entry_flag = np.zeros(N_PATHS, dtype=bool)
    holiday_count = np.zeros(N_PATHS, dtype=np.float64)
    holiday_account = np.zeros(N_PATHS, dtype=np.float64)
    repayment_step = np.zeros(N_PATHS, dtype=np.float64)
    funder_interest_tot = np.zeros(N_PATHS, dtype=np.float64)
    interest_charged_tot = np.zeros(N_PATHS, dtype=np.float64)

    yearly_surplus = np.zeros((N_PATHS, TENURE_YEARS + 1))
    yearly_investment = np.zeros((N_PATHS, TENURE_YEARS + 1))
    yearly_holidays = np.zeros((N_PATHS, TENURE_YEARS))
    yearly_loan = np.zeros(TENURE_YEARS + 1)
    cumulative_profit_share = np.zeros(N_PATHS)
    n_share_periods = (TENURE_YEARS - 1) // PROFIT_SHARE_YEARS
    profit_share_by_period = np.zeros((N_PATHS, max(n_share_periods, 1)))

    yearly_funder_received = np.zeros((N_PATHS, TENURE_YEARS))
    yearly_lender_nim = np.zeros((N_PATHS, TENURE_YEARS))
    yearly_fp_margin = np.zeros((N_PATHS, TENURE_YEARS))

    interest_deficit = np.zeros(N_PATHS)
    yearly_surplus[:, 0] = investment - loan_from_funder[0] + interest_deficit
    yearly_investment[:, 0] = investment.copy()
    yearly_loan[0] = loan_from_funder[0]

    investment *= (1 - COLLAR_PRICE)

    for t in range(1, TENURE_YEARS + 1):
        year_idx = t - 1

        w = np.exp(-CASH_RATE_KAPPA)
        v = CASH_RATE_SIGMA * np.sqrt((1 - w**2) / (2 * CASH_RATE_KAPPA))
        cash_rate = cash_rate * w + CASH_RATE_THETA * (1 - w) + v * z2[:, year_idx]
        cash_rate = np.maximum(cash_rate, 0)

        equity_trend *= (1 + eq_mu)
        gbm_component = equity_index * (1 + eq_mu + eq_sigma * z1[:, year_idx])
        mean_rev_component = eq_kappa * (equity_trend - equity_index)
        new_equity_index = gbm_component + mean_rev_component
        new_equity_index = np.maximum(new_equity_index, 0.01)

        raw_return = new_equity_index / equity_index - 1
        equity_index = new_equity_index
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

        interest_charged = funder_interest + interest_holiday + repayment_holiday
        interest_charged_tot += interest_charged
        interest_deficit = funder_interest_tot - interest_charged_tot

        retailer_nim = -RETAIL_MARGIN * avg_loan
        fp_margin_payment = -FP_MARGIN * investment
        hedging_fee_payment = -HEDGING_FEE * investment
        tail_risk_premium = -TAIL_RISK_ANNUAL_PCT * investment

        yearly_funder_received[:, year_idx] = -interest_charged
        yearly_lender_nim[:, year_idx] = -retailer_nim
        yearly_fp_margin[:, year_idx] = -fp_margin_payment

        if t == TENURE_YEARS:
            retailer_nim = -RETAIL_MARGIN * loan_from_funder[t - 1] / 2
            interest_charged = -funder_funding_cost * loan_from_funder[t - 1] / 2

        investment_return = investment * hedged_return

        principal_repayment = 0
        if t > ANNUITY_TERM_YEARS and LOAN_TYPE == "PI":
            pp = -(loan_from_funder[t - 1] - loan_from_funder[t])
            principal_repayment = pp

        investment = (investment + investment_return + interest_charged +
                      retailer_nim + fp_margin_payment + hedging_fee_payment +
                      tail_risk_premium + principal_repayment)

        surplus = investment - loan_from_funder[t] + interest_deficit
        yearly_loan[t] = loan_from_funder[t]

        if t < TENURE_YEARS and t % PROFIT_SHARE_YEARS == 0:
            profit_share = np.where(surplus > 0, surplus * PROFIT_SHARE_PCT, 0)
            investment -= profit_share
            cumulative_profit_share += profit_share
            period_idx = (t // PROFIT_SHARE_YEARS) - 1
            if period_idx < profit_share_by_period.shape[1]:
                profit_share_by_period[:, period_idx] = profit_share

        if t == TENURE_YEARS:
            windup = np.maximum(surplus, 0)
            investment -= windup

        if t < TENURE_YEARS:
            investment *= (1 - COLLAR_PRICE)

        yearly_surplus[:, t] = surplus
        yearly_investment[:, t] = investment

    elapsed = time.time() - start
    print(f"  ...done in {elapsed:.1f}s")

    final_surplus = yearly_surplus[:, -1]
    deficit_by_year = []
    for yr in range(1, TENURE_YEARS + 1):
        dp = np.mean(yearly_surplus[:, yr] < 0) * 100
        deficit_by_year.append(dp)

    final_deficit_prob = float(np.mean(final_surplus < 0) * 100)
    se_deficit = float(np.sqrt(final_deficit_prob/100 * (1 - final_deficit_prob/100) / N_PATHS) * 100)
    mean_surplus = float(np.mean(final_surplus))
    median_surplus = float(np.median(final_surplus))
    p1 = float(np.percentile(final_surplus, 1))
    p5 = float(np.percentile(final_surplus, 5))
    p10 = float(np.percentile(final_surplus, 10))
    p25 = float(np.percentile(final_surplus, 25))
    p75 = float(np.percentile(final_surplus, 75))
    p90 = float(np.percentile(final_surplus, 90))
    p95 = float(np.percentile(final_surplus, 95))
    p99 = float(np.percentile(final_surplus, 99))

    discount = np.exp(-CASH_RATE_THETA * TENURE_YEARS)
    deficit_mask = final_surplus < 0
    n_deficit = int(np.sum(deficit_mask))
    top_cover_quantile = 0.20
    if n_deficit > 0:
        top_cover_limit = float(np.percentile(final_surplus[deficit_mask], top_cover_quantile * 100))
    else:
        top_cover_limit = 0.0

    lmi_claims_mild = np.where(deficit_mask & (final_surplus >= top_cover_limit),
                                -final_surplus, 0)
    lmi_claims_severe = np.where(deficit_mask & (final_surplus < top_cover_limit),
                                  -top_cover_limit, 0)
    total_lmi_claims = lmi_claims_mild + lmi_claims_severe

    lmi_fair_premium_pv = float(discount * np.mean(total_lmi_claims))
    lmi_poc = float(np.mean(deficit_mask) * 100)
    lmi_cond_deficit = float(np.mean(final_surplus[deficit_mask])) if n_deficit > 0 else 0.0

    deep_deficit_mask = deficit_mask & (final_surplus < top_cover_limit)
    tail_claims = np.where(deep_deficit_mask, -(final_surplus - top_cover_limit), 0)
    tail_fair_premium_pv = float(discount * np.mean(tail_claims))
    tail_poc = float(np.mean(deep_deficit_mask) * 100)

    total_fair_premium = lmi_fair_premium_pv + tail_fair_premium_pv
    total_fair_loaded = total_fair_premium * 1.5

    print(f"  PoC={final_deficit_prob:.2f}% (SE={se_deficit:.2f}%)  "
          f"LMI_fair=${lmi_fair_premium_pv:,.0f}  LMI_loaded=${lmi_fair_premium_pv*1.5:,.0f} "
          f"({100*lmi_fair_premium_pv*1.5/peak_loan:.3f}%)  "
          f"Tail_fair=${tail_fair_premium_pv:,.0f}")

    mean_holidays_per_year = np.mean(yearly_holidays, axis=0)
    total_holiday_years = np.sum(yearly_holidays, axis=1)

    total_funder = float(np.mean(np.sum(yearly_funder_received, axis=1)))
    total_lender = float(np.mean(np.sum(yearly_lender_nim, axis=1)))
    total_fp = float(np.mean(np.sum(yearly_fp_margin, axis=1)))
    total_ps = float(np.mean(cumulative_profit_share))
    mean_windup = float(np.mean(np.maximum(final_surplus, 0)))
    fp_windup_share = mean_windup * 0.5

    results = {
        'model_version': 'v14d-OPTIMISED',
        'label': label,
        'n_paths': N_PATHS,
        'parameters': {
            'home_value': HOME_VALUE,
            'lvr': LVR,
            'max_loan': MAX_LOAN,
            'initial_loan': INITIAL_LOAN,
            'loan_type': LOAN_TYPE,
            'tenure_years': TENURE_YEARS,
            'annuity_pa': ANNUITY_PA,
            'annuity_term_years': ANNUITY_TERM_YEARS,
            'equity_mean': eq_mu,
            'equity_vol': eq_sigma,
            'equity_mean_rev': eq_kappa,
            'equity_model': 'GBM with Stochastic Drift + Mean Reversion',
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
        'peak_loan': round(peak_loan, 0),
        'upfront_lmi': round(float(upfront_LMI), 0),
        'deficit_prob': round(final_deficit_prob, 2),
        'deficit_se': round(se_deficit, 2),
        'mean_surplus': round(mean_surplus, 0),
        'median_surplus': round(median_surplus, 0),
        'p1': round(p1, 0),
        'p5': round(p5, 0),
        'p10': round(p10, 0),
        'p25': round(p25, 0),
        'p75': round(p75, 0),
        'p90': round(p90, 0),
        'p95': round(p95, 0),
        'p99': round(p99, 0),
        'insurance': {
            'top_cover_quantile': top_cover_quantile,
            'top_cover_limit': round(top_cover_limit, 0),
            'lmi': {
                'poc': round(lmi_poc, 2),
                'fair_premium_pv': round(lmi_fair_premium_pv, 0),
                'loaded_premium': round(lmi_fair_premium_pv * 1.5, 0),
                'pct_max_loan': round(100*lmi_fair_premium_pv*1.5/peak_loan, 4),
                'cond_expected_deficit': round(lmi_cond_deficit, 0),
            },
            'tail_risk': {
                'poc': round(tail_poc, 2),
                'fair_premium_pv': round(tail_fair_premium_pv, 0),
                'loaded_premium': round(tail_fair_premium_pv * 1.5, 0),
                'pct_max_loan': round(100*tail_fair_premium_pv*1.5/peak_loan, 4),
            },
            'combined': {
                'total_fair_premium': round(total_fair_premium, 0),
                'total_loaded_premium': round(total_fair_loaded, 0),
                'pct_max_loan': round(100*total_fair_loaded/peak_loan, 4),
            },
        },
        'deficit_by_year': [round(d, 2) for d in deficit_by_year],
        'mean_holidays_per_year': [round(float(h), 3) for h in mean_holidays_per_year],
        'mean_total_holiday_years': round(float(np.mean(total_holiday_years)), 2),
        'pct_zero_holidays': round(float(np.mean(total_holiday_years == 0)*100), 1),
        'profit_share_means': [round(float(np.mean(profit_share_by_period[:, i])), 0)
                                for i in range(profit_share_by_period.shape[1])],
        'total_mean_profit_share': round(float(np.mean(cumulative_profit_share)), 0),
        'loan_trajectory': [round(float(l), 0) for l in loan_from_funder],
        'revenue': {
            'funder_interest_30yr': round(total_funder, 0),
            'lender_nim_30yr': round(total_lender, 0),
            'fp_margin_30yr': round(total_fp, 0),
            'fp_profit_share_30yr': round(total_ps, 0),
            'fp_windup_share_50pct': round(fp_windup_share, 0),
            'total_fp_revenue': round(total_fp + total_ps + fp_windup_share, 0),
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

    return results


if __name__ == '__main__':
    base = run_simulation(label='base')
    with open('monte_carlo_v14d_optimised_results.json', 'w') as f:
        json.dump(base, f, indent=2)
    print("\n  -> monte_carlo_v14d_optimised_results.json")

    kappa_sensitivity = {}
    for k in [0.00, 0.08, 0.12, 0.163, 0.20, 0.30]:
        r = run_simulation(equity_mean_rev_override=k, label=f'kappa={k:.3f}')
        kappa_sensitivity[f'{k:.3f}'] = {
            'kappa': k,
            'poc': r['insurance']['lmi']['poc'],
            'fair_premium': r['insurance']['lmi']['fair_premium_pv'],
            'loaded_premium': r['insurance']['lmi']['loaded_premium'],
            'pct_max_loan': r['insurance']['lmi']['pct_max_loan'],
            'cond_expected_deficit': r['insurance']['lmi']['cond_expected_deficit'],
            'mean_surplus': r['mean_surplus'],
            'median_surplus': r['median_surplus'],
            'p5': r['p5'],
        }

    sigma_sensitivity = {}
    for s in [0.12, 0.15, 0.166, 0.20, 0.25]:
        r = run_simulation(equity_vol_override=s, label=f'sigma={s:.3f}')
        sigma_sensitivity[f'{s:.3f}'] = {
            'sigma': s,
            'poc': r['insurance']['lmi']['poc'],
            'fair_premium': r['insurance']['lmi']['fair_premium_pv'],
            'loaded_premium': r['insurance']['lmi']['loaded_premium'],
            'pct_max_loan': r['insurance']['lmi']['pct_max_loan'],
            'mean_surplus': r['mean_surplus'],
        }

    mu_sensitivity = {}
    for m in [0.06, 0.075, 0.092, 0.105, 0.12]:
        r = run_simulation(equity_mean_override=m, label=f'mu={m:.3f}')
        mu_sensitivity[f'{m:.3f}'] = {
            'mu': m,
            'poc': r['insurance']['lmi']['poc'],
            'fair_premium': r['insurance']['lmi']['fair_premium_pv'],
            'loaded_premium': r['insurance']['lmi']['loaded_premium'],
            'pct_max_loan': r['insurance']['lmi']['pct_max_loan'],
            'mean_surplus': r['mean_surplus'],
        }

    comprehensive = {
        'base': base,
        'kappa_sensitivity': kappa_sensitivity,
        'sigma_sensitivity': sigma_sensitivity,
        'mu_sensitivity': mu_sensitivity,
    }
    with open('monte_carlo_v14d_optimised_comprehensive_results.json', 'w') as f:
        json.dump(comprehensive, f, indent=2)
    print("\n  -> monte_carlo_v14d_optimised_comprehensive_results.json")
    print("\nDone.")
