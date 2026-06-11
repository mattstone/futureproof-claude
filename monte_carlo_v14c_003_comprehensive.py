#!/usr/bin/env python3
"""
Comprehensive Monte Carlo analysis for v14c (003) — Actuarial Review
Runs: base case, sensitivity grid, correlation stress, rate stress, combined scenarios
Uses GBM+MeanRev equity model from Shevchenko paper
"""

import numpy as np
import time
import json

# ============================================================
# BASE PARAMETERS (v14c 003)
# ============================================================
HOME_VALUE = 2_000_000
LVR = 0.80
MAX_LOAN = HOME_VALUE * LVR
ANNUITY_PA = 30_000
ANNUITY_TERM = 10
INITIAL_LOAN = int(MAX_LOAN - ANNUITY_PA * ANNUITY_TERM)
TENURE = 30

WHOLESALE_MARGIN = 0.02
RETAIL_MARGIN = 0.007
HEDGING_FEE = 0.0025
FP_MARGIN = 0.005
LMI_UPFRONT_PCT = 0.0065
TAIL_RISK_ANNUAL = 0.0005

EQUITY_MEAN = 0.092
EQUITY_VOL = 0.166
EQUITY_MEAN_REV = 0.163
BUFFER_CAP = 1.40
BUFFER_FLOOR = 0.80

CASH_INITIAL = 0.0421
CASH_THETA = 0.0213
CASH_KAPPA = 0.24
CASH_SIGMA = 0.0122
CORRELATION = 0.30

HOLIDAY_ENTRY = 0.75
HOLIDAY_EXIT = 1.458
PROFIT_SHARE_YRS = 5
PROFIT_SHARE_PCT = 0.10
COLLAR_PRICE = 0.00046

N_PATHS = 50_000
SEED = 42


def compute_loan():
    loan = np.zeros(TENURE + 1)
    loan[0] = INITIAL_LOAN
    for t in range(1, TENURE + 1):
        if t <= ANNUITY_TERM:
            loan[t] = loan[t - 1] + ANNUITY_PA
        else:
            loan[t] = loan[t - 1]
    peak = loan[ANNUITY_TERM]
    remaining = TENURE - ANNUITY_TERM
    if remaining > 0:
        annual_p = peak / remaining
        for t in range(ANNUITY_TERM + 1, TENURE + 1):
            loan[t] = max(loan[t - 1] - annual_p, 0)
    return loan


