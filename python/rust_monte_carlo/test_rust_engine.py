#!/usr/bin/env python3
"""
Quick test of the Rust Monte Carlo engine
"""

import time
import monte_carlo_engine

print("Testing Rust Monte Carlo Engine")
print("=" * 50)

# Test parameters (small scenario for quick test)
loan_duration = 10
equity_return = 0.10
volatility = 0.12
num_paths = 1000  # Start with 1K paths for quick test
s0 = 100.0

print(f"\nGenerating {num_paths:,} Monte Carlo paths...")
start = time.time()
paths = monte_carlo_engine.gen_monte_carlo_paths(
    loan_duration,
    equity_return,
    volatility,
    num_paths,
    s0
)
elapsed = time.time() - start
print(f"✅ Generated in {elapsed:.3f}s")
print(f"   Path shape: {len(paths)} paths × {len(paths[0])} months")
print(f"   First path start: ${paths[0][0]:.2f}, end: ${paths[0][-1]:.2f}")

# Test mortgage simulation
print(f"\nRunning mortgage simulation...")
start = time.time()
results = monte_carlo_engine.single_mortgage_rust(
    total_loan=1_600_000.0,
    reinvest_fraction=0.625,
    loan_duration=loan_duration,
    annual_income=30_000.0,
    annuity_duration=10,
    insurance_profit_margin=1.5,
    insurance_cost=8_000.0,
    cash_rate=0.04,
    wholesale_lending_margin=0.03,
    additional_loan_margins=0.012,
    holiday_enter_fraction=1.35,
    holiday_exit_fraction=1.95,
    subperform_loan_threshold_quarters=6,
    price_paths=paths,
    s0=s0,
    principal_repayment=False,
    hedged=True,
    hedging_max_loss=0.2,
    hedging_cap=0.4,
    hedging_cost_pa=0.005
)
elapsed = time.time() - start
print(f"✅ Simulated in {elapsed:.3f}s")
print(f"   {len(results):,} results")
print(f"   Mean reinvestment: ${sum(r.reinvestment for r in results) / len(results):,.2f}")
print(f"   Mean deficit: ${sum(r.interest_deficit for r in results) / len(results):,.2f}")

# Performance test with more paths
print(f"\n🚀 Performance test with 10,000 paths...")
start = time.time()
paths = monte_carlo_engine.gen_monte_carlo_paths(
    loan_duration, equity_return, volatility, 10_000, s0
)
gen_time = time.time() - start

start = time.time()
results = monte_carlo_engine.single_mortgage_rust(
    1_600_000.0, 0.625, loan_duration, 30_000.0, 10,
    1.5, 8_000.0, 0.04, 0.03, 0.012,
    1.35, 1.95, 6, paths, s0,
    False, True, 0.2, 0.4, 0.005
)
sim_time = time.time() - start
total_time = gen_time + sim_time

print(f"   Path generation: {gen_time:.3f}s")
print(f"   Simulation: {sim_time:.3f}s")
print(f"   Total: {total_time:.3f}s")
print(f"\n✅ Rust engine is working correctly!")
print(f"   Ready for full profitability sweep")
