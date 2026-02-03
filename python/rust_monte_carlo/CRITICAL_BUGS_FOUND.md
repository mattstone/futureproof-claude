# Critical Bugs Found in Rust Implementation

## Summary

The Rust Monte Carlo engine has critical bugs that cause it to produce incorrect results. **DO NOT USE for production until these are fixed.**

## Bug 1: Incorrect Holiday Initial State ✅ FIXED

**Issue**: Customer should start "on holiday" when `holiday_enter_fraction > 1.0`, but Rust was initializing `on_holiday = false`.

**Impact**: Customer starts in wrong state.

**Fix Applied**: Changed to `let mut on_holiday = holiday_enter_fraction > 1.0;`

## Bug 2: Customer Never Exits Holiday ⚠️ STILL BROKEN

**Issue**: Even after fixing initial state, Rust shows customer stays on holiday 100% of time, while Python shows customer exits holiday when portfolio grows.

**Evidence**:
- Rust: 100% holiday quarters, $584K deficit (maximum possible)
- Python: Customer exits holiday, only $330K average deficit

**Root Cause**: Unknown - holiday exit logic appears correct but not working.

**Debugging needed**:
1. Check if `reinvestment` value is being calculated correctly
2. Check if `holiday_exit_threshold` is correct value
3. Verify comparison logic

## Bug 3: Possible Annuity Payment Issue

**Observation**: Python adds `annual_income_quarter` to `loan_size` after each annuity payment (line 326):
```python
if t < annuity_duration_quarters:
    if piProgressiveRepayment:
        holdings -= units_to_principal
    else:
        loan_size += annual_income_quarter
```

**Rust**: Does not appear to modify loan size after annuity payments.

**Impact**: May affect interest calculations if loan size should increase.

## Bug 4: Missing Hedging Logic

**Issue**: Python has complex hedging logic (lines 271-289) that adjusts holdings based on price movements.

**Rust**: Hedging cost is deducted but no hedging protection/adjustment logic.

**Impact**: Results will differ when hedging is enabled.

## Current Test Results

### Python (100 paths, seed=42):
- Mean reinvestment: $1,205,749
- Mean deficit: $330,143
- Holiday percentage: Varies by path (exits holiday when portfolio grows)

### Rust (100 paths):
- Mean reinvestment: $1,152,297
- Mean deficit: $584,000 (WRONG - this is maximum possible)
- Holiday percentage: 100% (WRONG - should vary)

## Recommendation

**The Rust implementation needs a complete review comparing line-by-line against the Python original.**

I've identified several issues but there may be more. The safest approach is:

1. Create a detailed specification document from the Python code
2. Rewrite the Rust implementation following that spec exactly
3. Create comprehensive unit tests that compare Rust vs Python on single paths
4. Only then move to full Monte Carlo sweeps

**DO NOT run 100K path sweeps until the basic simulation logic is verified correct.**