def run_single(n_paths=N_PATHS, seed=SEED,
               equity_mean=EQUITY_MEAN, equity_vol=EQUITY_VOL,
               equity_mean_rev=EQUITY_MEAN_REV,
               correlation=CORRELATION,
               cash_theta=CASH_THETA, cash_kappa=CASH_KAPPA,
               cash_sigma=CASH_SIGMA, cash_initial=CASH_INITIAL,
               wholesale_margin=WHOLESALE_MARGIN):
    rng = np.random.default_rng(seed)
    loan = compute_loan()
    peak_loan = np.max(loan)
    upfront_lmi = peak_loan * LMI_UPFRONT_PCT
    h_entry = INITIAL_LOAN * HOLIDAY_ENTRY
    h_exit = INITIAL_LOAN * HOLIDAY_EXIT
    init_inv = INITIAL_LOAN - upfront_lmi

    z1 = rng.standard_normal((n_paths, TENURE))
    z2_raw = rng.standard_normal((n_paths, TENURE))
    z2 = correlation * z1 + np.sqrt(1 - correlation**2) * z2_raw

    investment = np.full(n_paths, init_inv, dtype=np.float64)
    cash_rate = np.full(n_paths, cash_initial, dtype=np.float64)
    eq_index = np.ones(n_paths, dtype=np.float64)
    eq_trend = np.ones(n_paths, dtype=np.float64)

    h_flag = np.zeros(n_paths, dtype=bool)
    h_count = np.zeros(n_paths, dtype=np.float64)
    h_acct = np.zeros(n_paths, dtype=np.float64)
    rep_step = np.zeros(n_paths, dtype=np.float64)
    funder_tot = np.zeros(n_paths, dtype=np.float64)
    interest_tot = np.zeros(n_paths, dtype=np.float64)

    yearly_surplus = np.zeros((n_paths, TENURE + 1))
    yearly_holidays = np.zeros((n_paths, TENURE))
    interest_deficit = np.zeros(n_paths)
    yearly_surplus[:, 0] = investment - loan[0]
    cumul_ps = np.zeros(n_paths)

    investment *= (1 - COLLAR_PRICE)

    for t in range(1, TENURE + 1):
        yi = t - 1

        # Cash rate OU
        w = np.exp(-cash_kappa)
        v = cash_sigma * np.sqrt((1 - w**2) / (2 * cash_kappa))
        cash_rate = cash_rate * w + cash_theta * (1 - w) + v * z2[:, yi]
        cash_rate = np.maximum(cash_rate, 0)

        # Equity GBM+MeanRev
        eq_trend *= (1 + equity_mean)
        gbm = eq_index * (1 + equity_mean + equity_vol * z1[:, yi])
        mr = equity_mean_rev * (eq_trend - eq_index)
        new_eq = np.maximum(gbm + mr, 0.01)
        raw_ret = new_eq / eq_index - 1
        eq_index = new_eq
        hedged_ret = np.clip(raw_ret, BUFFER_FLOOR - 1, BUFFER_CAP - 1)

        # Funder interest
        fund_cost = wholesale_margin + cash_rate
        avg_loan = (loan[t - 1] + loan[t]) / 2
        funder_int = -fund_cost * avg_loan
        funder_tot += funder_int

        # Holiday
        prev_flag = h_flag.copy()
        prev_count = h_count.copy()
        entering = (~prev_flag) & (investment < h_entry)
        exiting = prev_flag & (investment > h_exit)
        staying = prev_flag & (~exiting)
        h_flag = entering | staying
        h_count = np.where(h_flag, prev_count + 1, 0)
        yearly_holidays[:, yi] = h_flag.astype(float)

        rep_flag = prev_flag & (~h_flag)
        new_rep = np.where(rep_flag & (rep_step <= 0), prev_count, 0)
        rep_step = np.where(new_rep > 0, new_rep, np.maximum(rep_step - 1, 0))

        h_open = h_acct.copy()
        int_hol = np.where(h_flag, -funder_int, 0)
        rep_hol = np.where(rep_step > 0, -h_open / np.maximum(rep_step, 1), 0)
        h_acct = h_open + int_hol + rep_hol

        int_charged = funder_int + int_hol + rep_hol
        interest_tot += int_charged
        interest_deficit = funder_tot - interest_tot

        nim = -RETAIL_MARGIN * avg_loan
        fp_pay = -FP_MARGIN * investment
        hedge_pay = -HEDGING_FEE * investment
        tail_pay = -TAIL_RISK_ANNUAL * investment

        if t == TENURE:
            nim = -RETAIL_MARGIN * loan[t - 1] / 2
            int_charged = -fund_cost * loan[t - 1] / 2

        inv_ret = investment * hedged_ret
        pp = 0
        if t > ANNUITY_TERM:
            pp = -(loan[t - 1] - loan[t])

        investment = (investment + inv_ret + int_charged + nim + fp_pay + hedge_pay + tail_pay + pp)
        surplus = investment - loan[t] + interest_deficit

        if t < TENURE and t % PROFIT_SHARE_YRS == 0:
            ps = np.where(surplus > 0, surplus * PROFIT_SHARE_PCT, 0)
            investment -= ps
            cumul_ps += ps

        if t == TENURE:
            windup = np.maximum(surplus, 0)
            investment -= windup

        if t < TENURE:
            investment *= (1 - COLLAR_PRICE)

        yearly_surplus[:, t] = surplus

    final = yearly_surplus[:, -1]
    poc = np.mean(final < 0) * 100
    se = np.sqrt(poc / 100 * (1 - poc / 100) / n_paths) * 100

    # Insurance
    discount = np.exp(-cash_theta * TENURE)
    deficit_mask = final < 0
    n_def = np.sum(deficit_mask)
    if n_def > 0:
        def_vals = final[deficit_mask]
        tcl = np.percentile(def_vals, 20)
        lmi_mild = np.where(deficit_mask & (final >= tcl), -final, 0)
        lmi_severe = np.where(deficit_mask & (final < tcl), -tcl, 0)
        lmi_fair = discount * np.mean(lmi_mild + lmi_severe)
        tail_mask = deficit_mask & (final < tcl)
        tail_claims = np.where(tail_mask, -(final - tcl), 0)
        tail_fair = discount * np.mean(tail_claims)
        tail_poc = np.mean(tail_mask) * 100
        cond_def = np.mean(final[deficit_mask])
    else:
        lmi_fair = tail_fair = tail_poc = cond_def = tcl = 0

    mean_hol = np.mean(np.sum(yearly_holidays, axis=1))

    # Deficit by year
    dby = {}
    for yr in [1, 5, 10, 15, 20, 25, 30]:
        dby[str(yr)] = round(np.mean(yearly_surplus[:, yr] < 0) * 100, 2)

    return {
        'poc': round(poc, 2),
        'poc_se': round(se, 2),
        'mean_surplus': round(float(np.mean(final)), 0),
        'median_surplus': round(float(np.median(final)), 0),
        'p1': round(float(np.percentile(final, 1)), 0),
        'p5': round(float(np.percentile(final, 5)), 0),
        'p10': round(float(np.percentile(final, 10)), 0),
        'p25': round(float(np.percentile(final, 25)), 0),
        'p75': round(float(np.percentile(final, 75)), 0),
        'p90': round(float(np.percentile(final, 90)), 0),
        'p95': round(float(np.percentile(final, 95)), 0),
        'p99': round(float(np.percentile(final, 99)), 0),
        'cond_deficit': round(float(cond_def), 0),
        'lmi_fair': round(float(lmi_fair), 0),
        'tail_poc': round(float(tail_poc), 2),
        'mean_holidays': round(float(mean_hol), 1),
        'deficit_by_year': dby,
    }


