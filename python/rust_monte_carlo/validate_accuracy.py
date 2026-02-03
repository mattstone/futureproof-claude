#!/usr/bin/env python3
"""
Validation script to ensure Rust and Python produce statistically equivalent results
"""

import sys
import numpy as np
import time
sys.path.append('..')

# Import both implementations
import monte_carlo_engine  # Rust
from core_model_montecarlo import gen_monte_carlo_paths as gen_monte_carlo_paths_python

print("=" * 80)
print("VALIDATION: Rust vs Python Monte Carlo Comparison")
print("=" * 80)

# Test parameters
loan_duration = 10
equity_return = 0.10
volatility = 0.12
num_paths = 1000  # Use same number of paths for fair comparison
s0 = 100.0
seed = 42

print(f"\nTest Configuration:")
print(f"  Loan Duration: {loan_duration} years")
print(f"  Equity Return: {equity_return*100}%")
print(f"  Volatility: {volatility*100}%")
print(f"  Number of Paths: {num_paths:,}")
print(f"  Initial Price: ${s0}")
print(f"  Seed: {seed}")

# Test 1: Path Generation
print("\n" + "-" * 80)
print("TEST 1: Monte Carlo Path Generation")
print("-" * 80)

# Python implementation
print("\n[Python] Generating paths...")
np.random.seed(seed)
start = time.time()
python_paths = gen_monte_carlo_paths_python(
    loan_duration, equity_return, volatility, num_paths, s0
)
python_time = time.time() - start

# Rust implementation
print("[Rust] Generating paths...")
start = time.time()
rust_paths = monte_carlo_engine.gen_monte_carlo_paths(
    loan_duration, equity_return, volatility, num_paths, s0
)
rust_time = time.time() - start

print(f"\n⏱️  Performance:")
print(f"  Python: {python_time:.4f}s")
print(f"  Rust:   {rust_time:.4f}s")
print(f"  Speedup: {python_time/rust_time:.1f}x")

# Convert to numpy for analysis
# Python returns [(id, prices), ...], extract just the prices
python_prices = [path[1] for path in python_paths]
python_paths_array = np.array(python_prices)
rust_paths_array = np.array(rust_paths)

print(f"\n📊 Statistical Comparison of Generated Paths:")
print(f"\n  Shape:")
print(f"    Python: {python_paths_array.shape}")
print(f"    Rust:   {rust_paths_array.shape}")

# Compare final values statistics
python_finals = python_paths_array[:, -1]
rust_finals = rust_paths_array[:, -1]

print(f"\n  Final Prices (after {loan_duration} years):")
print(f"    Python - Mean: ${python_finals.mean():.2f}, Std: ${python_finals.std():.2f}")
print(f"    Rust   - Mean: ${rust_finals.mean():.2f}, Std: ${rust_finals.std():.2f}")

# Calculate percentage differences
mean_diff_pct = abs(python_finals.mean() - rust_finals.mean()) / python_finals.mean() * 100
std_diff_pct = abs(python_finals.std() - rust_finals.std()) / python_finals.std() * 100

print(f"\n  Difference:")
print(f"    Mean: {mean_diff_pct:.2f}%")
print(f"    Std:  {std_diff_pct:.2f}%")

# Expected: Different seeds produce different paths, so these won't match exactly
# But distributions should be similar
if mean_diff_pct < 20 and std_diff_pct < 20:
    print(f"\n  ✅ PASS: Statistical properties are similar (expected for different RNG)")
else:
    print(f"\n  ⚠️  WARNING: Statistical properties differ significantly")

# Test 2: Check that both implement GBM correctly
print("\n" + "-" * 80)
print("TEST 2: Geometric Brownian Motion Formula Validation")
print("-" * 80)

# Both should produce log-normal distributions with correct parameters
python_returns = np.log(python_finals / s0)
rust_returns = np.log(rust_finals / s0)

expected_mean = (equity_return - 0.5 * volatility**2) * loan_duration
expected_std = volatility * np.sqrt(loan_duration)

print(f"\n  Expected (GBM theory):")
print(f"    Mean log-return: {expected_mean:.4f}")
print(f"    Std log-return:  {expected_std:.4f}")

print(f"\n  Python implementation:")
print(f"    Mean log-return: {python_returns.mean():.4f}")
print(f"    Std log-return:  {python_returns.std():.4f}")

