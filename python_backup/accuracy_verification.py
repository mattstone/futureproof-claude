import json
import numpy as np
import sys

def compare_monte_carlo_results(baseline_file, test_file, tolerance=1e-10):
    """
    Comprehensive comparison of Monte Carlo results ensuring numerical accuracy
    """
    
    with open(baseline_file, 'r') as f:
        baseline = json.load(f)
    
    with open(test_file, 'r') as f:
        test_data = json.load(f)
    
    print("=== MONTE CARLO ACCURACY VERIFICATION ===")
    
    # Check basic structure
    errors = []
    
    if baseline['total_paths'] != test_data['total_paths']:
        errors.append(f"Path count mismatch: {baseline['total_paths']} vs {test_data['total_paths']}")
    
    # Compare aggregate metrics
    aggregate_checks = [
        'mean_final_reinvestment', 'std_final_reinvestment',
        'mean_final_deficit', 'std_final_deficit', 
        'total_holiday_quarters', 'pct_quarters_on_holiday',
        'total_interest_paid', 'mean_interest_per_path'
    ]
    
    print("Aggregate Metrics Comparison:")
    max_relative_error = 0
    
    for metric in aggregate_checks:
        if metric in baseline and metric in test_data:
            baseline_val = float(baseline[metric])
            test_val = float(test_data[metric])
            
            abs_diff = abs(baseline_val - test_val)
            rel_diff = abs_diff / max(abs(baseline_val), 1e-15) * 100
            max_relative_error = max(max_relative_error, rel_diff)
            
            status = "✅" if abs_diff < tolerance else "❌"
            print(f"  {metric}: diff={abs_diff:.2e}, rel_diff={rel_diff:.2e}% {status}")
            
            if abs_diff >= tolerance:
                errors.append(f"{metric}: difference {abs_diff:.2e} exceeds tolerance {tolerance:.2e}")
    
    # Compare path-by-path details
    print("\\nPath-by-Path Verification:")
    if 'path_details' in baseline and 'path_details' in test_data:
        baseline_paths = {p['path']: p for p in baseline['path_details']}
        test_paths = {p['path']: p for p in test_data['path_details']}
        
        path_errors = 0
        for path_id in baseline_paths:
            if path_id not in test_paths:
                errors.append(f"Missing path {path_id} in test data")
                continue
                
            b_path = baseline_paths[path_id]
            t_path = test_paths[path_id]
            
            path_checks = ['final_reinvestment', 'final_deficit', 'final_surplus', 
                          'total_interest_paid', 'holiday_quarters']
            
            for check in path_checks:
                if check in b_path and check in t_path:
                    b_val = float(b_path[check])
                    t_val = float(t_path[check])
                    diff = abs(b_val - t_val)
                    
                    if diff >= tolerance:
                        path_errors += 1
                        if path_errors <= 5:  # Show first 5 errors
                            errors.append(f"Path {path_id} {check}: diff {diff:.2e}")
        
        if path_errors == 0:
            print(f"  All {len(baseline_paths)} paths match exactly ✅")
        else:
            print(f"  {path_errors} path-level differences found ❌")
    
    # Compare time series data
    print("\\nTime Series Verification:")
    if 'quarterly_reinvestments' in baseline and 'quarterly_reinvestments' in test_data:
        b_series = np.array(baseline['quarterly_reinvestments'])
        t_series = np.array(test_data['quarterly_reinvestments'])
        
        max_series_diff = np.max(np.abs(b_series - t_series))
        if max_series_diff < tolerance:
            print(f"  Quarterly reinvestments match exactly ✅")
        else:
            print(f"  Quarterly reinvestments max diff: {max_series_diff:.2e} ❌")
            errors.append(f"Time series difference: {max_series_diff:.2e}")
    
    # Performance comparison
    print("\\nPerformance Comparison:")
    if 'performance' in baseline and 'performance' in test_data:
        b_perf = baseline['performance']
        t_perf = test_data['performance']
        
        if 'simulation_time' in b_perf and 'simulation_time' in t_perf:
            speedup = float(b_perf['simulation_time']) / float(t_perf['simulation_time'])
            print(f"  Speedup: {speedup:.2f}x ({b_perf['simulation_time']:.3f}s → {t_perf['simulation_time']:.3f}s)")
        
        if 'paths_per_second' in t_perf:
            print(f"  New performance: {t_perf['paths_per_second']:.1f} paths/second")
    
    # Final verdict
    print("\\n" + "="*50)
    if len(errors) == 0:
        print("🎉 ALL ACCURACY TESTS PASSED!")
        print(f"Maximum relative error: {max_relative_error:.2e}%")
        return True
    else:
        print(f"❌ {len(errors)} ACCURACY ERRORS DETECTED:")
        for i, error in enumerate(errors[:10], 1):  # Show first 10 errors
            print(f"  {i}. {error}")
        if len(errors) > 10:
            print(f"  ... and {len(errors) - 10} more errors")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python accuracy_verification.py baseline.json test.json")
        sys.exit(1)
    
    baseline_file = sys.argv[1]
    test_file = sys.argv[2]
    
    success = compare_monte_carlo_results(baseline_file, test_file)
    sys.exit(0 if success else 1)