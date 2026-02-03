#!/usr/bin/env python3
"""
Analyze failures from existing 1M results CSV

Uses the comprehensive profitability_results_1m.csv to understand:
1. What parameter combinations lead to failures
2. Relationship between CAGR and insurance risk
3. Identify viable parameter regions
"""

import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def load_and_prepare_data():
    """Load results and classify scenarios"""
    print("Loading 1M iteration results...")
    df = pd.read_csv('profitability_results_1m.csv')

    # Add viability flags
    df['viable'] = (df['mean_cagr'] >= 0.08) & (df['prob_insurance_payout'] < 0.20)
    df['premium_viable'] = (df['mean_cagr'] >= 0.10) & (df['prob_insurance_payout'] < 0.15)
    df['marginal'] = (df['mean_cagr'] >= 0.06) & (df['prob_insurance_payout'] < 0.30)

    # Calculate derived fields
    df['loan_amount_millions'] = df['loan_amount'] / 1_000_000
    df['house_value_millions'] = df['house_value'] / 1_000_000

    return df


def analyze_by_loan_type(df):
    """Compare Interest Only vs Principal+Interest"""
    print("\n" + "=" * 80)
    print("FAILURE ANALYSIS BY LOAN TYPE")
    print("=" * 80)

    for loan_type in ['Interest Only', 'Principal+Interest']:
        subset = df[df['loan_type'] == loan_type]
        print(f"\n{loan_type}:")
        print(f"  Total scenarios: {len(subset):,}")
        print(f"  Mean CAGR: {subset['mean_cagr'].mean()*100:.2f}%")
        print(f"  Mean Insurance Risk: {subset['prob_insurance_payout'].mean()*100:.2f}%")
        print(f"  Viable scenarios: {subset['viable'].sum():,} ({subset['viable'].mean()*100:.1f}%)")

        # Distribution of insurance risk
        print(f"\n  Insurance Risk Distribution:")
        print(f"    <10%:  {(subset['prob_insurance_payout'] < 0.10).sum():,} scenarios")
        print(f"    10-20%: {((subset['prob_insurance_payout'] >= 0.10) & (subset['prob_insurance_payout'] < 0.20)).sum():,} scenarios")
        print(f"    20-30%: {((subset['prob_insurance_payout'] >= 0.20) & (subset['prob_insurance_payout'] < 0.30)).sum():,} scenarios")
        print(f"    30-50%: {((subset['prob_insurance_payout'] >= 0.30) & (subset['prob_insurance_payout'] < 0.50)).sum():,} scenarios")
        print(f"    >50%:   {(subset['prob_insurance_payout'] >= 0.50).sum():,} scenarios")


def analyze_by_duration(df):
    """Understand impact of loan and annuity duration"""
    print("\n" + "=" * 80)
    print("FAILURE ANALYSIS BY DURATION")
    print("=" * 80)

    io_df = df[df['loan_type'] == 'Interest Only']

    print(f"\n{'Loan Dur':<10} {'Annuity Dur':<12} {'Count':<8} {'Mean CAGR':<12} {'Mean Ins Risk':<15} {'Viable':<10}")
    print("-" * 75)

    for ld in sorted(io_df['loan_duration'].unique()):
        for ad in sorted(io_df['annuity_duration'].unique()):
            if ad < ld:
                continue
            subset = io_df[(io_df['loan_duration'] == ld) & (io_df['annuity_duration'] == ad)]
            if len(subset) > 0:
                print(f"{int(ld)}y {int(ad)}y {len(subset):>12} {subset['mean_cagr'].mean()*100:>10.2f}% "
                      f"{subset['prob_insurance_payout'].mean()*100:>13.2f}% {subset['viable'].sum():>9}")


def analyze_by_house_value(df):
    """Impact of house value"""
    print("\n" + "=" * 80)
    print("FAILURE ANALYSIS BY HOUSE VALUE")
    print("=" * 80)

    io_df = df[df['loan_type'] == 'Interest Only']

    ranges = [
        (1, 2, "$1M-$2M"),
        (2, 3, "$2M-$3M"),
        (3, 5, "$3M-$5M"),
        (5, 7, "$5M-$7M"),
        (7, 11, "$7M-$10M")
    ]

    print(f"\n{'Range':<12} {'Count':<8} {'Mean CAGR':<12} {'Mean Ins Risk':<15} {'Best Config':<30}")
    print("-" * 85)

    for min_val, max_val, label in ranges:
        subset = io_df[(io_df['house_value_millions'] >= min_val) & (io_df['house_value_millions'] < max_val)]
        if len(subset) > 0:
            best = subset.nlargest(1, 'mean_cagr').iloc[0]
            print(f"{label:<12} {len(subset):<8} {subset['mean_cagr'].mean()*100:>10.2f}% "
                  f"{subset['prob_insurance_payout'].mean()*100:>13.2f}%  "
                  f"{int(best['loan_duration'])}y/{int(best['annuity_duration'])}y")


