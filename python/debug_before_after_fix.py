#!/usr/bin/env python3

import sys
import json
import math
import pandas as pd
import numpy as np
from core_model_montecarlo import single_mortgage, gen_monte_carlo_paths

print("=== COMPARING BEFORE AND AFTER PARAMETER FIX ===")

# BEFORE FIX: What Rails was doing if it got 80 from form but treated as already decimal
print("\n--- BEFORE FIX SIMULATION (if form sent 80 but we treated as 0.8) ---")
np.random.seed(42)

# This would be WRONG - treating form percentage as if it was already decimal
loan_to_value_wrong = 80.0  # Raw form value treated as decimal = 8000% LTV!
equity_return_wrong = 9.75  # Raw form value treated as decimal = 975% return!
volatility_wrong = 15.0  # Raw form value treated as decimal = 1500% volatility!
cash_rate_wrong = 4.0  # Raw form value treated as decimal = 400% cash rate!
insurer_profit_margin_wrong = 50.0  # Raw form value treated as decimal = 5000% margin!

print(f"WRONG parameters (treating form values as decimals):")
print(f"  loan_to_value: {loan_to_value_wrong} (8000% LTV!)")
print(f"  equity_return: {equity_return_wrong} (975% return!)")
print(f"  volatility: {volatility_wrong} (1500% volatility!)")
print(f"  cash_rate: {cash_rate_wrong} (400% cash rate!)")

# These extreme values would cause the simulation to fail or produce garbage
try:
    house_value = 1500000
    total_loan_wrong = house_value * loan_to_value_wrong  # $120,000,000 loan!
    print(f"  total_loan with wrong LTV: ${total_loan_wrong:,.0f}")
except Exception as e:
    print(f"Error with wrong parameters: {e}")

print("\n--- AFTER FIX SIMULATION (form values properly converted) ---")
np.random.seed(42)

# AFTER FIX: Properly convert form percentages to decimals
loan_to_value_correct = 80.0 / 100.0  # 0.8
equity_return_correct = 9.75 / 100.0  # 0.0975
volatility_correct = 15.0 / 100.0  # 0.15
cash_rate_correct = 4.0 / 100.0  # 0.04
insurer_profit_margin_correct = 50.0 / 100.0  # 0.5

print(f"CORRECT parameters (form values / 100):")
print(f"  loan_to_value: {loan_to_value_correct}")
print(f"  equity_return: {equity_return_correct}")  
print(f"  volatility: {volatility_correct}")
print(f"  cash_rate: {cash_rate_correct}")
print(f"  insurer_profit_margin: {insurer_profit_margin_correct}")

house_value = 1500000
total_loan_correct = house_value * loan_to_value_correct
print(f"  total_loan with correct LTV: ${total_loan_correct:,.0f}")

print(f"\n=== THE KEY INSIGHT ===")
print("If Rails was treating form percentages as decimals, the simulation would either:")
print("1. Fail completely due to extreme values")
print("2. Produce completely unrealistic results")
print("3. Show that we were already converting correctly in some other place")

print(f"\nLet's check what happens if we look at the original default values in Ruby...")
print("The Ruby defaults show 0.8, 0.0975, etc. - these are already decimals!")
print("This suggests the form might be sending correctly converted values,")
print("OR there might be another conversion step we missed.")