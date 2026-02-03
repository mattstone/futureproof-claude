#!/usr/bin/env python3
"""
Hedging Strategy Analysis

Compares different hedging approaches:
1. Current: 20% downside protection, 40% upside cap (5-year)
2. Tighter protection: 10% downside, 30% upside cap
3. Asymmetric: 15% downside, no upside cap
4. Put spread: 20-30% protection collar
5. Dynamic: Adjust based on volatility
6. No hedging: Baseline comparison
"""

import monte_carlo_engine
import pandas as pd
import numpy as np
import time

# Test scenario
HOUSE_VALUE = 2_000_000
LVR = 0.80
LOAN_DURATION = 10
ANNUITY_DURATION = 10
ANNUAL_INCOME_FRACTION = 0.015

# Fixed parameters
WHOLESALE_LENDING_MARGIN = 0.03
ADDITIONAL_LOAN_MARGINS = 0.012
SUBPERFORM_LOAN_THRESHOLD_QUARTERS = 6
INSURANCE_PROFIT_MARGIN = 1.5
CASH_RATE = 0.031
INSURANCE_COST_PA = 0.005
HOLIDAY_ENTER = 1.35
HOLIDAY_EXIT = 1.95

# Monte Carlo parameters
MONTE_CARLO_PATHS = 50_000  # 50K for reasonable speed
EQUITY_RETURN = 0.10
VOLATILITY = 0.12
S0 = 100.0

# Hedging strategies to test
STRATEGIES = [
    {
        'name': 'No Hedging',
        'hedged': False,
        'max_loss': 0.0,
        'cap': 0.0,
        'cost_pa': 0.0,
        'description': 'Pure equity exposure, no protection'
    },
    {
        'name': 'Current Strategy',
        'hedged': True,
        'max_loss': 0.20,
        'cap': 0.40,
        'cost_pa': 0.005,
        'description': '20% downside protection, 40% cap (5yr), 0.5% cost'
    },
    {
        'name': 'Tighter Protection',
        'hedged': True,
        'max_loss': 0.10,
        'cap': 0.30,
        'cost_pa': 0.012,
        'description': '10% downside protection, 30% cap (5yr), 1.2% cost'
    },
    {
        'name': 'Moderate Protection',
        'hedged': True,
        'max_loss': 0.15,
        'cap': 0.35,
        'cost_pa': 0.008,
        'description': '15% downside protection, 35% cap (5yr), 0.8% cost'
    },
    {
        'name': 'Loose Protection',
        'hedged': True,
        'max_loss': 0.25,
        'cap': 0.50,
        'cost_pa': 0.003,
        'description': '25% downside protection, 50% cap (5yr), 0.3% cost'
    },
    {
        'name': 'Asymmetric (No Cap)',
        'hedged': True,
        'max_loss': 0.15,
        'cap': 1.00,  # Effectively no cap
        'cost_pa': 0.010,
        'description': '15% downside protection, no upside cap, 1.0% cost'
    },
    {
        'name': 'Catastrophic Only',
        'hedged': True,
        'max_loss': 0.30,
        'cap': 0.60,
        'cost_pa': 0.002,
        'description': '30% downside protection, 60% cap (5yr), 0.2% cost'
    },
]