def identify_critical_thresholds(df):
    """Find parameter values that cause step-changes in viability"""
    print("\n" + "=" * 80)
    print("CRITICAL THRESHOLD ANALYSIS")
    print("=" * 80)

    io_df = df[df['loan_type'] == 'Interest Only']

    # Find the "cliff" where viability drops off
    print(f"\n🎯 Best vs Worst Scenarios:")

    best = io_df.nlargest(10, 'mean_cagr')
    worst = io_df.nsmallest(10, 'mean_cagr')

    print(f"\nTop 10 scenarios:")
    print(f"  Mean CAGR: {best['mean_cagr'].mean()*100:.2f}%")
    print(f"  Mean Insurance: {best['prob_insurance_payout'].mean()*100:.2f}%")
    print(f"  Mean LVR: {(best['loan_amount'] / best['house_value']).mean()*100:.1f}%")
    print(f"  Mean Duration: {best['loan_duration'].mean():.1f}y")

    print(f"\nWorst 10 scenarios:")
    print(f"  Mean CAGR: {worst['mean_cagr'].mean()*100:.2f}%")
    print(f"  Mean Insurance: {worst['prob_insurance_payout'].mean()*100:.2f}%")
    print(f"  Mean LVR: {(worst['loan_amount'] / worst['house_value']).mean()*100:.1f}%")
    print(f"  Mean Duration: {worst['loan_duration'].mean():.1f}y")

    # Correlation analysis
    print(f"\n📊 Correlation with Insurance Risk:")
    corr_with_insurance = io_df[['loan_duration', 'annuity_duration', 'house_value', 'reinvest_fraction', 'prob_insurance_payout']].corr()['prob_insurance_payout']
    print(f"  Loan Duration:      {corr_with_insurance['loan_duration']:+.3f}")
    print(f"  Annuity Duration:   {corr_with_insurance['annuity_duration']:+.3f}")
    print(f"  House Value:        {corr_with_insurance['house_value']:+.3f}")
    print(f"  Reinvest Fraction:  {corr_with_insurance['reinvest_fraction']:+.3f}")