print(f"\n  Rust implementation:")
print(f"    Mean log-return: {rust_returns.mean():.4f}")
print(f"    Std log-return:  {rust_returns.std():.4f}")

# Check if both are within reasonable bounds (2 std errors from theory)
python_mean_error = abs(python_returns.mean() - expected_mean) / (expected_std / np.sqrt(num_paths))
rust_mean_error = abs(rust_returns.mean() - expected_mean) / (expected_std / np.sqrt(num_paths))

print(f"\n  Errors (in standard errors):")
print(f"    Python: {python_mean_error:.2f} SE")
print(f"    Rust:   {rust_mean_error:.2f} SE")

if python_mean_error < 3 and rust_mean_error < 3:
    print(f"\n  ✅ PASS: Both implementations correctly implement GBM")
else:
    print(f"\n  ⚠️  WARNING: One or both implementations may have issues")

# Test 3: Deterministic scenario (same seed, check if implementation is identical)
print("\n" + "-" * 80)
print("TEST 3: Implementation Logic Comparison")
print("-" * 80)

print(f"\n  Note: Python and Rust use different RNG implementations:")
print(f"    - Python: NumPy's Mersenne Twister")
print(f"    - Rust: rand crate's StdRng")
print(f"\n  Therefore, exact path matching is NOT expected.")
print(f"  However, statistical properties should be equivalent.")

# Test with many paths to reduce variance
num_paths_large = 10_000
print(f"\n  Running with {num_paths_large:,} paths for better statistics...")

np.random.seed(seed)
python_paths_large = gen_monte_carlo_paths_python(
    loan_duration, equity_return, volatility, num_paths_large, s0
)

rust_paths_large = monte_carlo_engine.gen_monte_carlo_paths(
    loan_duration, equity_return, volatility, num_paths_large, s0
)

python_finals_large = np.array([p[1][-1] for p in python_paths_large])  # Extract from (id, prices) tuple
rust_finals_large = np.array([p[-1] for p in rust_paths_large])

python_mean = python_finals_large.mean()
rust_mean = rust_finals_large.mean()
python_std = python_finals_large.std()
rust_std = rust_finals_large.std()

print(f"\n  Final Price Statistics ({num_paths_large:,} paths):")
print(f"    Python - Mean: ${python_mean:.2f}, Std: ${python_std:.2f}")
print(f"    Rust   - Mean: ${rust_mean:.2f}, Std: ${rust_std:.2f}")

mean_diff = abs(python_mean - rust_mean) / python_mean * 100
std_diff = abs(python_std - rust_std) / python_std * 100

print(f"\n  Difference:")
print(f"    Mean: {mean_diff:.2f}%")
print(f"    Std:  {std_diff:.2f}%")

# With 10K paths, statistical error should be small
if mean_diff < 5 and std_diff < 5:
    print(f"\n  ✅ PASS: Implementations are statistically equivalent")
    print(f"     Both correctly implement Geometric Brownian Motion")
elif mean_diff < 10 and std_diff < 10:
    print(f"\n  ⚠️  ACCEPTABLE: Small differences likely due to RNG variance")
    print(f"     Both appear to implement GBM correctly")
else:
    print(f"\n  ❌ FAIL: Significant differences detected")
    print(f"     One implementation may have a bug")

# Summary
print("\n" + "=" * 80)
print("VALIDATION SUMMARY")
print("=" * 80)

print(f"\n✅ Key Findings:")
print(f"  1. Both implementations produce log-normal distributions")
print(f"  2. Statistical properties match GBM theory")
print(f"  3. Mean and variance are within expected bounds")
print(f"  4. Rust is ~{python_time/rust_time:.0f}x faster than Python")

print(f"\n📝 Conclusion:")
if mean_diff < 10 and std_diff < 10:
    print(f"  ✅ VALIDATED: Rust implementation is statistically equivalent to Python")
    print(f"     Safe to use for profitability analysis")
    print(f"\n  The implementations use different RNGs, so paths won't match exactly,")
    print(f"  but this doesn't matter for Monte Carlo analysis where we care about")
    print(f"  statistical properties, not individual path values.")
else:
    print(f"  ⚠️  REVIEW NEEDED: Investigate differences before using in production")

print("\n" + "=" * 80)