def run_strategy(strategy):
    """Run simulation with given hedging strategy"""

    total_loan = HOUSE_VALUE * LVR
    annual_income = HOUSE_VALUE * ANNUAL_INCOME_FRACTION
    reinvest_fraction = 1 - (ANNUITY_DURATION * annual_income) / total_loan
    insurance_cost = INSURANCE_COST_PA * total_loan * LOAN_DURATION

    print(f"\n  Testing: {strategy['name']}", end=" ", flush=True)
    start = time.time()

    try:
        results = monte_carlo_engine.single_mortgage_integrated(
            total_loan,
            reinvest_fraction,
            LOAN_DURATION,
            annual_income,
            ANNUITY_DURATION,
            INSURANCE_PROFIT_MARGIN,
            insurance_cost,
            CASH_RATE,
            WHOLESALE_LENDING_MARGIN,
            ADDITIONAL_LOAN_MARGINS,
            HOLIDAY_ENTER,
            HOLIDAY_EXIT,
            SUBPERFORM_LOAN_THRESHOLD_QUARTERS,
            MONTE_CARLO_PATHS,
            EQUITY_RETURN,
            VOLATILITY,
            S0,
            False,  # Interest Only
            strategy['hedged'],
            strategy['max_loss'],
            strategy['cap'],
            strategy['cost_pa']
        )

        metrics = monte_carlo_engine.calculate_metrics(
            results, total_loan, reinvest_fraction, LOAN_DURATION,
            annual_income, ANNUITY_DURATION, CASH_RATE
        )

        elapsed = time.time() - start
        print(f"✓ ({elapsed:.1f}s)")

        return {
            'strategy': strategy['name'],
            'description': strategy['description'],
            'hedged': strategy['hedged'],
            'max_loss': strategy['max_loss'],
            'cap': strategy['cap'],
            'cost_pa': strategy['cost_pa'],
            'cagr': metrics.mean_cagr,
            'insurance_risk': metrics.prob_insurance_payout,
            'xirr': metrics.xirr if metrics.xirr is not None else np.nan,
            'viable': (metrics.mean_cagr >= 0.08 and metrics.prob_insurance_payout < 0.20),
            'mean_reinvestment': metrics.mean_reinvestment,
            'std_reinvestment': metrics.std_reinvestment,
            'simulation_time': elapsed
        }
    except Exception as e:
        print(f"✗ Error: {e}")
        return None


def analyze_tradeoffs(df):
    """Analyze risk-return tradeoffs"""

    print("\n" + "=" * 90)
    print("HEDGING STRATEGY COMPARISON")
    print("=" * 90)

    print(f"\n{'Strategy':<25} {'CAGR':<10} {'Ins Risk':<12} {'XIRR':<10} {'Cost':<8} {'Viable':<8}")
    print("-" * 90)

    for _, row in df.iterrows():
        viable_str = "✅ YES" if row['viable'] else "❌ NO"
        xirr_str = f"{row['xirr']*100:5.2f}%" if not np.isnan(row['xirr']) else "  N/A"
        print(f"{row['strategy']:<25} {row['cagr']*100:>6.2f}%  {row['insurance_risk']*100:>8.2f}%  "
              f"{xirr_str:>8}  {row['cost_pa']*100:>5.2f}%  {viable_str}")

    # Find best by different criteria
    print("\n" + "=" * 90)
    print("OPTIMAL STRATEGIES BY OBJECTIVE")
    print("=" * 90)

    # Best CAGR
    best_cagr = df.nlargest(1, 'cagr').iloc[0]
    print(f"\nHighest CAGR: {best_cagr['strategy']}")
    print(f"  CAGR: {best_cagr['cagr']*100:.2f}%")
    print(f"  Insurance Risk: {best_cagr['insurance_risk']*100:.2f}%")
    print(f"  Trade-off: {best_cagr['description']}")

    # Lowest insurance risk
    best_ins = df.nsmallest(1, 'insurance_risk').iloc[0]
    print(f"\nLowest Insurance Risk: {best_ins['strategy']}")
    print(f"  Insurance Risk: {best_ins['insurance_risk']*100:.2f}%")
    print(f"  CAGR: {best_ins['cagr']*100:.2f}%")
    print(f"  Trade-off: {best_ins['description']}")

    # Best risk-adjusted (CAGR / Insurance Risk ratio)
    df['sharpe_proxy'] = df['cagr'] / df['insurance_risk']
    best_adjusted = df.nlargest(1, 'sharpe_proxy').iloc[0]
    print(f"\nBest Risk-Adjusted: {best_adjusted['strategy']}")
    print(f"  CAGR: {best_adjusted['cagr']*100:.2f}%")
    print(f"  Insurance Risk: {best_adjusted['insurance_risk']*100:.2f}%")
    print(f"  Risk-Adjusted Score: {best_adjusted['sharpe_proxy']:.3f}")
    print(f"  Trade-off: {best_adjusted['description']}")

    # Closest to viable (if any)
    df['distance_to_viable'] = np.sqrt(
        (df['cagr'] - 0.08)**2 + (df['insurance_risk'] - 0.20)**2
    )
    closest = df.nsmallest(1, 'distance_to_viable').iloc[0]
    print(f"\nClosest to Viability: {closest['strategy']}")
    print(f"  CAGR: {closest['cagr']*100:.2f}% (target: 8%)")
    print(f"  Insurance Risk: {closest['insurance_risk']*100:.2f}% (target: <20%)")
    print(f"  Distance to viable: {closest['distance_to_viable']:.4f}")

    # Cost-benefit analysis
    print("\n" + "=" * 90)
    print("COST-BENEFIT ANALYSIS")
    print("=" * 90)

    no_hedge = df[df['strategy'] == 'No Hedging'].iloc[0]
    print(f"\nBaseline (No Hedging):")
    print(f"  CAGR: {no_hedge['cagr']*100:.2f}%")
    print(f"  Insurance Risk: {no_hedge['insurance_risk']*100:.2f}%")

    print(f"\nHedging Impact vs No Hedging:")
    print(f"{'Strategy':<25} {'CAGR Δ':<12} {'Ins Risk Δ':<15} {'Cost':<10} {'Worth It?':<10}")
    print("-" * 90)

    for _, row in df[df['hedged']].iterrows():
        cagr_delta = row['cagr'] - no_hedge['cagr']
        ins_delta = row['insurance_risk'] - no_hedge['insurance_risk']

        # Simple "worth it" heuristic: Insurance reduction > 5% and CAGR loss < 1%
        worth_it = (ins_delta < -0.05) and (cagr_delta > -0.01)
        worth_str = "✅ YES" if worth_it else "❌ NO"

        print(f"{row['strategy']:<25} {cagr_delta*100:>+6.2f}%    {ins_delta*100:>+8.2f}%      "
              f"{row['cost_pa']*100:>5.2f}%    {worth_str}")


