#!/usr/bin/env python3
"""
Test if memory/path storage is the bottleneck
"""
import time
import sys
import monte_carlo_engine

print("=" * 80)
print("MEMORY/SCALING TEST")
print("=" * 80)

for num_paths in [1_000, 5_000, 10_000, 50_000, 100_000]:
    print(f"\nTesting with {num_paths:,} paths:")
    print("-" * 80)

    # Test path generation
    start = time.time()
    paths = monte_carlo_engine.gen_monte_carlo_paths(10, 0.10, 0.12, num_paths, 100.0)
    gen_time = time.time() - start

    # Calculate memory footprint (rough estimate)
    path_length = len(paths[0])
    memory_mb = (num_paths * path_length * 8) / (1024 * 1024)  # 8 bytes per f64

    print(f"  Path generation: {gen_time:.3f}s ({num_paths/gen_time:.0f} paths/sec)")
    print(f"  Path length: {path_length} timesteps")
    print(f"  Memory (est): {memory_mb:.1f} MB")

    # Test simulation
    start = time.time()
    results = monte_carlo_engine.single_mortgage_rust(
        1_600_000.0, 0.625, 10, 30_000.0, 10,
        1.5, 8_000.0, 0.04, 0.03, 0.012, 1.35, 1.95, 6,
        paths, 100.0, False, True, 0.2, 0.4, 0.005
    )
    sim_time = time.time() - start
    print(f"  Simulation:      {sim_time:.3f}s ({num_paths/sim_time:.0f} paths/sec)")

    # Test metrics
    start = time.time()
    metrics = monte_carlo_engine.calculate_metrics(
        results, 1_600_000.0, 0.625, 10, 30_000.0, 10, 0.04
    )
    metrics_time = time.time() - start
    print(f"  Metrics:         {metrics_time:.3f}s")

    total = gen_time + sim_time + metrics_time
    print(f"  TOTAL:           {total:.3f}s ({1/total:.2f} scenarios/sec)")

    if num_paths >= 50_000 and gen_time > 5.0:
        print(f"\n⚠️  Warning: Generation time growing significantly")
        print(f"   This suggests memory/allocation overhead")
        break

print("\n" + "=" * 80)
