#!/usr/bin/env python3
"""
Empirical assessment of Shevchenko's γ=0.163 mean-reversion assumption.

Tests:
  A. Estimate γ_B via MLE on actual S&P 500 total return data
  B. Compute confidence interval (Fisher information + bootstrap)
  C. Test statistical significance: is γ distinguishable from 0? from 0.163?
  D. Subperiod stability (rolling 15yr windows)
  E. Literature triangulation
  F. Translate CI into PoD range for the EPM model
"""

import csv
import numpy as np
from scipy.optimize import minimize
from scipy import stats
from datetime import datetime

# ============================================================
# A. Load S&P 500 total return data
# ============================================================
def load_sp500(path='data/sp500tr.csv'):
    rows = []
    with open(path, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        header = next(reader)
        for row in reader:
            date_str = row[0].strip('"')
            close = float(row[4].replace(',', ''))
            d = datetime.strptime(date_str, '%b %d, %Y')
            rows.append((d, close))
    rows.sort(key=lambda x: x[0])
    return rows

monthly = load_sp500()
print(f"Monthly observations: {len(monthly)}")
print(f"Date range: {monthly[0][0].date()} to {monthly[-1][0].date()}")

# Aggregate to annual (year-end observations)
by_year = {}
for d, c in monthly:
    by_year[d.year] = (d, c)  # overwrites, last entry of year wins
annual_sorted = sorted(by_year.items())
annual_prices = np.array([c for _, (d, c) in annual_sorted])
annual_years = np.array([y for y, _ in annual_sorted])
print(f"Annual observations: {len(annual_prices)} ({annual_years[0]}-{annual_years[-1]})")
print(f"Start: {annual_prices[0]:.2f}, End: {annual_prices[-1]:.2f}")

annual_returns = np.diff(annual_prices) / annual_prices[:-1]
print(f"Mean annual return: {np.mean(annual_returns)*100:.2f}%, "
      f"vol: {np.std(annual_returns, ddof=1)*100:.2f}%")

# ============================================================
# B. MLE for Shevchenko's GBM+MeanRev model
# ============================================================
# Model:
#   M(t+1) = M(t)(1 + μ_B)                 (deterministic trend)
#   S(t+1) = S(t)(1 + μ_B + σ_B ε) + γ_B (M(t) - S(t))
# M(t0) = S(t0)
#
# Residual:  ε~_{i+1} = [S(t+1) - γ_B(M(t) - S(t))] / S(t) - 1 - μ_B
# ε~ ~ N(0, σ_B^2)

def shevchenko_nll(params, S):
    mu_B, gamma_B, log_sigma = params
    sigma_B = np.exp(log_sigma)
    N = len(S) - 1
    # Build trend M(t)
    M = S[0] * (1 + mu_B) ** np.arange(len(S))
    # Residuals
    numer = S[1:] - gamma_B * (M[:-1] - S[:-1])
    eps = numer / S[:-1] - 1 - mu_B
    # Negative log-likelihood under N(0, sigma_B^2)
    nll = 0.5 * N * np.log(2 * np.pi) + N * np.log(sigma_B) + 0.5 * np.sum(eps**2) / sigma_B**2
    return nll

def fit_shevchenko(S, bounds=None):
    # Initial guesses from sample moments
    rets = np.diff(S) / S[:-1]
    mu0 = float(np.mean(rets))
    sig0 = float(np.std(rets, ddof=1))
    x0 = np.array([mu0, 0.1, np.log(sig0)])
    bounds = bounds or [(-0.2, 0.5), (-0.5, 2.0), (np.log(0.001), np.log(2.0))]
    res = minimize(shevchenko_nll, x0, args=(S,), method='L-BFGS-B', bounds=bounds)
    mu_hat, gamma_hat, log_sigma_hat = res.x
    return {
        'mu_B': float(mu_hat),
        'gamma_B': float(gamma_hat),
        'sigma_B': float(np.exp(log_sigma_hat)),
        'nll': float(res.fun),
        'converged': res.success,
        'n_obs': len(S) - 1,
    }

print("\n" + "="*70)
print("A. MLE ESTIMATION OF γ_B ON S&P 500 TOTAL RETURN, FULL SAMPLE")
print("="*70)

fit = fit_shevchenko(annual_prices)
print(f"  μ_B   = {fit['mu_B']*100:.2f}%   (drift)")
print(f"  γ_B   = {fit['gamma_B']:.4f}    (mean reversion speed)")
print(f"  σ_B   = {fit['sigma_B']*100:.2f}%  (volatility)")
print(f"  N     = {fit['n_obs']} annual observations")
print(f"  converged: {fit['converged']}")
print(f"  Shevchenko report value: γ=0.163")
print(f"  Our MLE estimate:        γ={fit['gamma_B']:.3f}")

# ============================================================
# C. Confidence interval via bootstrap
# ============================================================
print("\n" + "="*70)
print("B. BOOTSTRAP 95% CI FOR γ_B")
print("="*70)

rng = np.random.default_rng(42)
N_BOOT = 2000
boot_gammas = []
boot_mus = []

N = len(annual_prices) - 1
log_rets = np.diff(np.log(annual_prices))

for _ in range(N_BOOT):
    idx = rng.integers(0, N, size=N)
    boot_returns = (annual_prices[1:] / annual_prices[:-1] - 1)[idx]
    S_boot = np.zeros(N + 1)
    S_boot[0] = annual_prices[0]
    for i in range(N):
        S_boot[i+1] = S_boot[i] * (1 + boot_returns[i])
    try:
        f = fit_shevchenko(S_boot)
        if f['converged']:
            boot_gammas.append(f['gamma_B'])
            boot_mus.append(f['mu_B'])
    except Exception:
        pass

boot_gammas = np.array(boot_gammas)
boot_mus = np.array(boot_mus)
ci_low = np.percentile(boot_gammas, 2.5)
ci_high = np.percentile(boot_gammas, 97.5)
ci50_low = np.percentile(boot_gammas, 25)
ci50_high = np.percentile(boot_gammas, 75)

print(f"  Bootstrap samples: {len(boot_gammas)}")
print(f"  Mean γ_B:          {np.mean(boot_gammas):.3f}")
print(f"  Median γ_B:        {np.median(boot_gammas):.3f}")
print(f"  SD γ_B:            {np.std(boot_gammas):.3f}")
print(f"  95% CI: [{ci_low:.3f}, {ci_high:.3f}]")
print(f"  50% CI: [{ci50_low:.3f}, {ci50_high:.3f}]")

# Probability that γ > 0
p_gt_zero = np.mean(boot_gammas > 0)
p_gt_016 = np.mean(boot_gammas > 0.163)
p_gt_010 = np.mean(boot_gammas > 0.10)
print(f"\n  P(γ > 0):    {p_gt_zero*100:.1f}%")
print(f"  P(γ > 0.10): {p_gt_010*100:.1f}%")
print(f"  P(γ > 0.163): {p_gt_016*100:.1f}%")

# Likelihood ratio test: is γ > 0 statistically significant?
# Fit restricted model (γ = 0)
def shevchenko_nll_gamma0(params, S):
    mu_B, log_sigma = params
    sigma_B = np.exp(log_sigma)
    N = len(S) - 1
    eps = (S[1:] / S[:-1]) - 1 - mu_B
    return 0.5 * N * np.log(2 * np.pi) + N * np.log(sigma_B) + 0.5 * np.sum(eps**2) / sigma_B**2

def fit_gamma0(S):
    rets = np.diff(S) / S[:-1]
    mu0 = float(np.mean(rets))
    sig0 = float(np.std(rets, ddof=1))
    x0 = np.array([mu0, np.log(sig0)])
    res = minimize(shevchenko_nll_gamma0, x0, args=(S,), method='L-BFGS-B',
                   bounds=[(-0.2, 0.5), (np.log(0.001), np.log(2.0))])
    return {'mu_B': float(res.x[0]), 'sigma_B': float(np.exp(res.x[1])), 'nll': float(res.fun)}

fit_null = fit_gamma0(annual_prices)
lrt_stat = 2 * (fit_null['nll'] - fit['nll'])
p_lrt = 1 - stats.chi2.cdf(lrt_stat, df=1)
print(f"\n  LRT (H0: γ=0 vs H1: γ free):")
print(f"    NLL null:         {fit_null['nll']:.3f}")
print(f"    NLL alt:          {fit['nll']:.3f}")
print(f"    LRT statistic:    {lrt_stat:.3f}")
print(f"    p-value (χ²_1):   {p_lrt:.4f}")
print(f"    → mean reversion {'IS' if p_lrt < 0.05 else 'NOT'} statistically significant at 5%")

# LRT: γ = 0.163 specifically
def shevchenko_nll_fixed_gamma(params, S, gamma_fixed):
    mu_B, log_sigma = params
    sigma_B = np.exp(log_sigma)
    N = len(S) - 1
    M = S[0] * (1 + mu_B) ** np.arange(len(S))
    eps = (S[1:] - gamma_fixed * (M[:-1] - S[:-1])) / S[:-1] - 1 - mu_B
    return 0.5 * N * np.log(2 * np.pi) + N * np.log(sigma_B) + 0.5 * np.sum(eps**2) / sigma_B**2

def fit_fixed(S, gamma_fixed):
    rets = np.diff(S) / S[:-1]
    mu0 = float(np.mean(rets))
    sig0 = float(np.std(rets, ddof=1))
    res = minimize(shevchenko_nll_fixed_gamma, [mu0, np.log(sig0)], args=(S, gamma_fixed),
                   method='L-BFGS-B',
                   bounds=[(-0.2, 0.5), (np.log(0.001), np.log(2.0))])
    return res.fun

nll_016 = fit_fixed(annual_prices, 0.163)
lrt016 = 2 * (nll_016 - fit['nll'])
p_016 = 1 - stats.chi2.cdf(lrt016, df=1)
print(f"\n  LRT (H0: γ=0.163 vs H1: γ free):")
print(f"    NLL at γ=0.163:   {nll_016:.3f}")
print(f"    LRT statistic:    {lrt016:.3f}")
print(f"    p-value:          {p_016:.4f}")
print(f"    → γ=0.163 {'IS' if p_016 < 0.05 else 'NOT'} rejected at 5% (i.e. data {'is' if p_016 < 0.05 else 'is NOT'} inconsistent with γ=0.163)")

# ============================================================
# D. Subperiod stability
# ============================================================
print("\n" + "="*70)
print("C. SUBPERIOD STABILITY (rolling 15yr windows)")
print("="*70)

window = 15
subperiods = []
for start_idx in range(0, len(annual_prices) - window):
    end_idx = start_idx + window + 1
    S_win = annual_prices[start_idx:end_idx]
    try:
        f = fit_shevchenko(S_win)
        subperiods.append({
            'start_year': int(annual_years[start_idx]),
            'end_year': int(annual_years[end_idx-1]),
            'gamma': f['gamma_B'],
            'mu': f['mu_B'],
            'sigma': f['sigma_B'],
        })
    except Exception:
        pass

print(f"  {'Window':<15} {'γ':>8} {'μ':>8} {'σ':>8}")
for s in subperiods:
    win = f"{s['start_year']}-{s['end_year']}"
    print(f"  {win:<15} {s['gamma']:>8.3f} {s['mu']*100:>7.2f}% {s['sigma']*100:>7.2f}%")

gammas_subp = np.array([s['gamma'] for s in subperiods])
print(f"\n  Subperiod γ: min={np.min(gammas_subp):.3f}, max={np.max(gammas_subp):.3f}, "
      f"median={np.median(gammas_subp):.3f}")
print(f"  Fraction of windows with γ > 0.10: {np.mean(gammas_subp > 0.10)*100:.0f}%")
print(f"  Fraction of windows with γ > 0.163: {np.mean(gammas_subp > 0.163)*100:.0f}%")

# ============================================================
# E. Is MLE biased? Short-sample simulation study
# ============================================================
print("\n" + "="*70)
print("D. MLE PROPERTIES: SIMULATION STUDY")
print("="*70)
print("Simulate Shevchenko paths with known γ=0.163, re-estimate, check bias.\n")

def simulate_shevchenko(N, mu_B, sigma_B, gamma_B, S0=100, seed=0):
    rng = np.random.default_rng(seed)
    S = np.zeros(N + 1)
    M = np.zeros(N + 1)
    S[0] = M[0] = S0
    eps = rng.standard_normal(N)
    for i in range(N):
        M[i+1] = M[i] * (1 + mu_B)
        S[i+1] = S[i] * (1 + mu_B + sigma_B * eps[i]) + gamma_B * (M[i] - S[i])
    return S

N_SIM = 1000
estimates = []
for sd in range(N_SIM):
    S_sim = simulate_shevchenko(N=36, mu_B=0.092, sigma_B=0.166, gamma_B=0.163, seed=sd)
    try:
        f = fit_shevchenko(S_sim)
        if f['converged']:
            estimates.append(f['gamma_B'])
    except Exception:
        pass

estimates = np.array(estimates)
print(f"  True γ = 0.163, N=36 years (matches our S&P sample size)")
print(f"  Simulated MLE estimates over {len(estimates)} runs:")
print(f"    Mean:     {np.mean(estimates):.3f}  (bias: {np.mean(estimates) - 0.163:+.3f})")
print(f"    Median:   {np.median(estimates):.3f}")
print(f"    SD:       {np.std(estimates):.3f}")
print(f"    95% range: [{np.percentile(estimates, 2.5):.3f}, {np.percentile(estimates, 97.5):.3f}]")
print(f"    P(γ̂ > 0.30): {np.mean(estimates > 0.30)*100:.1f}%")

# ============================================================
# F. Translate γ-uncertainty into PoD range
# ============================================================
print("\n" + "="*70)
print("E. γ-UNCERTAINTY → PoD RANGE (from earlier test T1)")
print("="*70)
print("""  γ      PoD    (from opus47_critical_tests T1)
  0.00   31.48%
  0.05    8.87%
  0.10    3.05%
  0.163   1.20%  ← model assumption
  0.25    0.60%
  0.40    0.43%""")

# Linear interpolation of PoD vs gamma (rough, but instructive)
gamma_grid = np.array([0.00, 0.05, 0.10, 0.163, 0.25, 0.40])
pod_grid = np.array([31.48, 8.87, 3.05, 1.20, 0.60, 0.43])
def interp_pod(g):
    return float(np.interp(g, gamma_grid, pod_grid))

print(f"\n  Empirical MLE γ = {fit['gamma_B']:.3f}")
print(f"  Bootstrap 95% CI γ = [{ci_low:.3f}, {ci_high:.3f}]")
print(f"\n  Implied PoD at empirical MLE γ:       ~{interp_pod(fit['gamma_B']):.2f}%")
print(f"  Implied PoD at 95% CI low  (γ={ci_low:.3f}): ~{interp_pod(ci_low):.2f}%")
print(f"  Implied PoD at 95% CI high (γ={ci_high:.3f}): ~{interp_pod(ci_high):.2f}%")
print(f"\n  The EPM headline PoD of 1.20% is predicated on γ=0.163.")
print(f"  At the empirical point estimate γ={fit['gamma_B']:.2f}, PoD ~{interp_pod(fit['gamma_B']):.1f}%.")
print(f"  Within parameter uncertainty, PoD could plausibly be {interp_pod(ci_low):.1f}%–{interp_pod(ci_high):.1f}%.")

print("\n" + "="*70)
print("DONE")
print("="*70)
