#!/usr/bin/env python3
"""
Test Rust with detailed debugging output
We'll manually trace through quarters 28-32 to see why Rust doesn't exit holiday
"""
import sys
sys.path.append('..')

import numpy as np
import monte_carlo_engine

# Same parameters as other tests
SEED = 42
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
EQUITY_RETURN = 0.10
VOLATILITY = 0.12
S0 = 100.0
PRINCIPAL_REPAYMENT = False
HEDGED = True
HEDGING_MAX_LOSS = 0.2
HEDGING_CAP = 0.4
HEDGING_COST_PA = 0.005

print("="*80)
print("RUST DEBUG TEST")
print("="*80)
print()

# Generate the same path
np.random.seed(SEED)
dt = 1.0 / 120.0
n_steps = int(LOAN_DURATION / dt)
path = [S0]
price = S0
drift = (EQUITY_RETURN - 0.5 * VOLATILITY * VOLATILITY) * dt
diffusion = VOLATILITY * np.sqrt(dt)

for _ in range(n_steps - 1):
    dw = np.random.randn()
    price *= np.exp(drift + diffusion * dw)
    path.append(price)

# Calculate thresholds
insurance_pv = (INSURANCE_COST * INSURANCE_PROFIT_MARGIN) / ((1 + CASH_RATE) ** LOAN_DURATION)
initial_investment = TOTAL_LOAN * REINVEST_FRACTION - insurance_pv
holiday_exit_threshold = initial_investment * HOLIDAY_EXIT_FRACTION

print(f"Initial investment: ${initial_investment:,.2f}")
print(f"Holiday EXIT threshold: ${holiday_exit_threshold:,.2f}")
print()

# Get prices at key quarters (using period * 3 as month index)
print("Prices at key quarters:")
for q in [28, 29, 30, 31, 32]:
    month_idx = q * 3
    if month_idx < len(path):
        print(f"  Q{q}: month_idx={month_idx}, price=${path[month_idx]:.2f}")
print()

# Run Rust simulation
path_for_rust = [path]
rust_results = monte_carlo_engine.single_mortgage_rust(
    TOTAL_LOAN, REINVEST_FRACTION, LOAN_DURATION, ANNUAL_INCOME, ANNUITY_DURATION,
    INSURANCE_PROFIT_MARGIN, INSURANCE_COST, CASH_RATE,
    WHOLESALE_LENDING_MARGIN, ADDITIONAL_LOAN_MARGINS,
    HOLIDAY_ENTER_FRACTION, HOLIDAY_EXIT_FRACTION,
    SUBPERFORM_THRESHOLD, path_for_rust, S0,
    PRINCIPAL_REPAYMENT, HEDGED, HEDGING_MAX_LOSS, HEDGING_CAP, HEDGING_COST_PA
)

rust_result = rust_results[0]
print(f"Rust result:")
print(f"  Final reinvestment: ${rust_result.reinvestment:,.2f}")
print(f"  Final deficit: ${rust_result.interest_deficit:,.2f}")
print(f"  Quarters in holiday: {rust_result.quarters_in_holiday}")
print()

if rust_result.quarters_in_holiday == 40:
    print("❌ BUG CONFIRMED: Rust never exits holiday")
    print()
    print("The bug is in the Rust simulation loop.")
    print("Need to add println! debugging to src/lib.rs to trace exact values.")
else:
    print("✅ Rust exits holiday correctly")
