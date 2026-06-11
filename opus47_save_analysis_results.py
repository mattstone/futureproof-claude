#!/usr/bin/env python3
"""
Opus 4.7 — run all parameter-risk analyses and persist results as JSON.
Consumed by generate_model_assumptions_pdf.py and by re-run generators
for the 7 existing v14c PDFs.
"""

import csv
import json
import numpy as np
from scipy.optimize import minimize
from scipy import stats
from scipy.stats import norm
from datetime import datetime

# Reuse the simulation engine
import opus47_critical_tests as sim


# ============================================================
# Data loading
# ============================================================
def load_sp500(path='data/sp500tr.csv'):
    rows = []
    with open(path, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        next(reader)
        for row in reader:
            d = datetime.strptime(row[0].strip('"'), '%b %d, %Y')
            close = float(row[4].replace(',', ''))
            rows.append((d, close))
    rows.sort(key=lambda x: x[0])
    return rows

def load_fedfunds(path='data/FEDFUNDS2.csv'):
    rows = []
    with open(path, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        next(reader)
        for row in reader:
            d = datetime.strptime(row[0], '%Y-%m-%d')
            rate = float(row[1]) / 100.0
            rows.append((d, rate))
    rows.sort(key=lambda x: x[0])
    return rows

sp500 = load_sp500()
fedfunds = load_fedfunds()

by_year_sp = {}
for d, c in sp500:
    by_year_sp[d.year] = c
sp_annual = np.array([by_year_sp[y] for y in sorted(by_year_sp)])
sp_years = np.array(sorted(by_year_sp))

by_year_ff = {}
for d, r in fedfunds:
    by_year_ff[d.year] = r
ff_annual = np.array([by_year_ff[y] for y in sorted(by_year_ff)])
ff_years = np.array(sorted(by_year_ff))


# ============================================================
# γ analysis (Shevchenko MLE on S&P 500 TR)
# ============================================================
def shevchenko_nll(params, S):
    mu_B, gamma_B, log_sigma = params
    sigma_B = np.exp(log_sigma)
    N = len(S) - 1
    M = S[0] * (1 + mu_B) ** np.arange(len(S))
    eps = (S[1:] - gamma_B * (M[:-1] - S[:-1])) / S[:-1] - 1 - mu_B
    return 0.5*N*np.log(2*np.pi) + N*np.log(sigma_B) + 0.5*np.sum(eps**2)/sigma_B**2

def fit_shev(S):
    rets = np.diff(S) / S[:-1]
    mu0 = float(np.mean(rets))
    sig0 = float(np.std(rets, ddof=1))
    x0 = np.array([mu0, 0.1, np.log(sig0)])
    res = minimize(shevchenko_nll, x0, args=(S,), method='L-BFGS-B',
                   bounds=[(-0.2, 0.5), (-0.5, 2.0), (np.log(0.001), np.log(2.0))])
    return {'mu_B': float(res.x[0]), 'gamma_B': float(res.x[1]),
            'sigma_B': float(np.exp(res.x[2])), 'nll': float(res.fun)}

def shevchenko_nll_gamma0(params, S):
    mu_B, log_sigma = params
    sigma_B = np.exp(log_sigma)
    N = len(S) - 1
    eps = (S[1:] / S[:-1]) - 1 - mu_B
    return 0.5*N*np.log(2*np.pi) + N*np.log(sigma_B) + 0.5*np.sum(eps**2)/sigma_B**2

def fit_gamma0(S):
    rets = np.diff(S) / S[:-1]
    mu0 = float(np.mean(rets))
    sig0 = float(np.std(rets, ddof=1))
    res = minimize(shevchenko_nll_gamma0, [mu0, np.log(sig0)], args=(S,),
                   method='L-BFGS-B',
                   bounds=[(-0.2, 0.5), (np.log(0.001), np.log(2.0))])
    return {'mu_B': float(res.x[0]), 'sigma_B': float(np.exp(res.x[1])),
            'nll': float(res.fun)}

print("Fitting γ…")
fit_sp = fit_shev(sp_annual)

rng = np.random.default_rng(42)
N_BOOT = 2000
boot_gammas = []
boot_mus = []
for _ in range(N_BOOT):
    idx = rng.integers(0, len(sp_annual)-1, size=len(sp_annual)-1)
    rets = (np.diff(sp_annual)/sp_annual[:-1])[idx]
    S_b = np.zeros(len(sp_annual))
    S_b[0] = sp_annual[0]
    for i in range(len(sp_annual)-1):
        S_b[i+1] = S_b[i]*(1+rets[i])
    try:
        f = fit_shev(S_b)
        boot_gammas.append(f['gamma_B'])
        boot_mus.append(f['mu_B'])
    except Exception:
        pass
boot_gammas = np.array(boot_gammas)
boot_mus = np.array(boot_mus)

# LRT
fit_null = fit_gamma0(sp_annual)
lrt_gamma_vs_zero = 2 * (fit_null['nll'] - fit_sp['nll'])
p_gamma_zero = float(1 - stats.chi2.cdf(lrt_gamma_vs_zero, df=1))

# Bias study — simulate with true γ=0.163, re-estimate
print("Running γ bias study…")
def sim_shev(N, mu_B, sigma_B, gamma_B, S0=100, seed=0):
    rng = np.random.default_rng(seed)
    S = np.zeros(N + 1)
    M = np.zeros(N + 1)
    S[0] = M[0] = S0
    eps = rng.standard_normal(N)
    for i in range(N):
        M[i+1] = M[i] * (1 + mu_B)
        S[i+1] = S[i] * (1 + mu_B + sigma_B*eps[i]) + gamma_B*(M[i] - S[i])
    return S

bias_estimates = []
for sd in range(1000):
    Sb = sim_shev(36, 0.092, 0.166, 0.163, seed=sd)
    try:
        f = fit_shev(Sb)
        bias_estimates.append(f['gamma_B'])
    except Exception:
        pass
bias_estimates = np.array(bias_estimates)

# Subperiod
print("γ subperiods…")
gamma_subperiods = []
win = 15
for s in range(0, len(sp_annual)-win):
    try:
        f = fit_shev(sp_annual[s:s+win+1])
        gamma_subperiods.append({
            'start': int(sp_years[s]),
            'end': int(sp_years[s+win]),
            'gamma': f['gamma_B'],
            'mu': f['mu_B'],
            'sigma': f['sigma_B'],
        })
    except Exception:
        pass

# PoD sensitivity — run actual simulator
print("Running γ → PoD simulations…")
sim.COLLAR_PRICE = 0.00046
gamma_pod_grid = []
for g in [0.0, 0.05, 0.10, 0.163, 0.25, 0.40]:
    r = sim.simulate(mean_rev=g, label=f"γ={g}")
    gamma_pod_grid.append({
        'gamma': g,
        'pod': r['pod'],
        'mean_surplus': r['mean_surplus'],
        'p1': r['p1'],
        'cond_deficit': r['cond_deficit'],
    })


# ============================================================
# θ analysis (OU MLE on Fed Funds)
# ============================================================
print("Fitting θ (cash rate)…")
def fit_ou(r):
    N = len(r) - 1
    r0 = r[:-1]; r1 = r[1:]
    sum_r0 = r0.sum(); sum_r1 = r1.sum()
    sum_r0r0 = (r0*r0).sum(); sum_r0r1 = (r0*r1).sum()
    d = sum_r0**2 - N*sum_r0r0
    w_hat = (sum_r1*sum_r0 - N*sum_r0r1) / d
    kappa_hat_closed = (sum_r0*sum_r0r1 - sum_r0r0*sum_r1) / d
    theta_hat = kappa_hat_closed / (1 - w_hat)
    residuals = r1 - w_hat*r0 - kappa_hat_closed
    v2 = (residuals**2).sum() / N
    kappa_speed = -np.log(w_hat) if w_hat > 0 else np.nan
    sigma2 = 2*kappa_speed*v2/(1 - w_hat**2) if (1 - w_hat**2) > 0 else np.nan
    return {
        'theta': float(theta_hat),
        'kappa': float(kappa_speed),
        'sigma': float(np.sqrt(sigma2)) if sigma2 > 0 else np.nan,
    }

fit_ff = fit_ou(ff_annual)

# θ subperiods
theta_subperiods = []
for s in range(0, len(ff_annual)-win):
    try:
        f = fit_ou(ff_annual[s:s+win+1])
        theta_subperiods.append({
            'start': int(ff_years[s]),
            'end': int(ff_years[s+win]),
            'theta': f['theta'],
            'kappa': f['kappa'],
        })
    except Exception:
        pass

# θ references
theta_refs = {
    'fed_funds_1988_2024_mean': float(np.mean(ff_annual)),
    'fed_funds_2010_2024_mean': float(np.mean(ff_annual[ff_years >= 2010])),
    'rba_1990_2024_approx': 0.047,
    'au_10yr_gov_current': 0.042,
    'fed_laubach_williams_plus_infl_low': 0.025,
    'fed_laubach_williams_plus_infl_high': 0.030,
}

# θ → PoD from review table
theta_pod_grid = [
    {'theta': 0.015, 'pod': 0.5},
    {'theta': 0.0213, 'pod': 1.2},
    {'theta': 0.035, 'pod': 6.4},
    {'theta': 0.045, 'pod': 15.8},
]


# ============================================================
# Collar analysis (Black-Scholes)
# ============================================================
print("Computing collar BS prices…")
def bs_call(S, K, r, q, sigma, T):
    d1 = (np.log(S/K) + (r - q + 0.5*sigma**2)*T) / (sigma*np.sqrt(T))
    d2 = d1 - sigma*np.sqrt(T)
    return S*np.exp(-q*T)*norm.cdf(d1) - K*np.exp(-r*T)*norm.cdf(d2)

def bs_put(S, K, r, q, sigma, T):
    d1 = (np.log(S/K) + (r - q + 0.5*sigma**2)*T) / (sigma*np.sqrt(T))
    d2 = d1 - sigma*np.sqrt(T)
    return K*np.exp(-r*T)*norm.cdf(-d2) - S*np.exp(-q*T)*norm.cdf(-d1)

collar_scenarios = []
for label, r_f, q in [
    ('Current AU cash 4.21%, div 2.0%', 0.0421, 0.02),
    ('Model long-run θ=2.13%, div 2.0%', 0.0213, 0.02),
    ('US 10yr 4.5%, div 1.5%', 0.045, 0.015),
    ('Zero carry', 0.04, 0.04),
]:
    p = bs_put(100, 80, r_f, q, 0.166, 1.0)
    c = bs_call(100, 140, r_f, q, 0.166, 1.0)
    collar_scenarios.append({
        'label': label,
        'put': float(p),
        'call': float(c),
        'net_cost_pct': float((p - c) / 100),
    })

# Collar → PoD
print("Running collar → PoD simulations…")
collar_pod_grid = []
for cc in [0.00046, 0.0025, 0.005, 0.010, 0.015, 0.020]:
    sim.COLLAR_PRICE = cc
    r = sim.simulate(label=f"collar={cc}")
    collar_pod_grid.append({
        'collar_pct': cc,
        'pod': r['pod'],
        'mean_surplus': r['mean_surplus'],
    })
sim.COLLAR_PRICE = 0.00046  # reset


# ============================================================
# μ analysis
# ============================================================
print("μ bootstrap + PoD simulations…")
# already have fit_sp and boot_mus
mu_refs = {
    'sp500_1988_2024_arithmetic': float(np.mean(np.diff(sp_annual)/sp_annual[:-1])),
    'sp500_1988_2024_geometric': float((sp_annual[-1]/sp_annual[0])**(1/(len(sp_annual)-1)) - 1),
    'dms_global_nominal_approx': 0.075,
    'cape_implied_forward_nominal_low': 0.05,
    'cape_implied_forward_nominal_high': 0.06,
    'au_super_actuarial_low': 0.07,
    'au_super_actuarial_high': 0.08,
}

mu_pod_grid = []
for m in [0.060, 0.070, 0.080, 0.092, 0.100]:
    r = sim.simulate(eq_mean=m, label=f"μ={m}")
    mu_pod_grid.append({
        'mu': m,
        'pod': r['pod'],
        'mean_surplus': r['mean_surplus'],
    })


# ============================================================
# Wholesale margin
# ============================================================
print("Wholesale margin sweep…")
import importlib
importlib.reload(sim)
sim.COLLAR_PRICE = 0.00046

margin_pod_grid = []
for m in [0.015, 0.020, 0.025, 0.030, 0.035]:
    sim.WHOLESALE_MARGIN = m
    r = sim.simulate(label=f"margin={m}")
    margin_pod_grid.append({
        'margin': m,
        'pod': r['pod'],
        'mean_surplus': r['mean_surplus'],
    })
sim.WHOLESALE_MARGIN = 0.02


# ============================================================
# κ, ρ, σ sanity
# ============================================================
# κ already in fit_ff
# σ already in fit_sp
# ρ: residual correlation
print("κ, ρ, σ sanity…")
mu_B = fit_sp['mu_B']; gamma_B = fit_sp['gamma_B']; sig_B = fit_sp['sigma_B']
M = sp_annual[0]*(1+mu_B)**np.arange(len(sp_annual))
eps_sp = (sp_annual[1:] - gamma_B*(M[:-1] - sp_annual[:-1]))/sp_annual[:-1] - 1 - mu_B
eps_sp_std = eps_sp / sig_B
w_ff = np.exp(-fit_ff['kappa'])
v_ff = fit_ff['sigma']*np.sqrt((1 - w_ff**2)/(2*fit_ff['kappa']))
eps_ff = (ff_annual[1:] - w_ff*ff_annual[:-1] - fit_ff['kappa']*fit_ff['theta']) / v_ff
n_min = min(len(eps_sp_std), len(eps_ff))
rho_empirical = float(np.corrcoef(eps_sp_std[:n_min], eps_ff[:n_min])[0,1])


# ============================================================
# Combined adverse scenario
# ============================================================
print("Combined adverse parameter scenario…")
importlib.reload(sim)
sim.COLLAR_PRICE = 0.004     # BS-realistic
sim.WHOLESALE_MARGIN = 0.025  # modest stress
r_adverse = sim.simulate(
    mean_rev=0.10,   # weaker mean reversion
    eq_mean=0.080,   # forward-looking μ
    cr_theta=0.030,  # realistic θ
    label='combined-adverse',
)
# Also realistic-central
importlib.reload(sim)
sim.COLLAR_PRICE = 0.003
sim.WHOLESALE_MARGIN = 0.022
r_central = sim.simulate(
    mean_rev=0.13,
    eq_mean=0.085,
    cr_theta=0.027,
    label='realistic-central',
)
# Reset
importlib.reload(sim)


# ============================================================
# Assemble JSON
# ============================================================
out = {
    'metadata': {
        'analysis': 'Opus 4.7 parameter risk review of v14c-003',
        'date': '2026-04-19',
        'simulation_paths': 50000,
    },
    'gamma': {
        'model_value': 0.163,
        'mle_point_estimate': fit_sp['gamma_B'],
        'bootstrap_n': len(boot_gammas),
        'bootstrap_mean': float(np.mean(boot_gammas)),
        'bootstrap_median': float(np.median(boot_gammas)),
        'bootstrap_sd': float(np.std(boot_gammas)),
        'bootstrap_ci_95_low': float(np.percentile(boot_gammas, 2.5)),
        'bootstrap_ci_95_high': float(np.percentile(boot_gammas, 97.5)),
        'p_gamma_gt_zero': float(np.mean(boot_gammas > 0)),
        'p_gamma_gt_010': float(np.mean(boot_gammas > 0.10)),
        'p_gamma_gt_0163': float(np.mean(boot_gammas > 0.163)),
        'lrt_vs_zero_stat': float(lrt_gamma_vs_zero),
        'lrt_vs_zero_pvalue': p_gamma_zero,
        'mle_bias_simulation': {
            'n_sims': len(bias_estimates),
            'true_gamma': 0.163,
            'mean_estimate': float(np.mean(bias_estimates)),
            'bias': float(np.mean(bias_estimates) - 0.163),
            'sd': float(np.std(bias_estimates)),
            'ci_95_low': float(np.percentile(bias_estimates, 2.5)),
            'ci_95_high': float(np.percentile(bias_estimates, 97.5)),
        },
        'subperiods': gamma_subperiods,
        'pod_grid': gamma_pod_grid,
        'bootstrap_samples': boot_gammas.tolist(),
    },
    'theta': {
        'model_value': 0.0213,
        'mle_point_estimate': fit_ff['theta'],
        'mle_kappa': fit_ff['kappa'],
        'mle_sigma': fit_ff['sigma'],
        'subperiods': theta_subperiods,
        'references': theta_refs,
        'pod_grid': theta_pod_grid,
    },
    'collar': {
        'model_value': 0.00046,
        'bs_scenarios': collar_scenarios,
        'bs_central_estimate': float(np.median([s['net_cost_pct'] for s in collar_scenarios])),
        'pod_grid': collar_pod_grid,
    },
    'mu': {
        'model_value': 0.092,
        'mle_point_estimate': fit_sp['mu_B'],
        'bootstrap_mean': float(np.mean(boot_mus)),
        'bootstrap_ci_95_low': float(np.percentile(boot_mus, 2.5)),
        'bootstrap_ci_95_high': float(np.percentile(boot_mus, 97.5)),
        'p_mu_lt_092': float(np.mean(boot_mus < 0.092)),
        'p_mu_lt_070': float(np.mean(boot_mus < 0.070)),
        'references': mu_refs,
        'pod_grid': mu_pod_grid,
        'bootstrap_samples': boot_mus.tolist(),
    },
    'margin': {
        'model_value': 0.020,
        'pod_grid': margin_pod_grid,
    },
    'low_leverage': {
        'kappa': {'model': 0.24, 'empirical': fit_ff['kappa']},
        'sigma': {'model': 0.166, 'empirical': fit_sp['sigma_B']},
        'rho': {'model': 0.30, 'empirical': rho_empirical},
    },
    'combined_scenarios': {
        'base_case': {
            'gamma': 0.163, 'mu': 0.092, 'theta': 0.0213,
            'collar': 0.00046, 'margin': 0.02,
            'pod': 1.20,
            'description': 'Model as written',
        },
        'realistic_central': {
            'gamma': 0.13, 'mu': 0.085, 'theta': 0.027,
            'collar': 0.003, 'margin': 0.022,
            'pod': r_central['pod'],
            'mean_surplus': r_central['mean_surplus'],
            'description': 'Empirically-calibrated central parameters',
        },
        'adverse_plausible': {
            'gamma': 0.10, 'mu': 0.080, 'theta': 0.030,
            'collar': 0.004, 'margin': 0.025,
            'pod': r_adverse['pod'],
            'mean_surplus': r_adverse['mean_surplus'],
            'description': 'Plausible adverse but not worst-case',
        },
    },
    'wholesale_comparison': {
        'universe': [
            {'asset': 'AU Commonwealth bond', 'el_30yr_pct': 0.0,
             'spread_bps': 0, 'rating': 'AAA'},
            {'asset': 'AAA senior RMBS', 'el_30yr_pct': 0.03,
             'spread_bps': 100, 'rating': 'AAA'},
            {'asset': 'AA mezzanine RMBS', 'el_30yr_pct': 0.20,
             'spread_bps': 200, 'rating': 'AA'},
            {'asset': 'Prime direct mortgage', 'el_30yr_pct': 0.75,
             'spread_bps': 200, 'rating': 'A-equiv'},
            {'asset': 'A-rated corporate bond', 'el_30yr_pct': 1.0,
             'spread_bps': 150, 'rating': 'A'},
            {'asset': 'BBB corporate bond', 'el_30yr_pct': 3.0,
             'spread_bps': 240, 'rating': 'BBB'},
            {'asset': 'Senior CRE loan', 'el_30yr_pct': 2.25,
             'spread_bps': 300, 'rating': 'unrated'},
            {'asset': 'Infrastructure debt IG', 'el_30yr_pct': 0.75,
             'spread_bps': 200, 'rating': 'A/BBB'},
        ],
        'epm_scenarios': [
            {'scenario': 'Base (model)', 'el_30yr_pct': 0.132,
             'spread_bps': 200, 'comment': 'Premium vs AA RMBS'},
            {'scenario': 'Realistic central', 'el_30yr_pct': 0.50,
             'spread_bps': 200, 'comment': 'Prime mortgage equivalent'},
            {'scenario': 'Adverse plausible', 'el_30yr_pct': 2.0,
             'spread_bps': 200, 'comment': 'BBB/CRE-like; spread too thin'},
        ],
    },
}

outfile = 'opus47_assumption_analysis_results.json'
with open(outfile, 'w') as f:
    json.dump(out, f, indent=2)

print(f"\nSaved to {outfile}")
print(f"File size: {len(json.dumps(out))/1024:.1f} KB")