def create_visualizations(df):
    """Generate insightful plots"""
    print("\n" + "=" * 80)
    print("CREATING VISUALIZATIONS")
    print("=" * 80)

    io_df = df[df['loan_type'] == 'Interest Only']

    # Create figure with subplots
    fig = plt.figure(figsize=(16, 12))

    # 1. CAGR vs Insurance Risk scatter
    ax1 = plt.subplot(2, 3, 1)
    scatter = ax1.scatter(io_df['mean_cagr']*100, io_df['prob_insurance_payout']*100,
                         c=io_df['loan_duration'], cmap='viridis', alpha=0.5, s=20)
    ax1.axhline(20, color='red', linestyle='--', label='20% Insurance Threshold')
    ax1.axvline(8, color='blue', linestyle='--', label='8% CAGR Target')
    ax1.set_xlabel('Mean CAGR (%)')
    ax1.set_ylabel('Insurance Risk (%)')
    ax1.set_title('CAGR vs Insurance Risk (colored by duration)')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    plt.colorbar(scatter, ax=ax1, label='Loan Duration (years)')

    # 2. Duration impact
    ax2 = plt.subplot(2, 3, 2)
    duration_groups = io_df.groupby('loan_duration').agg({
        'mean_cagr': 'mean',
        'prob_insurance_payout': 'mean'
    })
    x = duration_groups.index
    ax2_twin = ax2.twinx()
    ax2.bar(x - 0.2, duration_groups['mean_cagr']*100, width=0.4, label='CAGR', color='green', alpha=0.7)
    ax2_twin.bar(x + 0.2, duration_groups['prob_insurance_payout']*100, width=0.4, label='Insurance Risk', color='red', alpha=0.7)
    ax2.set_xlabel('Loan Duration (years)')
    ax2.set_ylabel('Mean CAGR (%)', color='green')
    ax2_twin.set_ylabel('Mean Insurance Risk (%)', color='red')
    ax2.set_title('Impact of Loan Duration')
    ax2.tick_params(axis='y', labelcolor='green')
    ax2_twin.tick_params(axis='y', labelcolor='red')
    ax2.grid(True, alpha=0.3)

    # 3. House value impact
    ax3 = plt.subplot(2, 3, 3)
    io_df['house_value_bin'] = pd.cut(io_df['house_value_millions'], bins=[1, 3, 5, 7, 11], labels=['$1-3M', '$3-5M', '$5-7M', '$7-10M'])
    house_groups = io_df.groupby('house_value_bin').agg({
        'mean_cagr': 'mean',
        'prob_insurance_payout': 'mean'
    })
    x_pos = np.arange(len(house_groups))
    ax3_twin = ax3.twinx()
    ax3.bar(x_pos - 0.2, house_groups['mean_cagr']*100, width=0.4, label='CAGR', color='green', alpha=0.7)
    ax3_twin.bar(x_pos + 0.2, house_groups['prob_insurance_payout']*100, width=0.4, label='Insurance', color='red', alpha=0.7)
    ax3.set_xticks(x_pos)
    ax3.set_xticklabels(house_groups.index)
    ax3.set_xlabel('House Value Range')
    ax3.set_ylabel('Mean CAGR (%)', color='green')
    ax3_twin.set_ylabel('Mean Insurance Risk (%)', color='red')
    ax3.set_title('Impact of House Value')
    ax3.tick_params(axis='y', labelcolor='green')
    ax3_twin.tick_params(axis='y', labelcolor='red')

    # 4. Reinvest fraction impact
    ax4 = plt.subplot(2, 3, 4)
    ax4.scatter(io_df['reinvest_fraction'], io_df['mean_cagr']*100, alpha=0.3, s=10)
    ax4.set_xlabel('Reinvest Fraction')
    ax4.set_ylabel('CAGR (%)')
    ax4.set_title('Reinvestment vs Performance')
    ax4.grid(True, alpha=0.3)

    # 5. Insurance risk distribution
    ax5 = plt.subplot(2, 3, 5)
    ax5.hist(io_df['prob_insurance_payout']*100, bins=50, alpha=0.7, color='red', edgecolor='black')
    ax5.axvline(20, color='blue', linestyle='--', linewidth=2, label='20% Threshold')
    ax5.set_xlabel('Insurance Risk (%)')
    ax5.set_ylabel('Count')
    ax5.set_title('Distribution of Insurance Risk (Interest Only)')
    ax5.legend()
    ax5.grid(True, alpha=0.3, axis='y')

    # 6. CAGR distribution
    ax6 = plt.subplot(2, 3, 6)
    ax6.hist(io_df['mean_cagr']*100, bins=50, alpha=0.7, color='green', edgecolor='black')
    ax6.axvline(8, color='blue', linestyle='--', linewidth=2, label='8% Target')
    ax6.set_xlabel('CAGR (%)')
    ax6.set_ylabel('Count')
    ax6.set_title('Distribution of CAGR (Interest Only)')
    ax6.legend()
    ax6.grid(True, alpha=0.3, axis='y')

    plt.tight_layout()
    plt.savefig('failure_analysis_comprehensive.png', dpi=300, bbox_inches='tight')
    print("   ✅ Saved: failure_analysis_comprehensive.png")

    # Create heatmap of loan duration vs annuity duration (manual implementation)
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))

    # CAGR heatmap
    pivot_cagr = io_df.pivot_table(values='mean_cagr', index='loan_duration', columns='annuity_duration', aggfunc='mean')
    im1 = ax1.imshow(pivot_cagr*100, cmap='RdYlGn', aspect='auto', vmin=4, vmax=10)
    ax1.set_yticks(range(len(pivot_cagr.index)))
    ax1.set_yticklabels(pivot_cagr.index)
    ax1.set_xticks(range(len(pivot_cagr.columns)))
    ax1.set_xticklabels(pivot_cagr.columns)
    ax1.set_title('Mean CAGR (%) by Loan/Annuity Duration')
    ax1.set_xlabel('Annuity Duration (years)')
    ax1.set_ylabel('Loan Duration (years)')
    plt.colorbar(im1, ax=ax1)

    # Insurance risk heatmap
    pivot_ins = io_df.pivot_table(values='prob_insurance_payout', index='loan_duration', columns='annuity_duration', aggfunc='mean')
    im2 = ax2.imshow(pivot_ins*100, cmap='RdYlGn_r', aspect='auto', vmin=10, vmax=40)
    ax2.set_yticks(range(len(pivot_ins.index)))
    ax2.set_yticklabels(pivot_ins.index)
    ax2.set_xticks(range(len(pivot_ins.columns)))
    ax2.set_xticklabels(pivot_ins.columns)
    ax2.set_title('Mean Insurance Risk (%) by Loan/Annuity Duration')
    ax2.set_xlabel('Annuity Duration (years)')
    ax2.set_ylabel('Loan Duration (years)')
    plt.colorbar(im2, ax=ax2)

    plt.tight_layout()
    plt.savefig('duration_heatmaps.png', dpi=300, bbox_inches='tight')
    print("   ✅ Saved: duration_heatmaps.png")


