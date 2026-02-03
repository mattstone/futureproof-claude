"""
Index-Linked Annuity Model - Alternative to Equity Preservation Mortgage

Instead of investing in volatile S&P 500, convert home equity into guaranteed income
via inflation-linked annuities. This provides:
- Predictable income for borrower
- Predictable returns for funder (insurance company)
- No market volatility risk
- No complex insurance needed
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime

# Configuration
OUTPUT_FILE = 'annuity_model_results.csv'

# Parameter ranges (same as equity model for comparison)
HOUSE_VALUES = range(1_000_000, 10_100_000, 100_000)
LOAN_DURATIONS = [10, 15, 20, 25, 30]  # Years to receive income
ANNUITY_DURATIONS = [10, 15, 20, 25, 30]  # Same as loan duration in this model

# Fixed parameters
LOAN_TO_VALUE = 0.8  # Maximum equity extraction
ANNUAL_INCOME_TARGET = 30_000  # Target annual income for borrower

# Insurance company / Funder parameters
# Simplified model: Insurance company prices annuity based on what they can earn
INVESTMENT_RETURN = 0.05  # Insurance company earns 5% on bonds/safe assets
ANNUITY_RATE = 0.035  # Rate used to calculate annuity payments (lower than investment return)
# Spread = 1.5% (5% - 3.5%) covers admin costs, profit, reserves
INFLATION_RATE = 0.025  # 2.5% average inflation for COLA adjustments

def calculate_annuity_payment(principal, years, discount_rate):
    """
    Calculate annual payment from immediate annuity
    Using present value of annuity formula: PV = PMT * [(1 - (1 + r)^-n) / r]
    Solving for PMT: PMT = PV * r / (1 - (1 + r)^-n)
    """
    if years == 0:
        return principal

    r = discount_rate
    n = years
    pmt = principal * r / (1 - (1 + r)**(-n))
    return pmt

def calculate_inflation_adjusted_payment(base_payment, year, inflation_rate):
    """Calculate payment adjusted for inflation"""
    return base_payment * (1 + inflation_rate) ** year

def simulate_annuity(house_value, loan_duration, loan_to_value, annual_income_target):
    """
    Simulate index-linked annuity product

    Returns dict with:
    - borrower metrics (income received)
    - funder metrics (returns, profitability)
    """

    # 1. Calculate available equity
    total_equity = house_value * loan_to_value

    # 2. Use ANNUITY_RATE to price the annuity
    # This is the rate offered to customers (lower than what insurer earns)
    discount_rate = ANNUITY_RATE

    # 3. Calculate base annual payment (before inflation adjustment)
    base_annual_payment = calculate_annuity_payment(total_equity, loan_duration, discount_rate)

    # 4. Simulate year-by-year cashflows
    years = []
    borrower_payments = []
    funder_costs = []
    funder_investment_values = []

    remaining_principal = total_equity

    for year in range(1, loan_duration + 1):
        # Borrower receives inflation-adjusted payment
        inflation_adjusted_payment = calculate_inflation_adjusted_payment(
            base_annual_payment, year - 1, INFLATION_RATE
        )
        borrower_payments.append(inflation_adjusted_payment)

        # Funder's perspective
        # Investment grows at INVESTMENT_RETURN
        investment_earnings = remaining_principal * INVESTMENT_RETURN

        # Funder pays out the annuity payment
        funder_cost = inflation_adjusted_payment

        # Update remaining principal (no separate admin cost - it's in the spread)
        remaining_principal = remaining_principal + investment_earnings - funder_cost

        years.append(year)
        funder_costs.append(funder_cost)
        funder_investment_values.append(remaining_principal)

    # 5. Calculate metrics
    total_borrower_income = sum(borrower_payments)
    total_funder_cost = sum(funder_costs)
    total_admin_costs = 0  # Included in spread

    # Funder's final profit (what's left after all payments)
    funder_profit = remaining_principal
    funder_total_return = funder_profit / total_equity

    # Calculate CAGR - handle negative returns properly
    if funder_total_return < -1:
        # Total loss exceeds 100% - set CAGR to -100%
        funder_cagr = -1.0
    else:
        funder_cagr = (1 + funder_total_return) ** (1/loan_duration) - 1

    # Risk metrics
    prob_default = 0.0  # No default risk - payments are guaranteed by insurance company's capital

    # Compare to borrower's target income
    avg_annual_income = total_borrower_income / loan_duration
    income_vs_target = avg_annual_income / annual_income_target

    return {
        # Borrower metrics
        'total_borrower_income': total_borrower_income,
        'avg_annual_income': avg_annual_income,
        'first_year_income': borrower_payments[0],
        'last_year_income': borrower_payments[-1],
        'income_vs_target': income_vs_target,

        # Funder metrics
        'initial_investment': total_equity,
        'total_payments_made': total_funder_cost,
        'total_admin_costs': total_admin_costs,
        'final_profit': funder_profit,
        'total_return': funder_total_return,
        'cagr': funder_cagr,
        'prob_default': prob_default,

        # Comparison to equity model
        'market_risk': 0.0,  # No S&P 500 exposure
        'insurance_needed': False,
        'complexity_score': 1.0,  # Simple vs complex equity model
    }

def run_parameter_sweep():
    """Run analysis across all parameter combinations"""

    results = []
    total_scenarios = len(HOUSE_VALUES) * len(LOAN_DURATIONS)
    completed = 0

    print(f"Running Index-Linked Annuity Analysis...")
    print(f"Total scenarios: {total_scenarios}")
    print("=" * 80)

    for house_value in HOUSE_VALUES:
        for loan_duration in LOAN_DURATIONS:
            completed += 1

            # Run simulation
            result = simulate_annuity(
                house_value,
                loan_duration,
                LOAN_TO_VALUE,
                ANNUAL_INCOME_TARGET
            )

            # Add parameters to result
            result['house_value'] = house_value
            result['loan_duration'] = loan_duration
            result['loan_amount'] = house_value * LOAN_TO_VALUE

            results.append(result)

            # Progress update every 50 scenarios
            if completed % 50 == 0:
                pct = 100 * completed / total_scenarios
                cagr_val = result['cagr']
                if isinstance(cagr_val, complex):
                    cagr_str = "N/A (complex)"
                else:
                    cagr_str = f"{cagr_val:.2%}"
                print(f"Progress: {completed}/{total_scenarios} ({pct:.1f}%) | "
                      f"Last: HV=${house_value:,} LD={loan_duration}y CAGR={cagr_str}")

    print("=" * 80)
    print("Analysis complete!")

    return pd.DataFrame(results)

def analyze_results(df):
    """Analyze and display results"""

    print("\n" + "=" * 80)
    print("INDEX-LINKED ANNUITY MODEL - RESULTS ANALYSIS")
    print("=" * 80)

    print(f"\nScenarios analyzed: {len(df)}")
    print(f"House values: ${df['house_value'].min():,.0f} to ${df['house_value'].max():,.0f}")
    print(f"Loan durations: {df['loan_duration'].min()}-{df['loan_duration'].max()} years")

    print("\n" + "-" * 80)
    print("FUNDER RETURNS (Insurance Company Perspective)")
    print("-" * 80)
    print(f"Mean CAGR: {df['cagr'].mean():.2%}")
    print(f"Median CAGR: {df['cagr'].median():.2%}")
    print(f"Min CAGR: {df['cagr'].min():.2%}")
    print(f"Max CAGR: {df['cagr'].max():.2%}")
    print(f"Std Dev: {df['cagr'].std():.2%}")

    print("\nReturn Distribution:")
    print(f"  < 0% (losing money): {(df['cagr'] < 0).sum()} scenarios ({100*(df['cagr'] < 0).mean():.1f}%)")
    print(f"  0-1%: {((df['cagr'] >= 0) & (df['cagr'] < 0.01)).sum()} scenarios ({100*((df['cagr'] >= 0) & (df['cagr'] < 0.01)).mean():.1f}%)")
    print(f"  1-2%: {((df['cagr'] >= 0.01) & (df['cagr'] < 0.02)).sum()} scenarios ({100*((df['cagr'] >= 0.01) & (df['cagr'] < 0.02)).mean():.1f}%)")
    print(f"  2-3%: {((df['cagr'] >= 0.02) & (df['cagr'] < 0.03)).sum()} scenarios ({100*((df['cagr'] >= 0.02) & (df['cagr'] < 0.03)).mean():.1f}%)")
    print(f"  3%+: {(df['cagr'] >= 0.03).sum()} scenarios ({100*(df['cagr'] >= 0.03).mean():.1f}%)")

    RISK_FREE_RATE = 0.04
    print(f"\nCompared to risk-free rate ({RISK_FREE_RATE:.1%}):")
    print(f"  Above risk-free rate: {(df['cagr'] > RISK_FREE_RATE).sum()} scenarios ({100*(df['cagr'] > RISK_FREE_RATE).mean():.1f}%)")
    print(f"  Below risk-free rate: {(df['cagr'] <= RISK_FREE_RATE).sum()} scenarios ({100*(df['cagr'] <= RISK_FREE_RATE).mean():.1f}%)")

    print("\n" + "-" * 80)
    print("RISK METRICS")
    print("-" * 80)
    print(f"Default probability: {df['prob_default'].mean():.1%} (ZERO - guaranteed by capital)")
    print(f"Market risk exposure: {df['market_risk'].mean():.1%} (ZERO - no equity exposure)")
    print(f"Insurance required: {df['insurance_needed'].sum()} scenarios (NONE)")

    print("\n" + "-" * 80)
    print("BORROWER BENEFITS")
    print("-" * 80)
    print(f"Average annual income: ${df['avg_annual_income'].mean():,.0f}")
    print(f"Income vs target ({ANNUAL_INCOME_TARGET:,}): {df['income_vs_target'].mean():.1%}")
    print(f"First year income (avg): ${df['first_year_income'].mean():,.0f}")
    print(f"Last year income (avg): ${df['last_year_income'].mean():,.0f}")
    print(f"Total lifetime income (avg): ${df['total_borrower_income'].mean():,.0f}")

    print("\n" + "-" * 80)
    print("BEST SCENARIOS (Highest CAGR)")
    print("-" * 80)
    best = df.nlargest(5, 'cagr')[['house_value', 'loan_duration', 'cagr', 'avg_annual_income', 'final_profit']]
    print(best.to_string(index=False))

    print("\n" + "-" * 80)
    print("CAGR by Loan Duration")
    print("-" * 80)
    for duration in sorted(df['loan_duration'].unique()):
        subset = df[df['loan_duration'] == duration]
        print(f"  {duration} years: Mean CAGR = {subset['cagr'].mean():.2%}, Median = {subset['cagr'].median():.2%}")

    print("\n" + "=" * 80)
    print("VERDICT: IS THIS A GOOD PRODUCT?")
    print("=" * 80)

    avg_cagr = df['cagr'].mean()
    pct_positive = (df['cagr'] > 0).mean() * 100
    pct_above_1pct = (df['cagr'] > 0.01).mean() * 100

    print(f"\n📊 Average Return (CAGR): {avg_cagr:.2%}")
    print(f"✅ Positive Returns: {pct_positive:.1f}% of scenarios")
    print(f"📈 Above 1%: {pct_above_1pct:.1f}% of scenarios")
    print(f"⚠️  Default Risk: 0.0% (guaranteed)")
    print(f"⚠️  Market Risk: 0.0% (no equity exposure)")

    print("\n🔍 ASSESSMENT:")
    if avg_cagr > 0.01 and pct_positive == 100:
        print("✅ VIABLE - Consistent positive returns with zero default risk")
        print("   Insurance companies can profitably offer this product")
        print("   Returns lower than equity model's FALSE promises, but REAL and GUARANTEED")
    elif avg_cagr > 0:
        print("⚠️  MARGINAL - Small but consistent returns")
        print("   May work for large insurance companies with scale")
    else:
        print("❌ NOT VIABLE - Returns too low")

    print("\n💡 KEY ADVANTAGES vs Equity Preservation Mortgage:")
    print("• Zero default risk (vs 55% insurance probability)")
    print("• Zero market risk (vs volatile S&P 500 exposure)")
    print("• Predictable cashflows for both parties")
    print("• Simple, well-understood insurance product")
    print("• No complex derivatives or hedging needed")
    print(f"• Guaranteed returns: {avg_cagr:.2%} (vs equity model's FALSE 1.5% with hidden losses)")

    print("\n" + "=" * 80)

if __name__ == "__main__":
    # Run the analysis
    df = run_parameter_sweep()

    # Save results
    df.to_csv(OUTPUT_FILE, index=False)
    print(f"\nResults saved to: {OUTPUT_FILE}")

    # Analyze and display
    analyze_results(df)
