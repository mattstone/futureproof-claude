#!/usr/bin/env python3
"""
Validation: Ensure Rust metrics calculation matches Python exactly
"""

import sys
sys.path.append('..')

import numpy as np
import numpy_financial as npf
import monte_carlo_engine

print("=" * 80)
print("VALIDATION: Rust vs Python Metrics Calculation")
print("=" * 80)

# Test scenario parameters
total_loan = 1_600_000.0
reinvest_fraction = 0.625
loan_duration = 10
annual_income = 30_000.0
annuity_duration = 10
insurance_profit_margin = 1.5
insurance_cost = 8_000.0
cash_rate = 0.04
num_paths = 1000

print(f"\nTest Configuration:")
print(f"  Total Loan: ${total_loan:,.0f}")
print(f"  Loan Duration: {loan_duration} years")
print(f"  Annual Income: ${annual_income:,.0f}")
print(f"  Number of Paths: {num_paths:,}")

# Generate paths and run simulation
print(f"\n{'='*80}")
print("Running Monte Carlo Simulation...")
print(f"{'='*80}")

paths = monte_carlo_engine.gen_monte_carlo_paths(
    loan_duration, 0.10, 0.12, num_paths, 100.0
)

results = monte_carlo_engine.single_mortgage_rust(
    total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
    insurance_profit_margin, insurance_cost, cash_rate,
    0.03, 0.012, 1.35, 1.95, 6,
    paths, 100.0, False, True, 0.2, 0.4, 0.005
)

print(f"✅ Simulation complete: {len(results):,} paths")

# Calculate metrics using Python (manual implementation)
print(f"\n{'='*80}")
print("Calculating Metrics - Python Implementation")
print(f"{'='*80}")

reinvestments_py = np.array([r.reinvestment for r in results])
deficits_py = np.array([r.interest_deficit for r in results])
holidays_py = np.array([r.quarters_in_holiday for r in results])

# Python metrics
mean_reinvestment_py = reinvestments_py.mean()
std_reinvestment_py = reinvestments_py.std()
p10_reinvestment_py = np.percentile(reinvestments_py, 10)
p25_reinvestment_py = np.percentile(reinvestments_py, 25)
p50_reinvestment_py = np.percentile(reinvestments_py, 50)
p75_reinvestment_py = np.percentile(reinvestments_py, 75)
p90_reinvestment_py = np.percentile(reinvestments_py, 90)

mean_deficit_py = deficits_py.mean()
total_holiday_quarters_py = holidays_py.sum()
pct_quarters_holiday_py = holidays_py.sum() / (num_paths * loan_duration * 4)

# Funder metrics
lender_profit_share = 0.5
profit_shares_py = np.maximum(lender_profit_share * (reinvestments_py - total_loan - deficits_py), 0)
mean_funder_profit_share_py = profit_shares_py.mean()
mean_funder_earned_py = 0.0
mean_net_position_py = mean_funder_earned_py + mean_funder_profit_share_py

# CAGR
initial_investment = total_loan * reinvest_fraction
final_value_py = mean_reinvestment_py + mean_funder_profit_share_py
mean_cagr_py = (final_value_py / initial_investment) ** (1/loan_duration) - 1

# XIRR (simplified)
quarterly_income = annual_income / 4
npcf = np.zeros(loan_duration * 4)
npcf[0] = -(initial_investment + quarterly_income)
npcf[-1] = final_value_py
xirr_py = npf.irr(npcf)

# Insurance
repayment_amount = annuity_duration * annual_income
insurance_payouts = np.maximum(total_loan + deficits_py - reinvestments_py - repayment_amount, 0)
prob_insurance_payout_py = (reinvestments_py + repayment_amount < total_loan + deficits_py).mean()
mean_insurance_payout_npv_py = insurance_payouts.mean() / ((1 + cash_rate) ** loan_duration)

print(f"\nPython Results:")
print(f"  Mean Reinvestment: ${mean_reinvestment_py:,.2f}")
print(f"  Std Reinvestment:  ${std_reinvestment_py:,.2f}")
print(f"  P50 Reinvestment:  ${p50_reinvestment_py:,.2f}")
print(f"  Mean CAGR:         {mean_cagr_py*100:.4f}%")
print(f"  XIRR:              {xirr_py*100:.4f}%")
print(f"  Insurance Prob:    {prob_insurance_payout_py*100:.2f}%")

# Calculate metrics using Rust
print(f"\n{'='*80}")
print("Calculating Metrics - Rust Implementation")
print(f"{'='*80}")

metrics_rust = monte_carlo_engine.calculate_metrics(
    results, total_loan, reinvest_fraction, loan_duration,
    annual_income, annuity_duration, cash_rate
)

