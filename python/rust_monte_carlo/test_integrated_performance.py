#!/usr/bin/env python3
"""
Test the optimized integrated function that generates paths on-the-fly
"""
import time
import monte_carlo_engine

# Test parameters
total_loan = 1_600_000.0
reinvest_fraction = 0.625
loan_duration = 10
annual_income = 30_000.0
annuity_duration = 10

print("=" * 80)
print("PERFORMANCE COMPARISON: Old vs Integrated")
print("=" * 80)

for num_paths in [10_000, 50_000, 100_000]:
    print(f"\n{num_paths:,} Paths")
    print("-" * 80)

    # OLD METHOD: Generate paths separately, then simulate
    print("OLD METHOD (separate path generation):")
    start_total = time.time()

    start = time.time()
    paths = monte_carlo_engine.gen_monte_carlo_paths(
        loan_duration, 0.10, 0.12, num_paths, 100.0
    )
    gen_time = time.time() - start
    print(f"  Path generation: {gen_time:.3f}s")

    start = time.time()
    results_old = monte_carlo_engine.single_mortgage_rust(
        total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
        1.5, 8_000.0, 0.04, 0.03, 0.012, 1.35, 1.95, 6,
        paths, 100.0, False, True, 0.2, 0.4, 0.005
    )
    sim_time = time.time() - start
    print(f"  Simulation:      {sim_time:.3f}s")

    start = time.time()
    metrics_old = monte_carlo_engine.calculate_metrics(
        results_old, total_loan, reinvest_fraction, loan_duration,
        annual_income, annuity_duration, 0.04
    )
    metrics_time = time.time() - start
    print(f"  Metrics:         {metrics_time:.3f}s")

    old_total = time.time() - start_total
    print(f"  TOTAL:           {old_total:.3f}s ({1/old_total:.3f} scenarios/sec)")

    # NEW METHOD: Integrated (generate on-the-fly)
    print("\nNEW METHOD (integrated):")
    start_total = time.time()

    results_new = monte_carlo_engine.single_mortgage_integrated(
        total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
        1.5, 8_000.0, 0.04, 0.03, 0.012, 1.35, 1.95, 6,
        num_paths, 0.10, 0.12, 100.0, False, True, 0.2, 0.4, 0.005
    )
    sim_time_new = time.time() - start_total
    print(f"  Simulation:      {sim_time_new:.3f}s")

    start = time.time()
    metrics_new = monte_carlo_engine.calculate_metrics(
        results_new, total_loan, reinvest_fraction, loan_duration,
        annual_income, annuity_duration, 0.04
    )
    metrics_time_new = time.time() - start
    print(f"  Metrics:         {metrics_time_new:.3f}s")

    new_total = time.time() - start_total
    print(f"  TOTAL:           {new_total:.3f}s ({1/new_total:.3f} scenarios/sec)")

    # Comparison
    speedup = old_total / new_total
    print(f"\n  SPEEDUP:         {speedup:.2f}x faster")
    print(f"  Time saved:      {old_total - new_total:.3f}s ({(1-new_total/old_total)*100:.1f}%)")

    # Verify results match
    diff = abs(metrics_old.mean_reinvestment - metrics_new.mean_reinvestment)
    diff_pct = diff / metrics_old.mean_reinvestment * 100
    print(f"\n  Mean Reinvestment (old): ${metrics_old.mean_reinvestment:,.2f}")
    print(f"  Mean Reinvestment (new): ${metrics_new.mean_reinvestment:,.2f}")
    print(f"  Difference:              {diff_pct:.4f}%")

    if diff_pct < 1.0:
        print(f"  ✅ Results match!")
    else:
        print(f"  ⚠️  Results differ significantly")

    if num_paths >= 50_000:
        break  # Don't test 100K if 50K is too slow

print("\n" + "=" * 80)
