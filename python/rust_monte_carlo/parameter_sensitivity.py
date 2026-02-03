#!/usr/bin/env python3
"""
Parameter Sensitivity Analysis for Equity Preservation Mortgage

Analyzes how key parameters affect viability:
1. LVR (Loan-to-Value Ratio)
2. Holiday Entry Threshold
3. Annual Income Fraction
4. Insurance Cost

Tests combinations to find viable parameter space.
"""

import monte_carlo_engine
import pandas as pd
import numpy as np
import time
from itertools import product

# Base parameters (from current 1M run)
BASE_HOUSE_VALUE = 2_000_000
BASE_LVR = 0.80
BASE_LOAN_DURATION = 10
BASE_ANNUITY_DURATION = 10
BASE_ANNUAL_INCOME_FRACTION = 0.015
BASE_HOLIDAY_ENTER = 1.35
BASE_HOLIDAY_EXIT = 1.95
BASE_INSURANCE_COST_PA = 0.005

# Fixed parameters
WHOLESALE_LENDING_MARGIN = 0.03
ADDITIONAL_LOAN_MARGINS = 0.012
SUBPERFORM_LOAN_THRESHOLD_QUARTERS = 6
INSURANCE_PROFIT_MARGIN = 1.5
CASH_RATE = 0.031
HEDGED = True
HEDGING_MAX_LOSS = 0.2
HEDGING_CAP = 0.4
HEDGING_COST_PA = 0.005

# Monte Carlo parameters
MONTE_CARLO_PATHS = 100_000  # 100K for speed, enough for sensitivity
EQUITY_RETURN = 0.10
VOLATILITY = 0.12
S0 = 100.0

# Sensitivity ranges to test
LVR_RANGE = [0.60, 0.65, 0.70, 0.75, 0.80]
HOLIDAY_ENTER_RANGE = [1.10, 1.15, 1.20, 1.25, 1.30, 1.35, 1.40]
INCOME_FRACTION_RANGE = [0.015, 0.020, 0.025, 0.030]
INSURANCE_COST_RANGE = [0.003, 0.004, 0.005, 0.006, 0.007]


def run_scenario(lvr, holiday_enter, income_fraction, insurance_cost_pa, loan_type='Interest Only'):
    """Run single scenario and return key metrics"""

    total_loan = BASE_HOUSE_VALUE * lvr
    annual_income = BASE_HOUSE_VALUE * income_fraction
    reinvest_fraction = 1 - (BASE_ANNUITY_DURATION * annual_income) / total_loan
    insurance_cost = insurance_cost_pa * total_loan * BASE_LOAN_DURATION
    principal_repayment = (loan_type == 'Principal+Interest')
    holiday_exit = holiday_enter + 0.60  # Maintain 0.60 spread

    try:
        results = monte_carlo_engine.single_mortgage_integrated(
            total_loan,
            reinvest_fraction,
            BASE_LOAN_DURATION,
            annual_income,
            BASE_ANNUITY_DURATION,
            INSURANCE_PROFIT_MARGIN,
            insurance_cost,
            CASH_RATE,
            WHOLESALE_LENDING_MARGIN,
            ADDITIONAL_LOAN_MARGINS,
            holiday_enter,
            holiday_exit,
            SUBPERFORM_LOAN_THRESHOLD_QUARTERS,
            MONTE_CARLO_PATHS,
            EQUITY_RETURN,
            VOLATILITY,
            S0,
            principal_repayment,
            HEDGED,
            HEDGING_MAX_LOSS,
            HEDGING_CAP,
            HEDGING_COST_PA
        )

        metrics = monte_carlo_engine.calculate_metrics(
            results, total_loan, reinvest_fraction, BASE_LOAN_DURATION,
            annual_income, BASE_ANNUITY_DURATION, CASH_RATE
        )

        return {
            'lvr': lvr,
            'holiday_enter': holiday_enter,
            'income_fraction': income_fraction,
            'insurance_cost_pa': insurance_cost_pa,
            'loan_type': loan_type,
            'cagr': metrics.mean_cagr,
            'insurance_risk': metrics.prob_insurance_payout,
            'xirr': metrics.xirr if metrics.xirr is not None else np.nan,
            'viable': (metrics.mean_cagr >= 0.08 and metrics.prob_insurance_payout < 0.20),
            'premium_viable': (metrics.mean_cagr >= 0.10 and metrics.prob_insurance_payout < 0.15),
        }
    except Exception as e:
        print(f"Error in scenario: {e}")
        return None


