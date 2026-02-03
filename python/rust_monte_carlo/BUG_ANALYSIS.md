# Critical Bug Analysis: Rust Never Exits Holiday

## Test Results

**Single-Path Validation Test (seed=42):**
- Python: Exits holiday at quarter 30, final deficit $231K
- Rust: NEVER exits holiday (40/40 quarters), final deficit $530K
- Difference: $241K in reinvestment, $300K in deficit

## Root Cause

Python shows customer **DOES exit holiday** at quarter 30 when holdings reach $1.40M (above $1.18M threshold).

Rust shows customer **NEVER exits holiday** - stays on holiday all 40 quarters.

## Expected Behavior (from Python)

1. **Initial State:**
   - Initial investment: $605,385.51
   - Initial units: 6053.86
   - Initial loan size: $653,350.00
   - Holiday ENTER threshold (135%): $817,270.44
   - Holiday EXIT threshold (195%): $1,180,501.75

2. **Quarters 1-29:** Customer ON HOLIDAY
   - Holdings grow from $583K → $1.4M
   - Interest deferred (not paid)
   - Deficit accumulates

3. **Quarter 30:** **CUSTOMER EXITS HOLIDAY** ✅
   - Holdings: $1,402,973 > $1,180,502 exit threshold
   - Exits holiday, starts paying interest
   - Deficit stops growing

4. **Quarters 31-40:** Customer OFF HOLIDAY
   - Pays interest normally
   - Final deficit stays at $231K

## Suspected Rust Bug

The Rust code appears correct at first glance:

```rust
if on_holiday {
    if holdings_value > holiday_exit_threshold {
        // Exit holiday and pay interest
        on_holiday = false;
        sp500_units -= interest_due_per_share;
        interest_paid = interest_due;
        quarters_in_holiday = 0;
    }
}
```

But the customer NEVER exits, which means:
1. Either `holdings_value` is being calculated wrong
2. Or `holiday_exit_threshold` is wrong
3. Or there's a calculation order issue

## Next Steps

1. ✅ Add detailed quarter-by-quarter logging to Rust
2. Print out `holdings_value` vs `holiday_exit_threshold` for first 35 quarters
3. Find the exact quarter where divergence occurs
4. Compare the exact values between Python and Rust

## Critical Values to Check

- holdings_value = sp500_units * sp500_price
- holiday_exit_threshold = initial_investment * 1.95 = $1,180,501.75

If Rust is calculating these differently than Python, that's the bug.
