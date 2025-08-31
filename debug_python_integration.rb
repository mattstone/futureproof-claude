#!/usr/bin/env ruby

require_relative 'config/environment'

# Test parameters
TEST_PARAMS = {
  house_value: 1500000,
  loan_duration: 30,
  annuity_duration: 15,
  loan_type: 'Interest only',
  loan_to_value: 0.8,
  annual_income: 30000,
  start_year: 2000,
  insurer_profit_margin: 0.5,
  wholesale_lending_margin: 0.02,
  additional_loan_margins: 0.015,
  holiday_enter_fraction: 1.35,
  holiday_exit_fraction: 1.95,
  subperform_loan_threshold_quarters: 6,
  insurance_cost_pa: 0.02,
  hedged: false,
  hedging_max_loss: 0.1,
  hedging_cap: 0.2,
  hedging_cost_pa: 0.01
}

puts "=== PYTHON DEBUG TEST ==="

# Create a simple Python script
python_script = <<~PYTHON
  import sys
  import os
  print("Python script starting...")
  print("Current directory:", os.getcwd())
  print("Python path:", sys.path)
  
  try:
      import json
      print("JSON module imported successfully")
      
      import pandas as pd
      print("Pandas imported successfully")
      
      import numpy as np
      print("Numpy imported successfully")
      
      from core_model_advanced import single_mortgage, accounts_table
      print("Core model imported successfully")
      
      from utils import mean_sd, dollar, pcntdf, pcnt, secant
      print("Utils imported successfully")
      
      # Simple calculation
      output = {"test": "success", "params": #{TEST_PARAMS.to_json}}
      print(json.dumps(output))
      
  except ImportError as e:
      print("Import error:", str(e))
  except Exception as e:
      print("General error:", str(e))
PYTHON

# Write to python directory
python_dir = Rails.root.join('python')
debug_file = python_dir.join('debug_test.py')

File.write(debug_file, python_script)

puts "Created debug script: #{debug_file}"
puts "Running Python script..."

# Run the script and capture output
output = `cd #{python_dir} && python3 debug_test.py 2>&1`

puts "=== PYTHON OUTPUT ==="
puts output
puts "=== END OUTPUT ==="

# Check for JSON
json_line = output.split("\n").find { |line| line.strip.start_with?('{') }

if json_line
  puts "\n✅ Found JSON output:"
  puts json_line
  
  begin
    result = JSON.parse(json_line)
    puts "✅ JSON parsed successfully:"
    puts result.inspect
  rescue JSON::ParserError => e
    puts "❌ JSON parsing failed: #{e.message}"
  end
else
  puts "\n❌ No JSON found in output"
end

# Clean up
File.delete(debug_file) if File.exist?(debug_file)

puts "\n=== DEBUG COMPLETE ==="