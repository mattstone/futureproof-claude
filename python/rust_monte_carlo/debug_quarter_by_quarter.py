#!/usr/bin/env python3
"""
Quarter-by-quarter debugging: Find where Rust diverges from Python
"""
import sys
sys.path.append('..')

import numpy as np
from core_model_montecarlo import single_mortgage_optimized

# Fixed parameters
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
print("QUARTER-BY-QUARTER DEBUG - PYTHON IMPLEMENTATION")
print("="*100)
print()

# Generate path
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

# Calculate initial values for reference
insurance_pv = (INSURANCE_COST * INSURANCE_PROFIT_MARGIN) / ((1 + CASH_RATE) ** LOAN_DURATION)
initial_investment = TOTAL_LOAN * REINVEST_FRACTION - insurance_pv
initial_units = initial_investment / S0
quarterly_income = ANNUAL_INCOME / 4.0
initial_loan_size = TOTAL_LOAN * REINVEST_FRACTION + quarterly_income
holiday_enter_threshold = initial_investment * HOLIDAY_ENTER_FRACTION
holiday_exit_threshold = initial_investment * HOLIDAY_EXIT_FRACTION

print(f"Initial state:")
print(f"  Insurance PV: ${insurance_pv:,.2f}")
print(f"  Initial investment: ${initial_investment:,.2f}")
print(f"  Initial units: {initial_units:.4f}")
print(f"  Initial loan size: ${initial_loan_size:,.2f}")
print(f"  Holiday enter threshold (135%): ${holiday_enter_threshold:,.2f}")
print(f"  Holiday exit threshold (195%): ${holiday_exit_threshold:,.2f}")
print()

# Extract path 0 data
path0 = python_results[python_results['Path'] == 0].copy()

# Show first 15 quarters in detail
print("FIRST 15 QUARTERS (looking for when customer should exit holiday):")
print()
print("Qtr | SP500   | Units  | Holdings   | LoanSize  | Interest | Deficit   | OnHol | HolQtrs")
print("-" * 100)

for idx, row in path0.iterrows():
    period = int(row['Period'])
    if period > 15:
        break
    if period == 0:
        continue  # Skip period 0

    sp500 = row['SP500']
    units = row['Units']
    holdings = row['Reinvestment']
    loan_size = row['Loan size']
    interest = row['Interest']
    deficit = row['InterestDeficit']
    on_holiday = row['Prob Holiday']
    holiday_qtrs = int(row['HolidayQuarters'])

    # Calculate if above threshold
    above_exit = holdings > holiday_exit_threshold

    marker = ""
    if period > 0 and not on_holiday:
        marker = " <-- EXITED HOLIDAY!"
    elif above_exit and on_holiday:
        marker = " <-- SHOULD EXIT (above threshold)"

    print(f"{period:3d} | ${sp500:7.2f} | {units:6.2f} | ${holdings:10,.0f} | ${loan_size:9,.0f} | ${interest:8,.0f} | ${deficit:9,.0f} | {on_holiday:5} | {holiday_qtrs:7d}{marker}")

print()
print("Key observations:")
final_row = path0.iloc[-1]
print(f"  Final holdings: ${final_row['Reinvestment']:,.2f}")
print(f"  Final deficit: ${final_row['InterestDeficit']:,.2f}")
print(f"  Ever exited holiday: {not all(path0['Prob Holiday'][1:])}")  # Skip period 0
print(f"  Total quarters on holiday: {int(final_row['HolidayQuarters'])}/40")
print()

# Find the quarter where customer exits holiday
exit_periods = path0[~path0['Prob Holiday'] & (path0['Period'] > 0)]['Period'].values
if len(exit_periods) > 0:
    first_exit = exit_periods[0]
    print(f"✅ Customer EXITS holiday at quarter {first_exit}")
    exit_row = path0[path0['Period'] == first_exit].iloc[0]
    print(f"  Holdings at exit: ${exit_row['Reinvestment']:,.2f}")
    print(f"  Exit threshold: ${holiday_exit_threshold:,.2f}")
    print(f"  Ratio: {exit_row['Reinvestment'] / holiday_exit_threshold:.2f}x")
else:
    print(f"❌ Customer NEVER exits holiday (stays on holiday all 40 quarters)")

print()
print("="*100)
print("RUST IMPLEMENTATION MUST MATCH THIS BEHAVIOR")
print("="*100)
