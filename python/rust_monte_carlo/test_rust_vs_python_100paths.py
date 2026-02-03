#!/usr/bin/env python3
"""
Direct comparison: Rust vs Python on SAME 100 paths
"""
import sys
sys.path.append('..')

import numpy as np
import monte_carlo_engine
from core_model_montecarlo import single_mortgage_optimized

# Fixed seed
SEED = 42
NUM_PATHS = 100

# Parameters
TOTAL_LOAN = 800_000
REINVEST_FRACTION = 0.8125
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
EQUITY_RETURN = 0.10
VOLATILITY = 0.12
S0 = 100.0
PRINCIPAL_REPAYMENT = False
HEDGED = True
HEDGING_MAX_LOSS = 0.2
HEDGING_CAP = 0.4
HEDGING_COST_PA = 0.005

print("="*80)
print("RUST VS PYTHON: 100 IDENTICAL PATHS")
print("="*80)
print()

# Generate 100 paths with fixed seed
np.random.seed(SEED)
dt = 1.0 / 120.0
n_steps = int(LOAN_DURATION / dt)

print(f"Generating {NUM_PATHS} paths with seed={SEED}...")
paths = []
for path_num in range(NUM_PATHS):
    path = [S0]
    price = S0
    drift = (EQUITY_RETURN - 0.5 * VOLATILITY * VOLATILITY) * dt
    diffusion = VOLATILITY * np.sqrt(dt)
    
    for _ in range(n_steps - 1):
        dw = np.random.randn()
        price *= np.exp(drift + diffusion * dw)
        path.append(price)
    
    paths.append((path_num, np.array(path)))

print(f"Generated {len(paths)} paths")
print()

# Run Python simulation
print("Running Python simulation...")
python_results = single_mortgage_optimized(
    TOTAL_LOAN, REINVEST_FRACTION, LOAN_DURATION, ANNUAL_INCOME, ANNUITY_DURATION,
    INSURANCE_PROFIT_MARGIN, INSURANCE_COST, CASH_RATE, WHOLESALE_LENDING_MARGIN,
    ADDITIONAL_LOAN_MARGINS, HOLIDAY_ENTER_FRACTION, HOLIDAY_EXIT_FRACTION,
    SUBPERFORM_THRESHOLD, paths, S0, dt, 0, 1.0, 1.0, False,
    0, None, PRINCIPAL_REPAYMENT, HEDGED, HEDGING_MAX_LOSS, HEDGING_CAP, HEDGING_COST_PA
)

# Extract final period values
final_period = LOAN_DURATION * 4
python_finals = python_results[python_results['Period'] == final_period]

python_mean_reinvestment = python_finals['Reinvestment'].mean()
python_mean_deficit = python_finals['InterestDeficit'].mean()
python_total_holiday_qtrs = python_finals['HolidayQuarters'].sum()

print(f"Python mean reinvestment: ${python_mean_reinvestment:,.2f}")
print(f"Python mean deficit: ${python_mean_deficit:,.2f}")
print(f"Python total holiday quarters: {python_total_holiday_qtrs}")
print()

# Run Rust simulation on SAME paths
print("Running Rust simulation on SAME paths...")
paths_for_rust = [path[1].tolist() for path in paths]

rust_results = monte_carlo_engine.single_mortgage_rust(
    TOTAL_LOAN, REINVEST_FRACTION, LOAN_DURATION, ANNUAL_INCOME, ANNUITY_DURATION,
    INSURANCE_PROFIT_MARGIN, INSURANCE_COST, CASH_RATE,
    WHOLESALE_LENDING_MARGIN, ADDITIONAL_LOAN_MARGINS,
    HOLIDAY_ENTER_FRACTION, HOLIDAY_EXIT_FRACTION,
    SUBPERFORM_THRESHOLD, paths_for_rust, S0,
    PRINCIPAL_REPAYMENT, HEDGED, HEDGING_MAX_LOSS, HEDGING_CAP, HEDGING_COST_PA
)

rust_mean_reinvestment = np.mean([r.reinvestment for r in rust_results])
rust_mean_deficit = np.mean([r.interest_deficit for r in rust_results])
rust_total_holiday_qtrs = sum([r.quarters_in_holiday for r in rust_results])

print(f"Rust mean reinvestment: ${rust_mean_reinvestment:,.2f}")
print(f"Rust mean deficit: ${rust_mean_deficit:,.2f}")
print(f"Rust total holiday quarters: {rust_total_holiday_qtrs}")
print()

# Compare
print("="*80)
print("COMPARISON")
print("="*80)
print()
print(f"Mean Reinvestment difference: ${abs(python_mean_reinvestment - rust_mean_reinvestment):,.2f}")
print(f"Mean Deficit difference: ${abs(python_mean_deficit - rust_mean_deficit):,.2f}")
print(f"Holiday quarters difference: {abs(python_total_holiday_qtrs - rust_total_holiday_qtrs)}")
print()

tolerance = 100.0  # $100 tolerance
if (abs(python_mean_reinvestment - rust_mean_reinvestment) < tolerance and
    abs(python_mean_deficit - rust_mean_deficit) < tolerance and
    abs(python_total_holiday_qtrs - rust_total_holiday_qtrs) < 5):
    print("✅ PASS: Rust matches Python on 100 identical paths")
else:
    print("❌ FAIL: Rust does NOT match Python")
    print()
    print("This means there's a bug in either:")
    print("1. The Rust simulation logic")
    print("2. How paths are being generated in integrated mode")

