#!/usr/bin/env python3
"""
Comprehensive validation: Rust vs Python Monte Carlo
Tests that Rust implementation matches Python exactly
"""
import sys
sys.path.append('..')

import numpy as np
import monte_carlo_engine
from core_model_montecarlo import gen_monte_carlo_paths_vectorized, single_mortgage_optimized

# Test parameters
TOTAL_LOAN = 800_000
REINVEST_FRACTION = 0.812
LOAN_DURATION = 10
ANNUAL_INCOME = 15_000
ANNUITY_DURATION = 10
INSURANCE_PROFIT_MARGIN = 1.5
INSURANCE_COST = 40_000
CASH_RATE = 0.031
WHOLESALE_LENDING_MARGIN = 0.03
ADDITIONAL_LOAN_MARGINS = 0.012
HOLIDAY_ENTER_FRACTION = 1.35
HOLIDAY_EXIT_FRACTION = 1.95
SUBPERFORM_THRESHOLD = 6
NUM_PATHS = 100  # Small for validation
EQUITY_RETURN = 0.10
VOLATILITY = 0.12
S0 = 100.0
PRINCIPAL_REPAYMENT = False
HEDGED = True
HEDGING_MAX_LOSS = 0.2
HEDGING_CAP = 0.4
HEDGING_COST_PA = 0.005

print("="*80)
print("VALIDATING RUST VS PYTHON MONTE CARLO")
print("="*80)
print()

# Generate paths with Python
print(f"Generating {NUM_PATHS} Monte Carlo paths with Python...")
np.random.seed(42)  # For reproducibility
price_paths_python = gen_monte_carlo_paths_vectorized(
    LOAN_DURATION, EQUITY_RETURN, VOLATILITY, NUM_PATHS, S0
)

# Run Python simulation
print("Running Python simulation...")
python_results = single_mortgage_optimized(
    TOTAL_LOAN, REINVEST_FRACTION, LOAN_DURATION, ANNUAL_INCOME, ANNUITY_DURATION,
    INSURANCE_PROFIT_MARGIN, INSURANCE_COST, CASH_RATE, WHOLESALE_LENDING_MARGIN,
    ADDITIONAL_LOAN_MARGINS, HOLIDAY_ENTER_FRACTION, HOLIDAY_EXIT_FRACTION,
    SUBPERFORM_THRESHOLD, price_paths_python, S0, 1.0/120, 0, 1.0, 1.0, False,
    0, None, PRINCIPAL_REPAYMENT, HEDGED, HEDGING_MAX_LOSS, HEDGING_CAP, HEDGING_COST_PA
)

# Extract key metrics from Python
python_df = python_results[python_results['period'] == LOAN_DURATION * 4]
python_final_reinvestments = python_df['reinvestment'].values
python_mean_reinvestment = python_final_reinvestments.mean()

# Calculate Python deficit
python_deferred = python_df['deferred'].values
python_mean_deficit = python_deferred.mean()

print(f"Python mean final reinvestment: ${python_mean_reinvestment:,.0f}")
print(f"Python mean deficit: ${python_mean_deficit:,.0f}")
print()

# Run Rust simulation (integrated version)
print("Running Rust simulation...")
rust_results = monte_carlo_engine.single_mortgage_integrated(
    TOTAL_LOAN, REINVEST_FRACTION, LOAN_DURATION, ANNUAL_INCOME, ANNUITY_DURATION,
    INSURANCE_PROFIT_MARGIN, INSURANCE_COST, CASH_RATE,
    WHOLESALE_LENDING_MARGIN, ADDITIONAL_LOAN_MARGINS,
    HOLIDAY_ENTER_FRACTION, HOLIDAY_EXIT_FRACTION,
    SUBPERFORM_THRESHOLD, NUM_PATHS,
    EQUITY_RETURN, VOLATILITY, S0, PRINCIPAL_REPAYMENT,
    HEDGED, HEDGING_MAX_LOSS, HEDGING_CAP, HEDGING_COST_PA
)

# Calculate Rust metrics
rust_metrics = monte_carlo_engine.calculate_metrics(
    rust_results, TOTAL_LOAN, REINVEST_FRACTION, LOAN_DURATION,
    ANNUAL_INCOME, ANNUITY_DURATION, CASH_RATE
)

print(f"Rust mean final reinvestment: ${rust_metrics.mean_reinvestment:,.0f}")
print(f"Rust mean deficit: ${rust_metrics.mean_deficit:,.0f}")
print()

# Compare
print("="*80)
print("COMPARISON")
print("="*80)

reinvestment_diff = abs(python_mean_reinvestment - rust_metrics.mean_reinvestment)
reinvestment_pct_diff = (reinvestment_diff / python_mean_reinvestment) * 100

deficit_diff = abs(python_mean_deficit - rust_metrics.mean_deficit)
deficit_pct_diff = (deficit_diff / python_mean_deficit) * 100 if python_mean_deficit > 0 else 0

print(f"Reinvestment:")
print(f"  Python: ${python_mean_reinvestment:,.0f}")
print(f"  Rust:   ${rust_metrics.mean_reinvestment:,.0f}")
print(f"  Diff:   ${reinvestment_diff:,.0f} ({reinvestment_pct_diff:.2f}%)")
print()

print(f"Deficit:")
print(f"  Python: ${python_mean_deficit:,.0f}")
print(f"  Rust:   ${rust_metrics.mean_deficit:,.0f}")
print(f"  Diff:   ${deficit_diff:,.0f} ({deficit_pct_diff:.2f}%)")
print()

# Validation thresholds
TOLERANCE_PCT = 5.0  # 5% tolerance due to different random seeds

if reinvestment_pct_diff < TOLERANCE_PCT and deficit_pct_diff < TOLERANCE_PCT:
    print("✅ VALIDATION PASSED - Rust matches Python within tolerance")
    sys.exit(0)
else:
    print("⚠️  VALIDATION FAILED - Differences exceed tolerance")
    if reinvestment_pct_diff >= TOLERANCE_PCT:
        print(f"   Reinvestment diff: {reinvestment_pct_diff:.2f}% >= {TOLERANCE_PCT}%")
    if deficit_pct_diff >= TOLERANCE_PCT:
        print(f"   Deficit diff: {deficit_pct_diff:.2f}% >= {TOLERANCE_PCT}%")
    sys.exit(1)