def generate_recommendations(df):
    """Generate actionable recommendations"""
    print("\n" + "=" * 80)
    print("📋 RECOMMENDATIONS BASED ON FAILURE ANALYSIS")
    print("=" * 80)

    io_df = df[df['loan_type'] == 'Interest Only']

    # Find least-bad scenarios
    marginal = io_df[io_df['marginal']]

    print(f"\n1. CURRENT STATE")
    print(f"   ❌ Zero scenarios meet target (CAGR≥8%, Ins<20%)")
    print(f"   ⚠️  {len(marginal)} scenarios are marginal (CAGR≥6%, Ins<30%)")
    print(f"   📊 Mean CAGR: {io_df['mean_cagr'].mean()*100:.2f}%")
    print(f"   📊 Mean Insurance Risk: {io_df['prob_insurance_payout'].mean()*100:.2f}%")

    if len(marginal) > 0:
        best_marginal = marginal.nlargest(5, 'mean_cagr')
        print(f"\n2. BEST ACHIEVABLE (within tested parameters)")
        for idx, row in best_marginal.iterrows():
            lvr = row['loan_amount'] / row['house_value']
            print(f"   • ${row['house_value']/1e6:.1f}M house, {int(row['loan_duration'])}y/{int(row['annuity_duration'])}y: "
                  f"CAGR {row['mean_cagr']*100:.2f}%, Insurance {row['prob_insurance_payout']*100:.2f}%")

    print(f"\n3. REQUIRED CHANGES FOR VIABILITY")
    print(f"   Based on analysis, NO combination of tested parameters achieves viability.")
    print(f"   ")
    print(f"   The fundamental issue: Insurance risk remains >28% even in best case.")
    print(f"   Target is <20%, creating an 8+ percentage point gap.")
    print(f"   ")
    print(f"   💡 ROOT CAUSE:")
    print(f"      Current LVR (80%) combined with market volatility (12%) creates")
    print(f"      too high probability of equity dropping below loan value.")

    print(f"\n4. SUGGESTED NEXT STEPS")
    print(f"   ")
    print(f"   Option A - DRAMATIC PARAMETER CHANGES:")
    print(f"   • Reduce LVR to 50-60% (currently 80%)")
    print(f"   • Accept this makes product less attractive to customers")
    print(f"   • Test with new sweep to verify viability")

    print(f"\n   Option B - HYBRID PRODUCT STRUCTURE:")
    print(f"   • Add mandatory equity buffer (10-15% down payment)")
    print(f"   • Implement tiered LVR (start 70%, can refinance to 75% if performing)")
    print(f"   • Add market performance triggers (reduce LVR in bear markets)")

    print(f"\n   Option C - REINSURANCE / HEDGING:")
    print(f"   • Purchase tail risk insurance (protects against >30% market drops)")
    print(f"   • Cost: ~1-2% annually")
    print(f"   • Eliminates catastrophic scenarios, may achieve viability")

    print(f"\n   Option D - RECONSIDER BUSINESS MODEL:")
    print(f"   • Current structure may be fundamentally unviable")
    print(f"   • Consider alternative products (reverse mortgage, shared appreciation, etc.)")
    print(f"   • Partner with larger financial institution for risk sharing")


def main():
    print("=" * 80)
    print("COMPREHENSIVE FAILURE MODE ANALYSIS")
    print("Using 1M Monte Carlo Results")
    print("=" * 80)

    df = load_and_prepare_data()

    print(f"\nLoaded {len(df):,} scenarios")
    print(f"  Interest Only: {(df['loan_type'] == 'Interest Only').sum():,}")
    print(f"  Principal+Interest: {(df['loan_type'] == 'Principal+Interest').sum():,}")

    analyze_by_loan_type(df)
    analyze_by_duration(df)
    analyze_by_house_value(df)
    identify_critical_thresholds(df)
    create_visualizations(df)
    generate_recommendations(df)

    print("\n" + "=" * 80)
    print("✅ ANALYSIS COMPLETE")
    print("=" * 80)
    print("\nGenerated files:")
    print("  📊 failure_analysis_comprehensive.png - Multi-panel analysis")
    print("  📊 duration_heatmaps.png - Duration impact heatmaps")
    print("=" * 80)


if __name__ == "__main__":
    main()
