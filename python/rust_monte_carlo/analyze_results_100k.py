#!/usr/bin/env python3
"""
Analyze profitability results from 100,000 path Monte Carlo sweep
"""

import pandas as pd
import numpy as np

# Load results
df = pd.read_csv('profitability_results_optimized_100k.csv')

print("=" * 80)
print("PROFITABILITY ANALYSIS - 100,000 MONTE CARLO PATHS")
print("=" * 80)

print(f"\nTotal scenarios analyzed: {len(df):,}")
print(f"House values: ${df['house_value'].min():,.0f} to ${df['house_value'].max():,.0f}")
print(f"Loan durations: {sorted(df['loan_duration'].unique())} years")
print(f"Loan types: {df['loan_type'].unique().tolist()}")

# Filter for viable scenarios (positive XIRR)
viable = df[df['xirr'].notna() & (df['xirr'] > 0)].copy()
print(f"\n{'='*80}")
print(f"VIABLE SCENARIOS (positive XIRR)")
print(f"{'='*80}")
print(f"Viable scenarios: {len(viable):,} / {len(df):,} ({len(viable)/len(df)*100:.1f}%)")

if len(viable) > 0:
    print(f"\nXIRR Statistics (viable scenarios only):")
    print(f"  Mean XIRR:   {viable['xirr'].mean()*100:.2f}%")
    print(f"  Median XIRR: {viable['xirr'].median()*100:.2f}%")
    print(f"  Std XIRR:    {viable['xirr'].std()*100:.2f}%")
    print(f"  Min XIRR:    {viable['xirr'].min()*100:.2f}%")
    print(f"  Max XIRR:    {viable['xirr'].max()*100:.2f}%")

    print(f"\nCAGR Statistics (viable scenarios only):")
    print(f"  Mean CAGR:   {viable['mean_cagr'].mean()*100:.2f}%")
    print(f"  Median CAGR: {viable['mean_cagr'].median()*100:.2f}%")
    print(f"  Min CAGR:    {viable['mean_cagr'].min()*100:.2f}%")
    print(f"  Max CAGR:    {viable['mean_cagr'].max()*100:.2f}%")

    print(f"\nInsurance Risk (viable scenarios only):")
    print(f"  Mean probability of insurance payout: {viable['prob_insurance_payout'].mean()*100:.1f}%")
    print(f"  Mean insurance payout NPV: ${viable['mean_insurance_payout_npv'].mean():,.0f}")

    # Best scenarios
    print(f"\n{'='*80}")
    print(f"TOP 10 SCENARIOS BY XIRR")
    print(f"{'='*80}")
    top10 = viable.nlargest(10, 'xirr')[['loan_type', 'house_value', 'loan_duration',
                                          'annuity_duration', 'xirr', 'mean_cagr',
                                          'prob_insurance_payout']]
    for idx, row in top10.iterrows():
        print(f"\n{row['loan_type']}, HV=${row['house_value']:,.0f}, "
              f"LD={int(row['loan_duration'])}y, AD={int(row['annuity_duration'])}y")
        print(f"  XIRR: {row['xirr']*100:.2f}%, CAGR: {row['mean_cagr']*100:.2f}%, "
              f"Insurance Risk: {row['prob_insurance_payout']*100:.1f}%")

    # Loan type comparison
    print(f"\n{'='*80}")
    print(f"LOAN TYPE COMPARISON")
    print(f"{'='*80}")
    for loan_type in df['loan_type'].unique():
        lt_viable = viable[viable['loan_type'] == loan_type]
        lt_total = df[df['loan_type'] == loan_type]
        print(f"\n{loan_type}:")
        print(f"  Viable: {len(lt_viable):,} / {len(lt_total):,} ({len(lt_viable)/len(lt_total)*100:.1f}%)")
        if len(lt_viable) > 0:
            print(f"  Mean XIRR: {lt_viable['xirr'].mean()*100:.2f}%")
            print(f"  Mean CAGR: {lt_viable['mean_cagr'].mean()*100:.2f}%")
            print(f"  Mean Insurance Risk: {lt_viable['prob_insurance_payout'].mean()*100:.1f}%")

    # Loan duration analysis
    print(f"\n{'='*80}")
    print(f"LOAN DURATION ANALYSIS")
    print(f"{'='*80}")
    for duration in sorted(df['loan_duration'].unique()):
        dur_viable = viable[viable['loan_duration'] == duration]
        dur_total = df[df['loan_duration'] == duration]
        print(f"\n{int(duration)} years:")
        print(f"  Viable: {len(dur_viable):,} / {len(dur_total):,} ({len(dur_viable)/len(dur_total)*100:.1f}%)")
        if len(dur_viable) > 0:
            print(f"  Mean XIRR: {dur_viable['xirr'].mean()*100:.2f}%")
            print(f"  Mean Insurance Risk: {dur_viable['prob_insurance_payout'].mean()*100:.1f}%")

else:
    print("\n⚠️  No viable scenarios found (all XIRR ≤ 0 or null)")

# Performance statistics
print(f"\n{'='*80}")
print(f"PERFORMANCE STATISTICS")
print(f"{'='*80}")
print(f"Simulation time per scenario:")
print(f"  Mean:   {df['simulation_time_sec'].mean():.2f}s")
print(f"  Median: {df['simulation_time_sec'].median():.2f}s")
print(f"  Min:    {df['simulation_time_sec'].min():.2f}s")
print(f"  Max:    {df['simulation_time_sec'].max():.2f}s")

total_time_hours = df['simulation_time_sec'].sum() / 3600
print(f"\nTotal simulation time: {total_time_hours:.2f} hours")
print(f"Paths per scenario: 100,000")
print(f"Total paths simulated: {len(df) * 100_000:,}")

print("\n" + "=" * 80)
