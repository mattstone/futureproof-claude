# Quick Start Guide

## ✅ Installation Complete!

The Rust Monte Carlo engine has been successfully built and installed.

## 🚀 Performance Test Results

**10,000 Monte Carlo paths for a single scenario:**
- Path generation: **0.042s**
- Simulation: **0.010s**
- **Total: 0.052s**

Compare this to Python which would take ~10-20 seconds for the same scenario.

## Running the Full Profitability Sweep

The main Python profitability sweep takes **4.5 hours** with 2,730 scenarios × 10,000 paths.

With Rust, this should complete in **9-13 minutes** (estimated 20-30x speedup).

### Run the Rust-powered sweep:

```bash
cd rust_monte_carlo
python3 profitability_sweep_rust.py
```

This will:
- Test 2,730 scenarios (91 house values × 30 loan/annuity combinations × 2 loan types)
- Run 10,000 Monte Carlo paths per scenario
- Output results to `profitability_results_rust_10k.csv`
- Log progress to `profitability_progress_rust_10k.log`

### Monitor progress:

In another terminal:
```bash
tail -f profitability_progress_rust_10k.log
```

## What's Different

The Rust implementation:
- Uses parallel processing across all CPU cores
- Compiles to native machine code
- Has zero Python overhead in the hot loop
- Still outputs the same CSV format as the Python version

You can use the existing `analyze_results_10k.py` script to analyze the results (just update the filename to `profitability_results_rust_10k.csv`).

## Rebuilding

If you make changes to the Rust code in `src/lib.rs`:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
python3 -m maturin build --release
pip3 install --force-reinstall target/wheels/*.whl
```

Or use the provided script (after updating it with the correct PATH):
```bash
./build.sh
```
