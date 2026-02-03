import pandas as pd
import numpy as np

# Read the results
df = pd.read_csv('profitability_results.csv')

print("="*80)
print("EQUITY PRESERVATION MORTGAGE - PROFITABILITY ANALYSIS")
print("="*80)
print(f"\nScenarios analyzed: {len(df)}")
print(f"House values: ${df['house_value'].min():,.0f} to ${df['house_value'].max():,.0f}")
print(f"Loan durations: {df['loan_duration'].min()}-{df['loan_duration'].max()} years")
print(f"Annuity durations: {df['annuity_duration'].min()}-{df['annuity_duration'].max()} years")

# Check if loan_type column exists
if 'loan_type' in df.columns:
    print(f"Loan types: {', '.join(df['loan_type'].unique())}")
    print(f"  Interest Only: {(df['loan_type'] == 'Interest Only').sum()} scenarios")
    print(f"  Principal+Interest: {(df['loan_type'] == 'Principal+Interest').sum()} scenarios")

print("\n" + "="*80)
print("KEY QUESTION: WILL FUNDERS MAKE MONEY?")
print("="*80)

# Filter out NaN XIRRs for analysis
df_valid = df[df['xirr'].notna()].copy()

print(f"\nValid XIRR scenarios: {len(df_valid)} / {len(df)} ({100*len(df_valid)/len(df):.1f}%)")

# XIRR Analysis (Internal Rate of Return - the gold standard)
print("\n" + "-"*80)
print("FUNDER RETURNS (XIRR - Internal Rate of Return)")
print("-"*80)
print(f"Mean XIRR: {df_valid['xirr'].mean():.2%}")
print(f"Median XIRR: {df_valid['xirr'].median():.2%}")
print(f"Min XIRR: {df_valid['xirr'].min():.2%}")
print(f"Max XIRR: {df_valid['xirr'].max():.2%}")
print(f"Std Dev: {df_valid['xirr'].std():.2%}")

print("\nXIRR Distribution:")
print(f"  < 0% (losing money): {(df_valid['xirr'] < 0).sum()} scenarios ({100*(df_valid['xirr'] < 0).mean():.1f}%)")
print(f"  0-1%: {((df_valid['xirr'] >= 0) & (df_valid['xirr'] < 0.01)).sum()} scenarios ({100*((df_valid['xirr'] >= 0) & (df_valid['xirr'] < 0.01)).mean():.1f}%)")
print(f"  1-2%: {((df_valid['xirr'] >= 0.01) & (df_valid['xirr'] < 0.02)).sum()} scenarios ({100*((df_valid['xirr'] >= 0.01) & (df_valid['xirr'] < 0.02)).mean():.1f}%)")
print(f"  2-3%: {((df_valid['xirr'] >= 0.02) & (df_valid['xirr'] < 0.03)).sum()} scenarios ({100*((df_valid['xirr'] >= 0.02) & (df_valid['xirr'] < 0.03)).mean():.1f}%)")
print(f"  3-4%: {((df_valid['xirr'] >= 0.03) & (df_valid['xirr'] < 0.04)).sum()} scenarios ({100*((df_valid['xirr'] >= 0.03) & (df_valid['xirr'] < 0.04)).mean():.1f}%)")
print(f"  4-5%: {((df_valid['xirr'] >= 0.04) & (df_valid['xirr'] < 0.05)).sum()} scenarios ({100*((df_valid['xirr'] >= 0.04) & (df_valid['xirr'] < 0.05)).mean():.1f}%)")
print(f"  5%+: {(df_valid['xirr'] >= 0.05).sum()} scenarios ({100*(df_valid['xirr'] >= 0.05).mean():.1f}%)")

