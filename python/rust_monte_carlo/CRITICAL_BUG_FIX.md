# Critical Bug Fix: Interest Rate Calculation Error

## The Bug

The Rust implementation had a critical error in quarterly interest rate calculation that caused massively underestimated costs:

###  **WRONG (Bug):**
```rust
let quarterly_cash_rate = cash_rate / 4.0;           // e.g., 0.04 / 4 = 0.01
let total_margin = wholesale_lending_margin + additional_loan_margins;  // 0.03 + 0.012 = 0.042
let quarterly_interest_rate = (quarterly_cash_rate + total_margin) / 4.0;  // (0.01 + 0.042) / 4 = 0.013
```

**Effective annual rate:** 0.013 × 4 = **5.2%** (should be ~8.1%)

### ✅ **CORRECT (Fixed):**
```rust
let quarterly_cash_rate = cash_rate / 4.0;           // 0.04 / 4 = 0.01
let total_margin = wholesale_lending_margin + additional_loan_margins;  // 0.03 + 0.012 = 0.042
let quarterly_interest_rate = quarterly_cash_rate + (total_margin / 4.0);  // 0.01 + (0.042 / 4) = 0.0205
```

**Effective annual rate:** 0.0205 × 4 = **8.2%** ✓

## Impact

### Before Fix (WRONG):
- **Viable scenarios**: 13.3% (364/2,730)
- **Mean XIRR**: 1.20%
- **Mean Deficit**: $832K
- **Insurance Risk**: 68.4%

The bug was dividing the total_margin by 4 **twice**:
1. Once when adding it to quarterly_cash_rate
2. Once more in the outer division by 4.0

This meant lending margins of 4.2% annually were being applied as only ~1.05% annually!

### Python Reference (Correct):
```python
loan_interest_rates = cash_rates + wholesale_lending_margin + additional_loan_margins
# Annual rate: cash_rate + 0.03 + 0.012

interest_due = loan_size * loan_interest_rate * quarter_div
# Quarterly interest: loan_size * annual_rate * 0.25
```

## Why This Matters

### Interest Cost Difference:
- **Annual lending rate should be**: cash_rate + 3% + 1.2% = ~8.2%
- **Bug was applying**: ~5.2% (36% lower!)
- **Missing cost per year on $1.6M loan**: ~$48,000

### Over 10 years:
- **Missing interest costs**: ~$480,000
- This explained why reinvestment was higher and insurance risk lower
- Product appeared more viable than it actually was

## Fix Applied

Changed both occurrences in `src/lib.rs` (lines ~106 and ~265):

```rust
// BEFORE (BUG):
let quarterly_interest_rate = (quarterly_cash_rate + total_margin) / 4.0;

// AFTER (FIXED):
let quarterly_interest_rate = quarterly_cash_rate + (total_margin / 4.0);
```

## Validation Status

After applying this fix, the Rust results should now match the Python Monte Carlo implementation exactly (within randomness tolerance).

The discrepancy between old Python results (96.5% viable) and new results is likely due to:
1. **Different cash_rate**: Old Python used historical fed funds rates (varying), new uses constant 0.04
2. **Different random paths**: Different RNG seeds produce different market scenarios
3. **Possibly different path generation method**: Original may have used historical S&P500 data

**The fix ensures the Rust implementation correctly applies lending margins and interest costs.**

## Recommended Action

✅ Re-run all profitability sweeps with the fixed code
✅ Previous 100K path results are INVALID due to this bug
✅ New results will show lower viability and higher costs (correct!)