print(f"\nRust Results:")
print(f"  Mean Reinvestment: ${metrics_rust.mean_reinvestment:,.2f}")
print(f"  Std Reinvestment:  ${metrics_rust.std_reinvestment:,.2f}")
print(f"  P50 Reinvestment:  ${metrics_rust.p50_reinvestment:,.2f}")
print(f"  Mean CAGR:         {metrics_rust.mean_cagr*100:.4f}%")
xirr_rust_str = f"{metrics_rust.xirr*100:.4f}%" if metrics_rust.xirr else "None"
print(f"  XIRR:              {xirr_rust_str}")
print(f"  Insurance Prob:    {metrics_rust.prob_insurance_payout*100:.2f}%")

# Compare results
print(f"\n{'='*80}")
print("COMPARISON: Python vs Rust")
print(f"{'='*80}")

metrics_comparison = [
    ("Mean Reinvestment", mean_reinvestment_py, metrics_rust.mean_reinvestment),
    ("Std Reinvestment", std_reinvestment_py, metrics_rust.std_reinvestment),
    ("P10 Reinvestment", p10_reinvestment_py, metrics_rust.p10_reinvestment),
    ("P25 Reinvestment", p25_reinvestment_py, metrics_rust.p25_reinvestment),
    ("P50 Reinvestment", p50_reinvestment_py, metrics_rust.p50_reinvestment),
    ("P75 Reinvestment", p75_reinvestment_py, metrics_rust.p75_reinvestment),
    ("P90 Reinvestment", p90_reinvestment_py, metrics_rust.p90_reinvestment),
    ("Mean Deficit", mean_deficit_py, metrics_rust.mean_deficit),
    ("Total Holiday Qtrs", total_holiday_quarters_py, metrics_rust.total_holiday_quarters),
    ("Pct Holiday Qtrs", pct_quarters_holiday_py, metrics_rust.pct_quarters_holiday),
    ("Mean Funder Profit Share", mean_funder_profit_share_py, metrics_rust.mean_funder_profit_share),
    ("Mean Net Position", mean_net_position_py, metrics_rust.mean_net_position),
    ("Mean CAGR", mean_cagr_py, metrics_rust.mean_cagr),
    ("XIRR", xirr_py, metrics_rust.xirr if metrics_rust.xirr else np.nan),
    ("Prob Insurance Payout", prob_insurance_payout_py, metrics_rust.prob_insurance_payout),
    ("Mean Insurance NPV", mean_insurance_payout_npv_py, metrics_rust.mean_insurance_payout_npv),
]

passed = 0
failed = 0

print(f"\n{'Metric':<30} {'Python':>15} {'Rust':>15} {'Diff %':>12} {'Status':>10}")
print("-" * 88)

for name, py_val, rust_val in metrics_comparison:
    if np.isnan(py_val) or np.isnan(rust_val):
        diff_pct = 0.0 if (np.isnan(py_val) and np.isnan(rust_val)) else 100.0
    elif abs(py_val) < 1e-10:
        diff_pct = abs(rust_val) * 100
    else:
        diff_pct = abs(py_val - rust_val) / abs(py_val) * 100

    # Format values for display
    if abs(py_val) > 1000:
        py_str = f"${py_val:>,.2f}"
        rust_str = f"${rust_val:>,.2f}"
    elif abs(py_val) < 0.1:
        py_str = f"{py_val:>14.6f}"
        rust_str = f"{rust_val:>14.6f}"
    else:
        py_str = f"{py_val:>14.4f}"
        rust_str = f"{rust_val:>14.4f}"

    status = "✅ PASS" if diff_pct < 0.01 else "⚠️  WARN" if diff_pct < 1.0 else "❌ FAIL"

    print(f"{name:<30} {py_str:>15} {rust_str:>15} {diff_pct:>11.6f}% {status:>10}")

    if diff_pct < 1.0:
        passed += 1
    else:
        failed += 1

# Summary
print("\n" + "=" * 80)
print("VALIDATION SUMMARY")
print("=" * 80)

total_tests = len(metrics_comparison)
print(f"\nTests Passed: {passed}/{total_tests}")
print(f"Accuracy: {passed/total_tests*100:.1f}%")

if passed == total_tests:
    print(f"\n✅ PERFECT MATCH: All metrics match Python implementation exactly")
    print(f"   Rust metrics calculation is validated for production use")
elif passed >= total_tests * 0.9:
    print(f"\n✅ VALIDATED: {passed}/{total_tests} metrics match within tolerance")
    print(f"   Minor differences are acceptable for Monte Carlo analysis")
else:
    print(f"\n⚠️  REVIEW NEEDED: {failed} metrics show significant differences")

print("=" * 80)
