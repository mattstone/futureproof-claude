#!/bin/bash
# Run 10K Monte Carlo profitability sweep
# This will take approximately 2-4 hours depending on your machine

echo "=========================================="
echo "10K MONTE CARLO PROFITABILITY SWEEP"
echo "=========================================="
echo ""
echo "This will run 2,650 scenarios with 10,000 Monte Carlo paths each"
echo "Estimated time: 2-4 hours"
echo ""
echo "Progress will be logged to: profitability_progress_10k.log"
echo "Results will be saved to: profitability_results_10k.csv"
echo ""
echo "You can monitor progress in another terminal with:"
echo "  tail -f profitability_progress_10k.log"
echo ""
echo "Press Ctrl+C to cancel, or wait 5 seconds to start..."
sleep 5

echo ""
echo "Starting sweep..."
python3 profitability_sweep_10k.py

echo ""
echo "=========================================="
echo "SWEEP COMPLETE!"
echo "=========================================="
echo ""
echo "Running analysis..."
python3 analyze_results_10k.py

echo ""
echo "All done! Results are in:"
echo "  - profitability_results_10k.csv (detailed results)"
echo "  - profitability_summary_10k.txt (summary)"
echo "  - profitability_progress_10k.log (execution log)"