def main():
    print("=" * 90)
    print("HEDGING STRATEGY OPTIMIZATION")
    print("=" * 90)
    print(f"\nTesting {len(STRATEGIES)} hedging strategies")
    print(f"Scenario: ${HOUSE_VALUE:,} house, {LVR:.0%} LVR, {LOAN_DURATION}y/{ANNUITY_DURATION}y")
    print(f"Monte Carlo: {MONTE_CARLO_PATHS:,} paths per strategy")

    results = []
    for strategy in STRATEGIES:
        result = run_strategy(strategy)
        if result:
            results.append(result)

    df = pd.DataFrame(results)
    df.to_csv('hedging_strategy_comparison.csv', index=False)

    analyze_tradeoffs(df)

    # Key insights
    print("\n" + "=" * 90)
    print("🎯 KEY INSIGHTS")
    print("=" * 90)

    no_hedge = df[df['strategy'] == 'No Hedging'].iloc[0]
    current = df[df['strategy'] == 'Current Strategy'].iloc[0]

    ins_improvement = (no_hedge['insurance_risk'] - current['insurance_risk']) / no_hedge['insurance_risk']
    cagr_cost = (no_hedge['cagr'] - current['cagr']) / no_hedge['cagr']

    print(f"\nCurrent Hedging Performance:")
    print(f"  Reduces insurance risk by: {ins_improvement*100:.1f}%")
    print(f"  Costs in CAGR terms: {cagr_cost*100:.1f}%")
    print(f"  Direct cost: {current['cost_pa']*100:.1f}% annually")

    # Recommendations
    viable_count = df['viable'].sum()
    if viable_count > 0:
        print(f"\n✅ Found {viable_count} viable hedging strategies!")
        best_viable = df[df['viable']].nlargest(1, 'cagr').iloc[0]
        print(f"\nBest viable strategy: {best_viable['strategy']}")
        print(f"  {best_viable['description']}")
        print(f"  CAGR: {best_viable['cagr']*100:.2f}%")
        print(f"  Insurance Risk: {best_viable['insurance_risk']*100:.2f}%")
        print(f"  Cost: {best_viable['cost_pa']*100:.1f}% annually")
    else:
        print(f"\n❌ No hedging strategy achieves viability (CAGR≥8%, Insurance<20%)")

        closest = df.nsmallest(1, 'distance_to_viable').iloc[0]
        print(f"\nClosest approach: {closest['strategy']}")
        print(f"  CAGR: {closest['cagr']*100:.2f}% (need 8%)")
        print(f"  Insurance: {closest['insurance_risk']*100:.2f}% (need <20%)")
        print(f"\n💡 Conclusion: Hedging helps but can't overcome 80% LVR structural problem")

    print(f"\n✅ Results saved to: hedging_strategy_comparison.csv")
    print("=" * 90)


if __name__ == "__main__":
    main()