# Compare to risk-free rate
RISK_FREE_RATE = 0.04  # 4% cash rate in the model
print(f"\nCompared to risk-free rate ({RISK_FREE_RATE:.1%}):")
print(f"  Above risk-free rate: {(df_valid['xirr'] > RISK_FREE_RATE).sum()} scenarios ({100*(df_valid['xirr'] > RISK_FREE_RATE).mean():.1f}%)")
print(f"  Below risk-free rate: {(df_valid['xirr'] <= RISK_FREE_RATE).sum()} scenarios ({100*(df_valid['xirr'] <= RISK_FREE_RATE).mean():.1f}%)")

# CAGR Analysis
print("\n" + "-"*80)
print("FUNDER RETURNS (CAGR - Compound Annual Growth Rate)")
print("-"*80)
print(f"Mean CAGR: {df['mean_cagr'].mean():.2%}")
print(f"Median CAGR: {df['mean_cagr'].median():.2%}")
print(f"Min CAGR: {df['mean_cagr'].min():.2%}")
print(f"Max CAGR: {df['mean_cagr'].max():.2%}")

# Insurance Risk
print("\n" + "-"*80)
print("INSURANCE RISK (Probability of Insurance Payout Required)")
print("-"*80)
print(f"Mean probability: {df['prob_insurance_payout'].mean():.1%}")
print(f"Median probability: {df['prob_insurance_payout'].median():.1%}")
print(f"\nScenarios by insurance risk:")
print(f"  < 20% risk: {(df['prob_insurance_payout'] < 0.2).sum()} scenarios ({100*(df['prob_insurance_payout'] < 0.2).mean():.1f}%)")
print(f"  20-40% risk: {((df['prob_insurance_payout'] >= 0.2) & (df['prob_insurance_payout'] < 0.4)).sum()} scenarios ({100*((df['prob_insurance_payout'] >= 0.2) & (df['prob_insurance_payout'] < 0.4)).mean():.1f}%)")
print(f"  40-60% risk: {((df['prob_insurance_payout'] >= 0.4) & (df['prob_insurance_payout'] < 0.6)).sum()} scenarios ({100*((df['prob_insurance_payout'] >= 0.4) & (df['prob_insurance_payout'] < 0.6)).mean():.1f}%)")
print(f"  60-80% risk: {((df['prob_insurance_payout'] >= 0.6) & (df['prob_insurance_payout'] < 0.8)).sum()} scenarios ({100*((df['prob_insurance_payout'] >= 0.6) & (df['prob_insurance_payout'] < 0.8)).mean():.1f}%)")
print(f"  80-100% risk: {(df['prob_insurance_payout'] >= 0.8).sum()} scenarios ({100*(df['prob_insurance_payout'] >= 0.8).mean():.1f}%)")

# Payment Holidays
print("\n" + "-"*80)
print("OPERATIONAL METRICS (Payment Holidays)")
print("-"*80)
print(f"Mean % of quarters on holiday: {df['pct_quarters_holiday'].mean():.1%}")
print(f"Median % of quarters on holiday: {df['pct_quarters_holiday'].median():.1%}")

# Best and Worst Scenarios
print("\n" + "="*80)
print("BEST SCENARIOS (Highest XIRR)")
print("="*80)
best = df_valid.nlargest(5, 'xirr')[['house_value', 'loan_duration', 'annuity_duration', 'xirr', 'mean_cagr', 'prob_insurance_payout']]
print(best.to_string(index=False))

print("\n" + "="*80)
print("WORST SCENARIOS (Lowest XIRR)")
print("="*80)
worst = df_valid.nsmallest(5, 'xirr')[['house_value', 'loan_duration', 'annuity_duration', 'xirr', 'mean_cagr', 'prob_insurance_payout']]
print(worst.to_string(index=False))

# Pattern Analysis
print("\n" + "="*80)
print("PATTERN ANALYSIS")
print("="*80)

print("\nXIRR by Loan Duration:")
for ld in sorted(df_valid['loan_duration'].unique()):
    subset = df_valid[df_valid['loan_duration'] == ld]
    print(f"  {ld} years: Mean XIRR = {subset['xirr'].mean():.2%}, Median = {subset['xirr'].median():.2%}, N = {len(subset)}")