def main():
    start = time.time()
    results = {'model_version': 'v14c-003', 'n_paths': N_PATHS}

    # Phase 1: Base case
    print("Phase 1: Base case...")
    base = run_single()
    results['base_case'] = base
    print(f"  PoC: {base['poc']}%, Mean surplus: ${base['mean_surplus']:,.0f}")

    # Phase 2: Sensitivity grid (equity return x vol)
    print("\nPhase 2: Sensitivity grid...")
    returns = [0.070, 0.075, 0.080, 0.085, 0.090, 0.092, 0.100, 0.110]
    vols = [0.120, 0.150, 0.166, 0.200, 0.250]
    results['sensitivity'] = {}
    for ret in returns:
        for vol in vols:
            key = f"ret_{ret:.3f}_vol_{vol:.3f}"
            r = run_single(equity_mean=ret, equity_vol=vol)
            results['sensitivity'][key] = {
                'equity_return': ret, 'equity_vol': vol,
                'poc': r['poc'], 'mean_surplus': r['mean_surplus'],
                'median_surplus': r['median_surplus'],
                'p1': r['p1'], 'p10': r['p10'],
                'cond_deficit': r['cond_deficit'],
                'lmi_fair': r['lmi_fair'], 'tail_poc': r['tail_poc'],
                'mean_holidays': r['mean_holidays'],
            }
            print(f"  ret={ret*100:.1f}%, vol={vol*100:.1f}%: PoC={r['poc']:.2f}%")

    # Phase 3: Correlation stress
    print("\nPhase 3: Correlation stress...")
    results['correlation_stress'] = {}
    for corr in [-0.3, -0.15, 0.0, 0.15, 0.30, 0.45, 0.60]:
        r = run_single(correlation=corr)
        results['correlation_stress'][str(corr)] = {
            'poc': r['poc'], 'mean_surplus': r['mean_surplus'],
            'median_surplus': r['median_surplus'],
            'p1': r['p1'], 'p10': r['p10'],
            'cond_deficit': r['cond_deficit'],
            'mean_holidays': r['mean_holidays'],
        }
        print(f"  corr={corr:.2f}: PoC={r['poc']:.2f}%")

    # Phase 4: Cash rate stress
    print("\nPhase 4: Cash rate stress...")
    results['rate_stress'] = {}
    rate_scenarios = [
        ("Low rates (theta=1.5%)", 0.015, 0.24),
        ("Base case (theta=2.13%)", 0.0213, 0.24),
        ("Medium rates (theta=3.5%)", 0.035, 0.24),
        ("High rates (theta=4.5%)", 0.045, 0.24),
        ("High + fast reversion", 0.045, 0.50),
        ("Low + slow reversion", 0.015, 0.10),
    ]
    for name, theta, kappa in rate_scenarios:
        r = run_single(cash_theta=theta, cash_kappa=kappa)
        results['rate_stress'][name] = {
            'theta': theta, 'kappa': kappa,
            'poc': r['poc'], 'mean_surplus': r['mean_surplus'],
            'median_surplus': r['median_surplus'], 'p1': r['p1'],
        }
        print(f"  {name}: PoC={r['poc']:.2f}%")

    # Phase 5: Combined stress scenarios
    print("\nPhase 5: Combined stress scenarios...")
    results['combined_stress'] = {}
    scenarios = [
        ("Base case", dict(equity_mean=0.092, equity_vol=0.166, correlation=0.30, cash_theta=0.0213)),
        ("Mild adverse: 8% return, 20% vol", dict(equity_mean=0.08, equity_vol=0.20, correlation=0.30, cash_theta=0.0213)),
        ("Moderate adverse: 7.5% ret, 20% vol, neg corr, 3.5% rates", dict(equity_mean=0.075, equity_vol=0.20, correlation=-0.15, cash_theta=0.035)),
        ("Severe: 7% ret, 25% vol, neg corr, high rates", dict(equity_mean=0.07, equity_vol=0.25, correlation=-0.30, cash_theta=0.045)),
        ("Japan scenario: 7% ret, 12% vol, low rates", dict(equity_mean=0.07, equity_vol=0.12, correlation=0.15, cash_theta=0.01)),
        ("GFC-like: 8% but 25% vol, neg corr", dict(equity_mean=0.08, equity_vol=0.25, correlation=-0.30, cash_theta=0.025)),
        ("Stagflation: low ret, high rates, high vol", dict(equity_mean=0.07, equity_vol=0.22, correlation=0.0, cash_theta=0.05)),
        ("Goldilocks: high ret, low vol, moderate rates", dict(equity_mean=0.11, equity_vol=0.12, correlation=0.15, cash_theta=0.03)),
    ]
    for name, params in scenarios:
        r = run_single(**params)
        results['combined_stress'][name] = {
            'params': params,
            'poc': r['poc'], 'mean_surplus': r['mean_surplus'],
            'median_surplus': r['median_surplus'],
            'p1': r['p1'], 'p5': r['p5'], 'p10': r['p10'],
            'cond_deficit': r['cond_deficit'],
            'lmi_fair': r['lmi_fair'], 'tail_poc': r['tail_poc'],
            'mean_holidays': r['mean_holidays'],
            'deficit_by_year': r['deficit_by_year'],
        }
        print(f"  {name}: PoC={r['poc']:.2f}%")

    elapsed = time.time() - start
    print(f"\nAll phases completed in {elapsed:.1f}s")

    with open('monte_carlo_v14c_003_comprehensive_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    print("Results saved to monte_carlo_v14c_003_comprehensive_results.json")


if __name__ == '__main__':
    main()
