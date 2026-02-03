#!/usr/bin/env python3
"""
Validation script to ensure Rust XIRR matches Python numpy_financial.irr
"""

import numpy as np
import numpy_financial as npf
import monte_carlo_engine

print("=" * 80)
print("VALIDATION: Rust vs Python XIRR/IRR Comparison")
print("=" * 80)

# Test Case 1: Simple investment (should converge to known IRR)
print("\nTest Case 1: Simple Investment")
print("-" * 80)
cashflows1 = [-1000.0, 300.0, 300.0, 300.0, 300.0]
print(f"Cashflows: {cashflows1}")

python_irr1 = npf.irr(cashflows1)
rust_irr1 = monte_carlo_engine.calculate_irr(cashflows1)

print(f"\nPython IRR: {python_irr1:.6f} ({python_irr1*100:.4f}%)")
print(f"Rust IRR:   {rust_irr1:.6f} ({rust_irr1*100:.4f}%)" if rust_irr1 else "Rust IRR:   None (failed to converge)")

if rust_irr1:
    diff = abs(python_irr1 - rust_irr1)
    print(f"Difference: {diff:.10f} ({diff/abs(python_irr1)*100:.6f}%)")
    if diff < 1e-6:
        print("✅ PASS: Results match within tolerance")
    else:
        print("⚠️  WARNING: Results differ")
else:
    print("❌ FAIL: Rust did not converge")

# Test Case 2: Loan with negative return
print("\n\nTest Case 2: Loss-Making Investment")
print("-" * 80)
cashflows2 = [-1000.0, 100.0, 100.0, 100.0, 100.0]
print(f"Cashflows: {cashflows2}")

python_irr2 = npf.irr(cashflows2)
rust_irr2 = monte_carlo_engine.calculate_irr(cashflows2)

print(f"\nPython IRR: {python_irr2:.6f} ({python_irr2*100:.4f}%)")
print(f"Rust IRR:   {rust_irr2:.6f} ({rust_irr2*100:.4f}%)" if rust_irr2 else "Rust IRR:   None (failed to converge)")

if rust_irr2:
    diff = abs(python_irr2 - rust_irr2)
    print(f"Difference: {diff:.10f} ({diff/abs(python_irr2)*100:.6f}%)")
    if diff < 1e-6:
        print("✅ PASS: Results match within tolerance")
    else:
        print("⚠️  WARNING: Results differ")
else:
    print("❌ FAIL: Rust did not converge")

# Test Case 3: Mortgage scenario (realistic profitability case)
print("\n\nTest Case 3: Mortgage Profitability Scenario")
print("-" * 80)
# Simulate a 10-year mortgage quarterly cashflows
total_loan = 1_600_000.0
annual_income = 30_000.0
reinvest_fraction = 0.625
loan_duration = 10

# Initial outlay
initial_outlay = total_loan * reinvest_fraction + annual_income / 4

# Quarterly cashflows (simplified)
npcf = np.zeros(loan_duration * 4)
npcf[0] = -initial_outlay

# Assume some interest payments each quarter
quarterly_interest = total_loan * 0.04 / 4  # 4% annual rate
quarterly_annuity = annual_income / 4

for i in range(1, len(npcf)):
    npcf[i] = quarterly_interest - quarterly_annuity

# Final recovery (simplified - assume 80% loan recovery + some profit)
final_recovery = total_loan * 0.8 + 100_000
npcf[-1] += final_recovery

print(f"Initial Outlay: ${initial_outlay:,.2f}")
print(f"Quarterly Net Cashflow: ${npcf[1]:,.2f}")
print(f"Final Recovery: ${final_recovery:,.2f}")

python_irr3 = npf.irr(npcf)
rust_irr3 = monte_carlo_engine.calculate_irr(npcf.tolist())

print(f"\nPython IRR: {python_irr3:.6f} ({python_irr3*100:.4f}%)")
print(f"Rust IRR:   {rust_irr3:.6f} ({rust_irr3*100:.4f}%)" if rust_irr3 else "Rust IRR:   None (failed to converge)")

if rust_irr3:
    diff = abs(python_irr3 - rust_irr3)
    print(f"Difference: {diff:.10f} ({diff/abs(python_irr3)*100:.6f}%)")
    if diff < 1e-6:
        print("✅ PASS: Results match within tolerance")
    else:
        print("⚠️  WARNING: Results differ")
else:
    print("❌ FAIL: Rust did not converge")

# Test Case 4: Edge case - all zeros (should return None)
print("\n\nTest Case 4: Edge Case - All Zeros")
print("-" * 80)
cashflows4 = [0.0, 0.0, 0.0, 0.0]
print(f"Cashflows: {cashflows4}")

try:
    python_irr4 = npf.irr(cashflows4)
    print(f"\nPython IRR: {python_irr4}")
except:
    print("\nPython IRR: Failed (expected)")
    python_irr4 = None

rust_irr4 = monte_carlo_engine.calculate_irr(cashflows4)
print(f"Rust IRR:   {rust_irr4}")

if rust_irr4 is None:
    print("✅ PASS: Correctly returns None for invalid cashflows")
else:
    print("⚠️  WARNING: Should return None for all-zero cashflows")

# Test Case 5: High-yield scenario
print("\n\nTest Case 5: High-Yield Investment")
print("-" * 80)
cashflows5 = [-100.0, 50.0, 60.0, 70.0, 80.0]
print(f"Cashflows: {cashflows5}")

python_irr5 = npf.irr(cashflows5)
rust_irr5 = monte_carlo_engine.calculate_irr(cashflows5)

print(f"\nPython IRR: {python_irr5:.6f} ({python_irr5*100:.4f}%)")
print(f"Rust IRR:   {rust_irr5:.6f} ({rust_irr5*100:.4f}%)" if rust_irr5 else "Rust IRR:   None (failed to converge)")

if rust_irr5:
    diff = abs(python_irr5 - rust_irr5)
    print(f"Difference: {diff:.10f} ({diff/abs(python_irr5)*100:.6f}%)")
    if diff < 1e-6:
        print("✅ PASS: Results match within tolerance")
    else:
        print("⚠️  WARNING: Results differ")
else:
    print("❌ FAIL: Rust did not converge")

# Summary
print("\n" + "=" * 80)
print("VALIDATION SUMMARY")
print("=" * 80)

test_results = [
    ("Simple Investment", rust_irr1 is not None and abs(python_irr1 - rust_irr1) < 1e-6),
    ("Loss-Making Investment", rust_irr2 is not None and abs(python_irr2 - rust_irr2) < 1e-6),
    ("Mortgage Scenario", rust_irr3 is not None and abs(python_irr3 - rust_irr3) < 1e-6),
    ("Edge Case - Zeros", rust_irr4 is None),
    ("High-Yield Investment", rust_irr5 is not None and abs(python_irr5 - rust_irr5) < 1e-6),
]

passed = sum(1 for _, result in test_results if result)
total = len(test_results)

print(f"\nTests Passed: {passed}/{total}")
for name, result in test_results:
    status = "✅ PASS" if result else "❌ FAIL"
    print(f"  {status}: {name}")

if passed == total:
    print(f"\n✅ VALIDATED: Rust IRR implementation matches Python numpy_financial.irr")
    print(f"   Safe to use for profitability analysis")
else:
    print(f"\n⚠️  REVIEW NEEDED: Some tests failed")

print("=" * 80)