def main():
    print("=" * 80)
    print("PARAMETER SENSITIVITY ANALYSIS")
    print("=" * 80)
    print(f"\nBase case: $2M house, 10y/10y, Interest Only, {MONTE_CARLO_PATHS:,} paths")
    print(f"Current parameters: LVR={BASE_LVR}, Holiday={BASE_HOLIDAY_ENTER}x, Income={BASE_ANNUAL_INCOME_FRACTION:.1%}")

    results = []

    # Test 1: LVR Sensitivity (holding others constant)
    print("\n" + "=" * 80)
    print("TEST 1: LVR SENSITIVITY")
    print("=" * 80)
    print(f"Testing LVR values: {LVR_RANGE}")
    print("(Holding other parameters at base values)")

    for lvr in LVR_RANGE:
        print(f"\nTesting LVR = {lvr:.0%}...", end=" ", flush=True)
        start = time.time()
        result = run_scenario(lvr, BASE_HOLIDAY_ENTER, BASE_ANNUAL_INCOME_FRACTION, BASE_INSURANCE_COST_PA)
        if result:
            results.append(result)
            status = "✅ VIABLE" if result['viable'] else "❌ Not viable"
            print(f"{status} | CAGR: {result['cagr']*100:.2f}% | Insurance: {result['insurance_risk']*100:.2f}% ({time.time()-start:.1f}s)")

    # Test 2: Holiday Threshold Sensitivity
    print("\n" + "=" * 80)
    print("TEST 2: HOLIDAY THRESHOLD SENSITIVITY")
    print("=" * 80)
    print(f"Testing holiday entry thresholds: {HOLIDAY_ENTER_RANGE}")

    for holiday in HOLIDAY_ENTER_RANGE:
        print(f"\nTesting Holiday = {holiday:.2f}x...", end=" ", flush=True)
        start = time.time()
        result = run_scenario(BASE_LVR, holiday, BASE_ANNUAL_INCOME_FRACTION, BASE_INSURANCE_COST_PA)
        if result:
            results.append(result)
            status = "✅ VIABLE" if result['viable'] else "❌ Not viable"
            print(f"{status} | CAGR: {result['cagr']*100:.2f}% | Insurance: {result['insurance_risk']*100:.2f}% ({time.time()-start:.1f}s)")

    # Test 3: Income Fraction Sensitivity
    print("\n" + "=" * 80)
    print("TEST 3: ANNUAL INCOME SENSITIVITY")
    print("=" * 80)
    print(f"Testing income fractions: {[f'{x:.1%}' for x in INCOME_FRACTION_RANGE]}")

    for income_frac in INCOME_FRACTION_RANGE:
        print(f"\nTesting Income = {income_frac:.1%}...", end=" ", flush=True)
        start = time.time()
        result = run_scenario(BASE_LVR, BASE_HOLIDAY_ENTER, income_frac, BASE_INSURANCE_COST_PA)
        if result:
            results.append(result)
            status = "✅ VIABLE" if result['viable'] else "❌ Not viable"
            print(f"{status} | CAGR: {result['cagr']*100:.2f}% | Insurance: {result['insurance_risk']*100:.2f}% ({time.time()-start:.1f}s)")

    # Test 4: Combined optimization - best combinations
    print("\n" + "=" * 80)
    print("TEST 4: COMBINED PARAMETER OPTIMIZATION")
    print("=" * 80)
    print("Testing promising combinations...")

    # Promising combinations based on individual tests
    combinations = [
        (0.70, 1.20, 0.020, 0.004, "Moderate improvement"),
        (0.65, 1.20, 0.020, 0.004, "Strong improvement"),
        (0.70, 1.15, 0.020, 0.004, "Aggressive holidays"),
        (0.65, 1.15, 0.025, 0.004, "Maximum improvement"),
        (0.60, 1.20, 0.020, 0.004, "Conservative LVR"),
    ]

    for lvr, holiday, income, ins_cost, description in combinations:
        print(f"\n{description}: LVR={lvr:.0%}, Holiday={holiday:.2f}x, Income={income:.1%}...", end=" ", flush=True)
        start = time.time()
        result = run_scenario(lvr, holiday, income, ins_cost)
        if result:
            results.append(result)
            status = "✅ VIABLE" if result['viable'] else "❌ Not viable"
            premium = "⭐ PREMIUM" if result['premium_viable'] else ""
            print(f"{status} {premium} | CAGR: {result['cagr']*100:.2f}% | Insurance: {result['insurance_risk']*100:.2f}% ({time.time()-start:.1f}s)")

    # Save results
    df = pd.DataFrame(results)
    df.to_csv('sensitivity_results.csv', index=False)

    # Analysis
    print("\n" + "=" * 80)
    print("SENSITIVITY ANALYSIS SUMMARY")
    print("=" * 80)

    # By parameter
    print("\n📊 IMPACT BY PARAMETER:")

    # LVR impact
    lvr_df = df[df['holiday_enter'] == BASE_HOLIDAY_ENTER].sort_values('lvr')
    if len(lvr_df) > 0:
        print(f"\nLVR Impact (lower = better):")
        for _, row in lvr_df.iterrows():
            print(f"  {row['lvr']:.0%}: CAGR {row['cagr']*100:5.2f}%, Insurance {row['insurance_risk']*100:5.2f}% {'✅' if row['viable'] else '❌'}")

    # Holiday impact
    holiday_df = df[df['lvr'] == BASE_LVR].sort_values('holiday_enter')
    if len(holiday_df) > 0:
        print(f"\nHoliday Threshold Impact (lower = more lenient):")
        for _, row in holiday_df.iterrows():
            print(f"  {row['holiday_enter']:.2f}x: CAGR {row['cagr']*100:5.2f}%, Insurance {row['insurance_risk']*100:5.2f}% {'✅' if row['viable'] else '❌'}")

    # Viable scenarios
    viable = df[df['viable'] == True]
    print(f"\n🎯 VIABLE SCENARIOS: {len(viable)} / {len(df)}")

    if len(viable) > 0:
        print("\nTop 5 viable scenarios:")
        top5 = viable.nlargest(5, 'cagr')
        print(f"\n{'LVR':<6} {'Holiday':<8} {'Income':<8} {'CAGR':<8} {'Insurance':<10} {'XIRR':<8}")
        print("-" * 60)
        for _, row in top5.iterrows():
            xirr_str = f"{row['xirr']*100:5.2f}%" if not np.isnan(row['xirr']) else "  N/A"
            print(f"{row['lvr']:.0%}   {row['holiday_enter']:.2f}x    {row['income_fraction']:.1%}    "
                  f"{row['cagr']*100:5.2f}%  {row['insurance_risk']*100:5.2f}%    {xirr_str}")

        # Best scenario
        best = viable.nlargest(1, 'cagr').iloc[0]
        print(f"\n⭐ RECOMMENDED PARAMETERS:")
        print(f"   LVR:              {best['lvr']:.0%} (currently {BASE_LVR:.0%})")
        print(f"   Holiday Entry:    {best['holiday_enter']:.2f}x (currently {BASE_HOLIDAY_ENTER:.2f}x)")
        print(f"   Annual Income:    {best['income_fraction']:.1%} (currently {BASE_ANNUAL_INCOME_FRACTION:.1%})")
        print(f"   Expected CAGR:    {best['cagr']*100:.2f}%")
        print(f"   Insurance Risk:   {best['insurance_risk']*100:.2f}%")
        print(f"   Company XIRR:     {best['xirr']*100:.2f}%" if not np.isnan(best['xirr']) else "   Company XIRR:     N/A")
    else:
        print("\n❌ NO VIABLE SCENARIOS FOUND in tested range")
        print("   Consider more aggressive parameter changes:")
        print("   - LVR < 60%")
        print("   - Holiday entry < 1.10x")
        print("   - Income fraction > 3.0%")

    print(f"\n✅ Results saved to: sensitivity_results.csv")
    print("=" * 80)


if __name__ == "__main__":
    main()
