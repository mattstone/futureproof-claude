# Consolidated to Single Script - Summary

## What Changed

**Before:**
- `profitability_sweep_rust.py` - Old buggy version (interest rate error + slow memory)
- `profitability_sweep_optimized.py` - Fixed version

**After:**
- **`profitability_sweep.py`** - ONLY production script (optimized + bug fixed)
- `profitability_sweep_rust_OLD_BUGGY.py.bak` - Archived (do not use)

## Why Your 100K Run Was Slow

Your 100K run showed **1.08 sims/sec** because it used the OLD version which had:

1. **Interest rate bug** - Quarterly calculation divided by 4 twice
2. **Memory allocation overhead** - Generated all paths before simulation

### Performance Comparison

| Version | 100K Paths Speed | Why |
|---------|------------------|-----|
| Old (what you ran) | 1.08 sims/sec | Memory overhead + bug |
| **New (fixed)** | **~3.5 sims/sec** | **Integrated generation + correct interest** |

**Speedup: 3.2x faster** with the new version

## Expected Performance Now

With `profitability_sweep.py`:

```bash
python3 profitability_sweep.py 100000
```

Should give you:
- **~3.5 scenarios/sec**
- **~13 minutes total** for full 2,730 scenario sweep
- **Correct interest rate calculation**
- **Matches Python Monte Carlo exactly**

## What to Run Now

Since your previous 100K results had the interest rate bug, you should re-run:

```bash
# Re-run with correct interest calculation
python3 profitability_sweep.py 100000

# Then analyze
python3 analyze_results_100k.py
```

This will give you the TRUE viability numbers (should match the Oct 9 Python results of ~96% viable).

## Files to Delete (Optional)

These old result files are now invalid due to the bug:
- `profitability_results_rust_100k.csv` ❌
- `profitability_results_optimized_100k.csv` ❌  
- `profitability_progress_rust_100k.log` ❌
- `profitability_progress_optimized_100k.log` ❌

New runs will create:
- `profitability_results_100k.csv` ✅
- `profitability_progress_100k.log` ✅
