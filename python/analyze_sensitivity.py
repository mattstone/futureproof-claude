"""
Analyze sensitivity results to identify viable parameter combinations
"""

import pandas as pd
import numpy as np

# Read results
df = pd.read_csv('sensitivity_results.csv')

# Filter valid XIRRs
df_valid = df[df['xirr'].notna()].copy()

print("="*80)
print("PARAMETER SENSITIVITY ANALYSIS - RESULTS")
print("="*80)
print(f"\nTotal scenarios tested: {len(df)}")
print(f"Valid XIRR scenarios: {len(df_valid)}")

# Define viability thresholds
RISK_FREE_RATE = 0.04
MIN_VIABLE_XIRR = 0.02  # 2% minimum
TARGET_XIRR = 0.04      # 4% target

print("\n" + "="*80)
print("VIABILITY ASSESSMENT")
print("="*80)

viable_2pct = df_valid[df_valid['xirr'] >= MIN_VIABLE_XIRR]
viable_4pct = df_valid[df_valid['xirr'] >= TARGET_XIRR]

print(f"\nScenarios with XIRR >= 2%: {len(viable_2pct)} ({100*len(viable_2pct)/len(df_valid):.1f}%)")
print(f"Scenarios with XIRR >= 4%: {len(viable_4pct)} ({100*len(viable_4pct)/len(df_valid):.1f}%)")

print("\n" + "-"*80)
print("OVERALL RETURN DISTRIBUTION")
print("-"*80)
print(f"Mean XIRR: {df_valid['xirr'].mean():.2%}")
print(f"Median XIRR: {df_valid['xirr'].median():.2%}")
print(f"Min XIRR: {df_valid['xirr'].min():.2%}")
print(f"Max XIRR: {df_valid['xirr'].max():.2%}")

print("\nXIRR Distribution:")
print(f"  < 0%: {(df_valid['xirr'] < 0).sum()} scenarios ({100*(df_valid['xirr'] < 0).mean():.1f}%)")
print(f"  0-2%: {((df_valid['xirr'] >= 0) & (df_valid['xirr'] < 0.02)).sum()} scenarios ({100*((df_valid['xirr'] >= 0) & (df_valid['xirr'] < 0.02)).mean():.1f}%)")
print(f"  2-4%: {((df_valid['xirr'] >= 0.02) & (df_valid['xirr'] < 0.04)).sum()} scenarios ({100*((df_valid['xirr'] >= 0.02) & (df_valid['xirr'] < 0.04)).mean():.1f}%)")
print(f"  4-6%: {((df_valid['xirr'] >= 0.04) & (df_valid['xirr'] < 0.06)).sum()} scenarios ({100*((df_valid['xirr'] >= 0.04) & (df_valid['xirr'] < 0.06)).mean():.1f}%)")
print(f"  6%+: {(df_valid['xirr'] >= 0.06).sum()} scenarios ({100*(df_valid['xirr'] >= 0.06).mean():.1f}%)")

