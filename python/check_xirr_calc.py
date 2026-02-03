"""
Quick test to verify XIRR calculation makes sense
"""
import pandas as pd
import numpy as np

# Read first few rows
df = pd.read_csv('profitability_results.csv')

print("="*80)
print("XIRR CALCULATION REVIEW")
print("="*80)

# Pick an example scenario to analyze
example = df[(df['house_value'] == 1_000_000) &
             (df['loan_duration'] == 10) &
             (df['annuity_duration'] == 10) &
             (df['loan_type'] == 'Interest Only')].iloc[0]

print("\n📋 Example Scenario:")
print(f"  House Value: ${example['house_value']:,.0f}")
print(f"  Loan Type: {example['loan_type']}")
print(f"  Loan Duration: {example['loan_duration']} years")
print(f"  Annuity Duration: {example['annuity_duration']} years")
print(f"  Loan Amount: ${example['loan_amount']:,.0f}")
print(f"  Reinvest Fraction: {example['reinvest_fraction']:.2%}")

print("\n📊 Results:")
print(f"  Mean Reinvestment: ${example['mean_reinvestment']:,.0f}")
print(f"  Mean Deficit: ${example['mean_deficit']:,.0f}")
print(f"  Mean Funder Earned: ${example['mean_funder_earned']:,.0f}")
print(f"  Mean Funder Profit Share: ${example['mean_funder_profit_share']:,.0f}")
print(f"  Mean Net Position: ${example['mean_net_position']:,.0f}")

print("\n💰 Returns:")
print(f"  XIRR: {example['xirr']:.2%}")
print(f"  CAGR: {example['mean_cagr']:.2%}")

print("\n⚠️  Risk Metrics:")
print(f"  Prob Insurance Payout: {example['prob_insurance_payout']:.1%}")
print(f"  % Quarters on Holiday: {example['pct_quarters_holiday']:.1%}")

# Basic sanity check
loan_amount = example['loan_amount']
initial_outlay = loan_amount * example['reinvest_fraction'] + 30000/4
final_recovery = example['mean_net_position']
years = example['loan_duration']

simple_return = (final_recovery - initial_outlay) / initial_outlay
annualized = pow(1 + simple_return, 1/years) - 1

print("\n🔍 SANITY CHECK:")
print(f"  Initial Outlay (approx): ${initial_outlay:,.0f}")
print(f"  Final Recovery: ${final_recovery:,.0f}")
print(f"  Simple Return: {simple_return:.2%}")
print(f"  Annualized (simple): {annualized:.2%}")
print(f"  XIRR (actual): {example['xirr']:.2%}")

if abs(example['xirr']) < 0.001:
    print("\n⚠️  WARNING: XIRR near zero suggests potential calculation issue")

print("\n" + "="*80)
print("COMPARISON: Interest Only vs Principal+Interest (same scenario)")
print("="*80)

pi_example = df[(df['house_value'] == 1_000_000) &
                (df['loan_duration'] == 10) &
                (df['annuity_duration'] == 10) &
                (df['loan_type'] == 'Principal+Interest')].iloc[0]

print("\nInterest Only:")
print(f"  XIRR: {example['xirr']:.4f} ({example['xirr']:.2%})")
print(f"  CAGR: {example['mean_cagr']:.4f} ({example['mean_cagr']:.2%})")
print(f"  Funder Earned: ${example['mean_funder_earned']:,.0f}")
print(f"  Insurance Risk: {example['prob_insurance_payout']:.1%}")

print("\nPrincipal+Interest:")
print(f"  XIRR: {pi_example['xirr']:.4f} ({pi_example['xirr']:.2%})")
print(f"  CAGR: {pi_example['mean_cagr']:.4f} ({pi_example['mean_cagr']:.2%})")
print(f"  Funder Earned: ${pi_example['mean_funder_earned']:,.0f}")
print(f"  Insurance Risk: {pi_example['prob_insurance_payout']:.1%}")

print("\n🤔 Does this make sense?")
print(f"  IO has higher funder earnings? {example['mean_funder_earned'] > pi_example['mean_funder_earned']}")
print(f"  IO has higher XIRR? {example['xirr'] > pi_example['xirr']}")
print(f"  IO has lower insurance risk? {example['prob_insurance_payout'] < pi_example['prob_insurance_payout']}")
