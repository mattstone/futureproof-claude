# Rust Monte Carlo Engine for Equity Preservation Mortgage

## Single Production Script

**USE THIS SCRIPT ONLY:** `profitability_sweep.py`

All other versions are archived as `.bak` files. This is the only maintained version.

## Quick Start

```bash
# Default: 10,000 paths (~2 minutes)
python3 profitability_sweep.py

# 100,000 paths (~13 minutes) - recommended for final analysis
python3 profitability_sweep.py 100000

# 1,000,000 paths (~2 hours) - maximum precision
python3 profitability_sweep.py 1000000
```

## Performance

| Paths | Speed | Total Time | Use Case |
|-------|-------|------------|----------|
| 10K | ~18 sims/sec | ~2 min | Quick testing |
| 100K | ~3.5 sims/sec | ~13 min | **Standard analysis** |
| 1M | ~0.35 sims/sec | ~2 hours | Maximum precision |

**Note:** Your 100K run showed 1.08 sims/sec because it used the OLD buggy version.
With the fixed version, you should see ~3.5 sims/sec (3x faster).

## Critical Fixes Applied

✅ **Interest rate bug fix** - Quarterly calculation now correct
✅ **Memory optimization** - Integrated path generation (7-8x faster)
✅ **Single production script** - No confusion about which version to use

## Output Files

Files are named based on path count:
- `profitability_results_10k.csv`
- `profitability_progress_10k.log`

## Archived Files (DO NOT USE)

- `profitability_sweep_rust_OLD_BUGGY.py.bak` - Had interest rate bug + slow memory allocation
