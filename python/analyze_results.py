#!/usr/bin/env python3
"""
Analysis script for profitability sweep results
"""

import pandas as pd
import numpy as np

def main():
    print("=" * 80)
    print("ANALYZING PROFITABILITY RESULTS")
    print("=" * 80)

    # Load results
    df = pd.read_csv('profitability_results.csv')

    print(f"\n✅ Loaded {len(df):,} scenarios")
    print(f"   Monte Carlo paths per scenario: 100")
    print(f"   Total simulations: {len(df) * 100:,}")

    # Overall statistics
    print("\n" + "=" * 80)
    print("OVERALL PERFORMANCE")
    print("=" * 80)

    valid_xirr = df[df['xirr'].notna()]
    print(f"\nScenarios with valid XIRR: {len(valid_xirr):,} / {len(df):,} ({len(valid_xirr)/len(df)*100:.1f}%)")
    print(f"Scenarios with positive XIRR: {(df['xirr'] > 0).sum():,} ({(df['xirr'] > 0).sum() / len(df) * 100:.1f}%)")
    print(f"Scenarios with XIRR ≥ 4%: {(df['xirr'] >= 0.04).sum():,} ({(df['xirr'] >= 0.04).sum() / len(df) * 100:.1f}%)")

    # XIRR statistics
    print("\n" + "=" * 80)
    print("XIRR STATISTICS")
    print("=" * 80)
    print(f"Mean:   {valid_xirr['xirr'].mean() * 100:6.2f}%")
    print(f"Median: {valid_xirr['xirr'].median() * 100:6.2f}%")
    print(f"StdDev: {valid_xirr['xirr'].std() * 100:6.2f}%")
    print(f"Min:    {valid_xirr['xirr'].min() * 100:6.2f}%")
    print(f"Max:    {valid_xirr['xirr'].max() * 100:6.2f}%")

    # CAGR statistics
    print("\n" + "=" * 80)
    print("CAGR STATISTICS")
    print("=" * 80)
    print(f"Mean:   {df['mean_cagr'].mean() * 100:6.2f}%")
    print(f"Median: {df['mean_cagr'].median() * 100:6.2f}%")
    print(f"StdDev: {df['mean_cagr'].std() * 100:6.2f}%")
    print(f"Min:    {df['mean_cagr'].min() * 100:6.2f}%")
    print(f"Max:    {df['mean_cagr'].max() * 100:6.2f}%")

    # Insurance statistics
    print("\n" + "=" * 80)
    print("INSURANCE RISK STATISTICS")
    print("=" * 80)
    print(f"Mean probability:   {df['prob_insurance_payout'].mean() * 100:6.2f}%")
    print(f"Median probability: {df['prob_insurance_payout'].median() * 100:6.2f}%")
    print(f"\nScenarios with insurance risk:")
    print(f"  < 5%:  {(df['prob_insurance_payout'] < 0.05).sum():4,} ({(df['prob_insurance_payout'] < 0.05).sum() / len(df) * 100:5.1f}%)")
    print(f"  < 10%: {(df['prob_insurance_payout'] < 0.10).sum():4,} ({(df['prob_insurance_payout'] < 0.10).sum() / len(df) * 100:5.1f}%)")
    print(f"  < 15%: {(df['prob_insurance_payout'] < 0.15).sum():4,} ({(df['prob_insurance_payout'] < 0.15).sum() / len(df) * 100:5.1f}%)")
    print(f"  < 20%: {(df['prob_insurance_payout'] < 0.20).sum():4,} ({(df['prob_insurance_payout'] < 0.20).sum() / len(df) * 100:5.1f}%)")

    # Viability analysis
    print("\n" + "=" * 80)
    print("VIABILITY ANALYSIS")
    print("=" * 80)

    # Define viability criteria
    viable_cagr_8 = df[(df['mean_cagr'] >= 0.08) & (df['prob_insurance_payout'] < 0.20)]
    viable_cagr_10 = df[(df['mean_cagr'] >= 0.10) & (df['prob_insurance_payout'] < 0.15)]

    print(f"\nCAGR ≥ 8% AND Insurance < 20%:")
    print(f"  Count: {len(viable_cagr_8):,} ({len(viable_cagr_8)/len(df)*100:.1f}%)")
    if len(viable_cagr_8) > 0:
        print(f"  Mean CAGR: {viable_cagr_8['mean_cagr'].mean() * 100:.2f}%")
        print(f"  Mean Insurance: {viable_cagr_8['prob_insurance_payout'].mean() * 100:.2f}%")

    print(f"\nCAGR ≥ 10% AND Insurance < 15%:")
    print(f"  Count: {len(viable_cagr_10):,} ({len(viable_cagr_10)/len(df)*100:.1f}%)")
    if len(viable_cagr_10) > 0:
        print(f"  Mean CAGR: {viable_cagr_10['mean_cagr'].mean() * 100:.2f}%")
        print(f"  Mean Insurance: {viable_cagr_10['prob_insurance_payout'].mean() * 100:.2f}%")

    # Top scenarios
    print("\n" + "=" * 80)
    print("TOP 10 SCENARIOS BY CAGR (Insurance < 15%)")
    print("=" * 80)

    good_scenarios = df[df['prob_insurance_payout'] < 0.15]
    top10_cagr = good_scenarios.nlargest(10, 'mean_cagr')

    for idx, row in top10_cagr.iterrows():
        xirr_str = f"{row['xirr']*100:5.2f}%" if pd.notna(row['xirr']) else "  N/A"
        print(f"\n{row['loan_type']:<22} | HV=${row['house_value']/1e6:4.1f}M | "
              f"LD={row['loan_duration']:2.0f}y | AD={row['annuity_duration']:2.0f}y")
        print(f"  XIRR: {xirr_str} | CAGR: {row['mean_cagr']*100:5.2f}% | "
              f"Insurance: {row['prob_insurance_payout']*100:5.2f}%")

    # Analysis by loan type
    print("\n" + "=" * 80)
    print("PERFORMANCE BY LOAN TYPE")
    print("=" * 80)

    for loan_type in df['loan_type'].unique():
        subset = df[df['loan_type'] == loan_type]
        valid_subset = subset[subset['xirr'].notna()]

        print(f"\n{loan_type}:")
        print(f"  Scenarios: {len(subset):,}")
        print(f"  Mean XIRR: {valid_subset['xirr'].mean() * 100:6.2f}%")
        print(f"  Mean CAGR: {subset['mean_cagr'].mean() * 100:6.2f}%")
        print(f"  Mean Insurance: {subset['prob_insurance_payout'].mean() * 100:6.2f}%")
        print(f"  Viable (CAGR≥8%, Ins<20%): {len(subset[(subset['mean_cagr'] >= 0.08) & (subset['prob_insurance_payout'] < 0.20)]):,}")

    # Analysis by house value ranges
    print("\n" + "=" * 80)
    print("PERFORMANCE BY HOUSE VALUE RANGE")
    print("=" * 80)

    ranges = [
        (1_000_000, 2_000_000, "$1M-$2M"),
        (2_000_000, 3_000_000, "$2M-$3M"),
        (3_000_000, 5_000_000, "$3M-$5M"),
        (5_000_000, 7_000_000, "$5M-$7M"),
        (7_000_000, 10_100_000, "$7M-$10M")
    ]

    for min_val, max_val, label in ranges:
        subset = df[(df['house_value'] >= min_val) & (df['house_value'] < max_val)]
        if len(subset) > 0:
            valid_subset = subset[subset['xirr'].notna()]
            print(f"\n{label}:")
            print(f"  Scenarios: {len(subset):,}")
            print(f"  Mean CAGR: {subset['mean_cagr'].mean() * 100:6.2f}%")
            print(f"  Mean Insurance: {subset['prob_insurance_payout'].mean() * 100:6.2f}%")
            print(f"  Viable (CAGR≥8%, Ins<20%): {len(subset[(subset['mean_cagr'] >= 0.08) & (subset['prob_insurance_payout'] < 0.20)]):,}")

    # Save summary statistics
    summary_file = 'profitability_summary.txt'
    with open(summary_file, 'w') as f:
        f.write("EQUITY PRESERVATION MORTGAGE - PROFITABILITY SUMMARY\n")
        f.write("=" * 80 + "\n\n")
        f.write(f"Total scenarios: {len(df):,}\n")
        f.write(f"Monte Carlo paths: 100 per scenario\n")
        f.write(f"Mean CAGR: {df['mean_cagr'].mean() * 100:.2f}%\n")
        f.write(f"Mean XIRR: {valid_xirr['xirr'].mean() * 100:.2f}%\n")
        f.write(f"Mean Insurance Risk: {df['prob_insurance_payout'].mean() * 100:.2f}%\n")
        f.write(f"\nViable scenarios (CAGR≥8%, Insurance<20%): {len(viable_cagr_8):,} ({len(viable_cagr_8)/len(df)*100:.1f}%)\n")

    print(f"\n✅ Summary saved to: {summary_file}")
    print("=" * 80)

if __name__ == "__main__":
    main()
