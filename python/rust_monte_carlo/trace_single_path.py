#!/usr/bin/env python3
"""
Trace a single path through Python implementation to understand exact behavior
"""
import sys
sys.path.append('..')
import numpy as np
from core_model_montecarlo import gen_monte_carlo_paths_vectorized, single_mortgage_optimized

# Generate ONE path with fixed seed
np.random.seed(42)
paths = gen_monte_carlo_paths_vectorized(10, 0.10, 0.12, 1, 100.0)

# Run simulation
result = single_mortgage_optimized(
    800_000, 0.812, 10, 15_000, 10,
    1.5, 40_000, 0.031, 0.03, 0.012,
    1.35, 1.95, 6, paths, 100.0, 1.0/120,
    0, 1.0, 1.0, False, 0, None, False,
    True, 0.2, 0.4, 0.005
)

# Calculate key thresholds
total_loan = 800_000
reinvest_fraction = 0.812
annual_income = 15_000
quarterly_income = annual_income / 4
insurance_profit_margin = 1.5
insurance_cost = 40_000
cash_rate = 0.031
loan_duration = 10

insurance_pv = (insurance_cost * insurance_profit_margin) / ((1 + cash_rate) ** loan_duration)
initial_investment = total_loan * reinvest_fraction - insurance_pv
initial_units = initial_investment / 100.0
initial_loan_size = total_loan * reinvest_fraction + quarterly_income

holiday_enter_threshold = initial_investment * 1.35
holiday_exit_threshold = initial_investment * 1.95

print("="*100)
print("SINGLE PATH TRACE - PYTHON IMPLEMENTATION")
print("="*100)
print()
print(f"Initial values:")
print(f"  Total loan: ${total_loan:,.0f}")
print(f"  Reinvest fraction: {reinvest_fraction}")
print(f"  Insurance PV: ${insurance_pv:,.0f}")
print(f"  Initial investment: ${initial_investment:,.0f}")
print(f"  Initial units: {initial_units:,.2f}")
print(f"  Initial loan size: ${initial_loan_size:,.0f}")
print(f"  Quarterly income: ${quarterly_income:,.0f}")
print()
print(f"Holiday thresholds:")
print(f"  Enter (135%): ${holiday_enter_threshold:,.0f}")
print(f"  Exit (195%): ${holiday_exit_threshold:,.0f}")
print()

# Extract path 0 data
path0 = result[result['Path'] == 0].copy()

print("Quarter-by-quarter trace:")
print()
print("Period | SP500  | Units | Holdings  | LoanSize | Interest | IntDeficit | Holiday | HolQtrs")
print("-"*100)

for idx, row in path0.iterrows():
    period = int(row['Period'])
    if period > 10:  # Just show first 10 periods
        break

    sp500 = row['SP500']
    units = row['Units']
    holdings = row['Reinvestment']
    loan_size = row['Loan size']
    interest = row['Interest']
    deficit = row['InterestDeficit']
    on_holiday = row['Prob Holiday']
    holiday_qtrs = row['HolidayQuarters']

    print(f"{period:6d} | ${sp500:6.2f} | {units:5.2f} | ${holdings:9,.0f} | ${loan_size:8,.0f} | ${interest:8,.0f} | ${deficit:10,.0f} | {on_holiday:7} | {holiday_qtrs:7d}")

print()
print("Key observations:")
path0_final = path0[path0['Period'] == 40].iloc[0]
print(f"  Final deficit: ${path0_final['InterestDeficit']:,.0f}")
print(f"  Final loan size: ${path0_final['Loan size']:,.0f}")
print(f"  Ever exited holiday: {not all(path0['Prob Holiday'])}")
print(f"  Quarters on holiday: {int(path0['HolidayQuarters'].iloc[-1])}/40")