print("\nXIRR by Annuity Duration:")
for ad in sorted(df_valid['annuity_duration'].unique()):
    subset = df_valid[df_valid['annuity_duration'] == ad]
    print(f"  {ad} years: Mean XIRR = {subset['xirr'].mean():.2%}, Median = {subset['xirr'].median():.2%}, N = {len(subset)}")

print("\nXIRR by House Value Tier:")
df_valid['value_tier'] = pd.cut(df_valid['house_value'], bins=[0, 2e6, 4e6, 6e6, 8e6, 1e7],
                                 labels=['$1-2M', '$2-4M', '$4-6M', '$6-8M', '$8-10M'])
for tier in df_valid['value_tier'].cat.categories:
    subset = df_valid[df_valid['value_tier'] == tier]
    if len(subset) > 0:
        print(f"  {tier}: Mean XIRR = {subset['xirr'].mean():.2%}, Median = {subset['xirr'].median():.2%}, N = {len(subset)}")

# Final Verdict
print("\n" + "="*80)
print("COMPARISON BY LOAN TYPE")
print("="*80)

if 'loan_type' in df.columns and len(df['loan_type'].unique()) > 1:
    for loan_type in sorted(df['loan_type'].unique()):
        df_lt = df_valid[df_valid['loan_type'] == loan_type]
        if len(df_lt) > 0:
            print(f"\n{loan_type}:")
            print(f"  Scenarios: {len(df_lt)}")
            print(f"  Mean XIRR: {df_lt['xirr'].mean():.2%}")
            print(f"  Median XIRR: {df_lt['xirr'].median():.2%}")
            print(f"  Mean CAGR: {df_lt['mean_cagr'].mean():.2%}")
            print(f"  Beats Risk-Free Rate: {(df_lt['xirr'] > RISK_FREE_RATE).mean():.1%}")
            print(f"  Mean Insurance Risk: {df[df['loan_type'] == loan_type]['prob_insurance_payout'].mean():.1%}")
            print(f"  Mean % Quarters on Holiday: {df[df['loan_type'] == loan_type]['pct_quarters_holiday'].mean():.1%}")

print("\n" + "="*80)
print("VERDICT: IS THIS A GOOD PRODUCT FOR FUNDERS?")
print("="*80)

avg_xirr = df_valid['xirr'].mean()
pct_positive = (df_valid['xirr'] > 0).mean() * 100
pct_above_risk_free = (df_valid['xirr'] > RISK_FREE_RATE).mean() * 100
avg_insurance_risk = df['prob_insurance_payout'].mean() * 100

print(f"\n📊 Average Return (XIRR): {avg_xirr:.2%}")
print(f"✅ Positive Returns: {pct_positive:.1f}% of scenarios")
print(f"📈 Beats Risk-Free Rate (4%): {pct_above_risk_free:.1f}% of scenarios")
print(f"⚠️  Average Insurance Risk: {avg_insurance_risk:.1f}%")

print("\n🔍 ASSESSMENT:")
if avg_xirr > 0.02 and pct_above_risk_free > 50:
    print("✅ POTENTIALLY VIABLE - Funders make positive returns in most scenarios")
    print("   However, returns are modest relative to risk-free alternatives.")
elif avg_xirr > 0 and pct_positive > 70:
    print("⚠️  MARGINAL - Funders generally make money, but returns are low")
    print("   May not adequately compensate for complexity and insurance risk.")
else:
    print("❌ CONCERNING - Returns are too low or inconsistent")
    print("   Product needs restructuring to be attractive to funders.")

print("\n💡 KEY INSIGHTS:")
if df_valid['xirr'].std() > 0.02:
    print("• High variability in returns - some scenarios much better than others")
if avg_insurance_risk > 50:
    print("• Insurance required in majority of scenarios - significant risk factor")
if df['pct_quarters_holiday'].mean() > 0.5:
    print("• Borrowers spend significant time in payment holidays - cashflow concern")

print("\n" + "="*80)
