#!/usr/bin/env python3

import sys
import json
import math
import pandas as pd
import numpy as np
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths

# Set seed for reproducible results
np.random.seed(42)

# Parameters with HEDGING ENABLED
house_value = 1500000
loan_duration = 30
annuity_duration = 15
loan_to_value = 0.8
annual_income = 30000
total_loan = house_value * loan_to_value
reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan
insurance_profit_margin = 1.5
wholesale_lending_margin = 0.02
additional_loan_margins = 0.015
holiday_enter_fraction = 1.35
holiday_exit_fraction = 1.95
subperform_loan_threshold_quarters = 6
superpay_start_factor = 1.0
max_superpay_factor = 1.0
insurance_cost = 0.02 * total_loan * loan_duration
year0 = 2000
principal_repayment = False
hedged = True  # ENABLE HEDGING
hedging_max_loss = 0.1
hedging_cap = 0.2
hedging_cost_pa = 0.01

equity_return = 0.0975
volatility = 0.15
S0 = 100
cash_rate = 0.04
total_paths = 3

print("=== HEDGED SCENARIO TEST ===")
print(f"Hedged: {hedged}")
print(f"Hedging max loss: {hedging_max_loss}")
print(f"Hedging cap: {hedging_cap}")
print(f"Hedging cost p.a.: {hedging_cost_pa}")

price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)
dt = 1.0/120

df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin, insurance_cost,
                    cash_rate, wholesale_lending_margin, additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)

path_0 = df[df['Path'] == 0].copy()

print(f"\n=== HEDGED FIELDS ANALYSIS ===")
periods_to_check = [0, 20, 40, 80, 119]
for period in periods_to_check:
    row = path_0[path_0['Period'] == period]
    if not row.empty:
        r = row.iloc[0]
        print(f"\n--- Period {period} ---")
        print(f"  HedgeUnitsDelta: {r['HedgeUnitsDelta']:,.0f}")
        print(f"  CumUnitsToPool: {r['CumUnitsToPool']:,.0f}")
        print(f"  UnitsToPool: {r['UnitsToPool']:,.0f}")
        print(f"  Units: {r['Units']:,.0f}")
        print(f"  UnitsSold: {r['UnitsSold']:,.0f}")

# Check if any hedging fields are non-zero
hedge_values = path_0['HedgeUnitsDelta'].tolist()
pool_values = path_0['CumUnitsToPool'].tolist()
print(f"\n=== NON-ZERO VALUES ===")
print(f"HedgeUnitsDelta non-zero periods: {sum(1 for v in hedge_values if v != 0)}")
print(f"CumUnitsToPool non-zero periods: {sum(1 for v in pool_values if v != 0)}")
print(f"Max HedgeUnitsDelta: {max(hedge_values)}")
print(f"Max CumUnitsToPool: {max(pool_values)}")

# Test different parameter combinations that might activate pooling
print(f"\n=== TESTING DIFFERENT SCENARIOS ===")

# Test with different holiday thresholds
scenarios = [
    {"name": "High volatility", "volatility": 0.30},
    {"name": "Low equity return", "equity_return": 0.05},
    {"name": "Higher holiday fractions", "holiday_enter": 2.0, "holiday_exit": 3.0},
]

for scenario in scenarios:
    print(f"\n--- {scenario['name']} ---")
    
    test_equity_return = scenario.get('equity_return', equity_return)
    test_volatility = scenario.get('volatility', volatility)
    test_holiday_enter = scenario.get('holiday_enter', holiday_enter_fraction)
    test_holiday_exit = scenario.get('holiday_exit', holiday_exit_fraction)
    
    test_paths = gen_monte_carlo_paths(loan_duration, test_equity_return, test_volatility, 1, S0)
    
    test_df = single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                        insurance_profit_margin, insurance_cost,
                        cash_rate, wholesale_lending_margin, additional_loan_margins,
                        test_holiday_enter, test_holiday_exit, subperform_loan_threshold_quarters,
                        test_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                        0, None, principal_repayment, hedged, hedging_max_loss, hedging_cap, hedging_cost_pa)
    
    test_path = test_df[test_df['Path'] == 0]
    test_hedge_values = test_path['HedgeUnitsDelta'].tolist()
    test_pool_values = test_path['CumUnitsToPool'].tolist()
    test_holiday_quarters = test_path['Prob Holiday'].sum()
    
    print(f"  Holiday quarters: {test_holiday_quarters}")
    print(f"  HedgeUnitsDelta non-zero: {sum(1 for v in test_hedge_values if v != 0)}")
    print(f"  CumUnitsToPool non-zero: {sum(1 for v in test_pool_values if v != 0)}")