if len(viable_2pct) > 0:
    print("\n" + "="*80)
    print("TOP 10 VIABLE SCENARIOS (XIRR >= 2%)")
    print("="*80)
    # Check which column name exists
    income_col = 'annual_income_pct' if 'annual_income_pct' in viable_2pct.columns else 'annual_income'
    top10 = viable_2pct.nlargest(10, 'xirr')[['ltv', 'lending_margin', 'additional_margin',
                                               income_col, 'insurance_cost_pa',
                                               'xirr', 'mean_cagr', 'prob_insurance_payout']]
    print(top10.to_string(index=False))

    print("\n" + "="*80)
    print("PATTERN ANALYSIS - WHAT MAKES A SCENARIO VIABLE?")
    print("="*80)

    print("\n📊 By LTV (Loan-to-Value):")
    for ltv in sorted(df_valid['ltv'].unique()):
        subset = df_valid[df_valid['ltv'] == ltv]
        viable_count = (subset['xirr'] >= MIN_VIABLE_XIRR).sum()
        print(f"  {ltv:.0%}: Mean XIRR = {subset['xirr'].mean():.2%}, "
              f"Viable scenarios = {viable_count}/{len(subset)} ({100*viable_count/len(subset):.1f}%)")

    print("\n💰 By Total Cost of Funds (Cash Rate + Lending + Additional):")
    for cof in sorted(df_valid['total_cost_of_funds'].unique()):
        subset = df_valid[df_valid['total_cost_of_funds'] == cof]
        viable_count = (subset['xirr'] >= MIN_VIABLE_XIRR).sum()
        print(f"  {cof:.1%}: Mean XIRR = {subset['xirr'].mean():.2%}, "
              f"Viable scenarios = {viable_count}/{len(subset)} ({100*viable_count/len(subset):.1f}%)")

    print("\n📉 By Annual Income to Borrower:")
    # Check which column exists
    if 'annual_income_pct' in df_valid.columns:
        for income_pct in sorted(df_valid['annual_income_pct'].unique()):
            subset = df_valid[df_valid['annual_income_pct'] == income_pct]
            viable_count = (subset['xirr'] >= MIN_VIABLE_XIRR).sum()
            print(f"  {income_pct:.1%} of home value: Mean XIRR = {subset['xirr'].mean():.2%}, "
                  f"Viable scenarios = {viable_count}/{len(subset)} ({100*viable_count/len(subset):.1f}%)")
    else:
        for income in sorted(df_valid['annual_income'].unique()):
            subset = df_valid[df_valid['annual_income'] == income]
            viable_count = (subset['xirr'] >= MIN_VIABLE_XIRR).sum()
            print(f"  ${income:,}: Mean XIRR = {subset['xirr'].mean():.2%}, "
                  f"Viable scenarios = {viable_count}/{len(subset)} ({100*viable_count/len(subset):.1f}%)")

    print("\n🛡️ By Insurance Cost PA:")
    for ins_cost in sorted(df_valid['insurance_cost_pa'].unique()):
        subset = df_valid[df_valid['insurance_cost_pa'] == ins_cost]
        viable_count = (subset['xirr'] >= MIN_VIABLE_XIRR).sum()
        print(f"  {ins_cost:.1%}: Mean XIRR = {subset['xirr'].mean():.2%}, "
              f"Viable scenarios = {viable_count}/{len(subset)} ({100*viable_count/len(subset):.1f}%)")

    print("\n" + "="*80)
    print("RECOMMENDED PARAMETER CHANGES")
    print("="*80)

    # Find the best viable scenario
    best = viable_2pct.nlargest(1, 'xirr').iloc[0]

    print("\n🎯 BEST VIABLE SCENARIO:")
    print(f"  LTV: {best['ltv']:.0%} (current: 80%)")
    print(f"  Lending Margin: {best['lending_margin']:.1%} (current: 3.0%)")
    print(f"  Additional Margin: {best['additional_margin']:.1%} (current: 1.0%)")
    if 'annual_income_pct' in best:
        print(f"  Annual Income: {best['annual_income_pct']:.1%} of home value (${best['annual_income']:,.0f}) (current: 1.5%)")
    else:
        print(f"  Annual Income: ${best['annual_income']:,.0f} (current: $30,000)")
    print(f"  Insurance Cost PA: {best['insurance_cost_pa']:.1%} (current: 2.0%)")
    print(f"\n  📈 Expected XIRR: {best['xirr']:.2%}")
    print(f"  📈 Expected CAGR: {best['mean_cagr']:.2%}")
    print(f"  ⚠️  Insurance Payout Risk: {best['prob_insurance_payout']:.1%}")

    # Calculate averages of viable scenarios
    print("\n📊 AVERAGE OF ALL VIABLE SCENARIOS (XIRR >= 2%):")
    print(f"  Average LTV: {viable_2pct['ltv'].mean():.1%}")
    print(f"  Average Lending Margin: {viable_2pct['lending_margin'].mean():.2%}")
    print(f"  Average Additional Margin: {viable_2pct['additional_margin'].mean():.2%}")
    if 'annual_income_pct' in viable_2pct.columns:
        print(f"  Average Annual Income %: {viable_2pct['annual_income_pct'].mean():.2%} of home value")
    if 'annual_income' in viable_2pct.columns:
        print(f"  Average Annual Income $: ${viable_2pct['annual_income'].mean():,.0f}")
    print(f"  Average Insurance Cost: {viable_2pct['insurance_cost_pa'].mean():.2%}")
    print(f"\n  📈 Average XIRR: {viable_2pct['xirr'].mean():.2%}")
    print(f"  ⚠️  Average Insurance Risk: {viable_2pct['prob_insurance_payout'].mean():.1%}")

else:
    print("\n❌ NO VIABLE SCENARIOS FOUND")
    print("   Even with parameter adjustments, this product may not be viable.")
    print("\n   Consider:")
    print("   - Further reducing LTV (below 40%)")
    print("   - Further increasing lending margins (above 6%)")
    print("   - Further reducing annual income (below $15,000)")
    print("   - Alternative product structures (annuities, shared equity, etc.)")

print("\n" + "="*80)
print("INSURANCE RISK ANALYSIS")
print("="*80)
print(f"\nMean insurance payout probability: {df_valid['prob_insurance_payout'].mean():.1%}")
print(f"Scenarios with <50% insurance risk: {(df_valid['prob_insurance_payout'] < 0.5).sum()} ({100*(df_valid['prob_insurance_payout'] < 0.5).mean():.1f}%)")

if len(viable_2pct) > 0:
    print(f"\nAmong viable scenarios (XIRR >= 2%):")
    print(f"  Mean insurance risk: {viable_2pct['prob_insurance_payout'].mean():.1%}")
    print(f"  Min insurance risk: {viable_2pct['prob_insurance_payout'].min():.1%}")
    print(f"  Max insurance risk: {viable_2pct['prob_insurance_payout'].max():.1%}")

print("\n" + "="*80)
