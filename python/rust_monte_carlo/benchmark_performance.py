#!/usr/bin/env python3
"""
Quick benchmark to identify performance bottleneck
"""
import time
import monte_carlo_engine

# Test parameters
total_loan = 1_600_000.0
reinvest_fraction = 0.625
loan_duration = 10
annual_income = 30_000.0
annuity_duration = 10
num_paths = 10_000

print("=" * 80)
print("PERFORMANCE BENCHMARK")
print("=" * 80)
print(f"\nConfiguration: {num_paths:,} paths, {loan_duration} year loan\n")

# Test 1: Path Generation
print("Test 1: Path Generation")
print("-" * 80)
start = time.time()
paths = monte_carlo_engine.gen_monte_carlo_paths(
    loan_duration, 0.10, 0.12, num_paths, 100.0
)
path_time = time.time() - start
print(f"✓ Generated {len(paths):,} paths in {path_time:.3f}s ({num_paths/path_time:.1f} paths/sec)")

# Test 2: Simulation
print("\nTest 2: Mortgage Simulation")
print("-" * 80)
start = time.time()
results = monte_carlo_engine.single_mortgage_rust(
    total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
    1.5, 8_000.0, 0.04, 0.03, 0.012, 1.35, 1.95, 6,
    paths, 100.0, False, True, 0.2, 0.4, 0.005
)
sim_time = time.time() - start
print(f"✓ Simulated {len(results):,} paths in {sim_time:.3f}s ({num_paths/sim_time:.1f} paths/sec)")

# Test 3: Metrics Calculation
print("\nTest 3: Metrics Calculation")
print("-" * 80)
start = time.time()
metrics = monte_carlo_engine.calculate_metrics(
    results, total_loan, reinvest_fraction, loan_duration,
    annual_income, annuity_duration, 0.04
)
metrics_time = time.time() - start
print(f"✓ Calculated metrics in {metrics_time:.3f}s")

# Total
total_time = path_time + sim_time + metrics_time
print("\n" + "=" * 80)
print("SUMMARY")
print("=" * 80)
print(f"Path Generation:  {path_time:.3f}s ({path_time/total_time*100:.1f}%)")
print(f"Simulation:       {sim_time:.3f}s ({sim_time/total_time*100:.1f}%)")
print(f"Metrics:          {metrics_time:.3f}s ({metrics_time/total_time*100:.1f}%)")
print(f"Total:            {total_time:.3f}s")
print(f"Rate:             {1/total_time:.2f} scenarios/sec")
print("=" * 80)

# Display some results
print(f"\nSample Results:")
print(f"  Mean Reinvestment: ${metrics.mean_reinvestment:,.2f}")
print(f"  Mean CAGR:         {metrics.mean_cagr*100:.2f}%")
xirr_str = f"{metrics.xirr*100:.2f}%" if metrics.xirr else "N/A"
print(f"  XIRR:              {xirr_str}")
