#!/usr/bin/env python3
"""
Compare Rust vs Python quarter-by-quarter to find divergence
"""
import sys
sys.path.append('..')

import numpy as np
import monte_carlo_engine
from core_model_montecarlo import single_mortgage_optimized

# Same parameters
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

print("="*100)
print("QUARTER-BY-QUARTER COMPARISON: Python vs Rust")
print("="*100)
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

# Run Python simulation
price_paths_python = [(0, np.array(path))]
python_results = single_mortgage_optimized(
    TOTAL_LOAN, REINVEST_FRACTION, LOAN_DURATION, ANNUAL_INCOME, ANNUITY_DURATION,
    INSURANCE_PROFIT_MARGIN, INSURANCE_COST, CASH_RATE, WHOLESALE_LENDING_MARGIN,
    ADDITIONAL_LOAN_MARGINS, HOLIDAY_ENTER_FRACTION, HOLIDAY_EXIT_FRACTION,
    SUBPERFORM_THRESHOLD, price_paths_python, S0, dt, 0, 1.0, 1.0, False,
    0, None, PRINCIPAL_REPAYMENT, HEDGED, HEDGING_MAX_LOSS, HEDGING_CAP, HEDGING_COST_PA
)

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

# Extract Python path 0 data
path0 = python_results[python_results['Path'] == 0].copy()

print("Comparing first 10 quarters in detail:")
print()
print("Q  | Price   | Python Units | Rust (calc) | Diff   | Python Deficit | Rust Deficit | Diff")
print("-" * 100)

# Calculate what Rust should have quarter by quarter
# We'll manually simulate to match what we expect
insurance_pv = (INSURANCE_COST * INSURANCE_PROFIT_MARGIN) / ((1 + CASH_RATE) ** LOAN_DURATION)
initial_investment = TOTAL_LOAN * REINVEST_FRACTION - insurance_pv
initial_units = initial_investment / S0
quarterly_income = ANNUAL_INCOME / 4.0

# Manual Rust simulation for comparison
rust_units = initial_units
rust_loan_size = TOTAL_LOAN * REINVEST_FRACTION + quarterly_income
rust_deficit = 0.0
on_holiday = HOLIDAY_ENTER_FRACTION > 1.0
holiday_exit_threshold = initial_investment * HOLIDAY_EXIT_FRACTION

quarterly_interest_rate = (CASH_RATE / 4.0) + ((WHOLESALE_LENDING_MARGIN + ADDITIONAL_LOAN_MARGINS) / 4.0)
last_yearly_hedge_price = S0

for q in range(1, 11):
    # Get price at this quarter
    month_idx = (q * 30) - 1
    price_q = path[month_idx]

    # Calculate interest
    interest_due = rust_loan_size * quarterly_interest_rate
    interest_due_per_share = interest_due / price_q
    holdings_value = rust_units * price_q

    # Holiday logic
    if on_holiday:
        if holdings_value > holiday_exit_threshold:
            on_holiday = False
            rust_units -= interest_due_per_share  # Pay interest
        else:
            rust_deficit += interest_due  # Defer interest
    else:
        rust_units -= interest_due_per_share  # Pay interest

    # Hedging (every 4 quarters)
    if q % 4 == 0:
        rust_units -= rust_units * HEDGING_COST_PA
        year_move = (price_q - last_yearly_hedge_price) / last_yearly_hedge_price
        if year_move < -HEDGING_MAX_LOSS:
            buy_units = ((last_yearly_hedge_price / price_q) * (1.0 - HEDGING_MAX_LOSS) - 1.0) * rust_units
            rust_units += buy_units
        last_yearly_hedge_price = price_q

    # Annuity payment (if q < 40)
    if q < ANNUITY_DURATION * 4:
        units_for_annuity = quarterly_income / price_q
        rust_units -= units_for_annuity
        rust_loan_size += quarterly_income

    # Get Python values
    py_row = path0[path0['Period'] == q].iloc[0]
    py_units = py_row['Units']
    py_deficit = py_row['InterestDeficit']

    # Compare
    units_diff = abs(py_units - rust_units)
    deficit_diff = abs(py_deficit - rust_deficit)

    print(f"{q:2d} | ${price_q:7.2f} | {py_units:12.4f} | {rust_units:11.4f} | {units_diff:6.4f} | ${py_deficit:14,.0f} | ${rust_deficit:12,.0f} | ${deficit_diff:,.0f}")

print()
print("Final comparison:")
print(f"  Python final units: {path0.iloc[-1]['Units']:.4f}")
print(f"  Rust calculated:    {rust_units:.4f}")
print(f"  Python final deficit: ${path0.iloc[-1]['InterestDeficit']:,.2f}")
print(f"  Rust calculated:      ${rust_deficit:,.2f}")
print()

rust_final = rust_results[0]
print(f"  Rust ACTUAL reinvestment: ${rust_final.reinvestment:,.2f}")
print(f"  Rust ACTUAL deficit:      ${rust_final.interest_deficit:,.2f}")
print()

print("If calculated values don't match actual Rust values, there's a bug in Rust implementation.")
