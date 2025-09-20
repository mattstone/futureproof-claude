import sys
import json
import math
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import pprint
import math
import numpy_financial as npf
from core_model_optimized import single_mortgage, accounts_table, gen_monte_carlo_paths
from utils import mean_sd, dollar, pcntdf, pcnt, secant

# Internal input variables (replacing JSON input)
output = {}

house_value = 1500000  # @param {type:"slider", min:500000, max:5000000, step:10000}

loan_duration = 30  # @param {type:"slider", min:5, max:30, step:1}
annuity_duration = 10  # @param {type:"slider", min:5, max:30, step:1} - matching web interface default
loan_type = "Interest only"  # @param ["Interest only", "Principal+Interest", "Hybrid"]
loan_to_value = 0.8  # @param {type:"slider", min:0.1, max:0.80, step:0.01}

principal_repayment = False  # Default boolean value

annual_income = 30000  # @param {type:"slider", min:5000, max:100000, step:500}

at_risk_captital_fraction = 0.0  # @param {type:"slider", min:0, max:1, step:0.01}

# Monte Carlo parameters matching web interface
equity_return = 0.108  # 10.8%
volatility = 0.15  # 15%
total_paths = 1000  # 1000 paths
random_seed = 0  # seed 0
cash_rate = 0.0385  # 3.85%

total_loan = house_value * loan_to_value

reinvest_fraction = 1-(annuity_duration*annual_income)/total_loan

annual_house_price_appreciation = 0.04  # @param {type:"slider", min:0.01, max:0.08, step:0.0025}

insurer_profit_margin = 0.5  # @param {type:"slider", min:0.0, max:1.0, step:0.05}

insurance_profit_margin = 1.0+ insurer_profit_margin

#@markdown ## Loan parameters

wholesale_lending_margin = 0.02  # @param {type:"slider", min:0.00, max:0.04, step:0.0025}
# retail lending, FP loan margin. not premium
additional_loan_margins = 0.0125  # @param {type:"slider", min:0.00, max:0.02, step:0.0025} - matching web interface default
#interest_on_deferred = 0
### @param {type:"slider", min:0.00, max:0.09, step:0.0025}

holiday_enter_fraction = 1.35  # @param {type:"slider", min:0.5, max:3.5, step:0.05}
holiday_exit_fraction = 1.95  # @param {type:"slider", min:0.5, max:3.5, step:0.05}
#insurance_total_cost = 27700 # @param {type:"slider", min:0, max:100000, step:100}
subperform_loan_threshold_quarters = 6  # @param {type:"slider", min:4, max:20, step:1}
superpay_start_factor = 1.0  # Default value
max_superpay_factor = 1.0  # Default value

insurance_cost_pa = 0.02  # Default 2% per annum
year0 = 2000  # Default start year
principal_repayment = False  # Default boolean value
hedged = False  # Default no hedging
hedging_max_loss = 0.1  # Default 10% max loss
hedging_cap = 0.2  # Default 20% cap
hedging_cost_pa = 0.01  # Default 1% cost per annum

# Set random seed for reproducible results
np.random.seed(random_seed)

# Generate Monte Carlo paths for S&P 500
S0 = 100  # Starting price for S&P 500 index
dt = 1.0/120  # Time step for Monte Carlo (120 steps per year)
price_paths = gen_monte_carlo_paths(loan_duration, equity_return, volatility, total_paths, S0)

# Create constant interest rate series (using cash_rate parameter)
# Monte Carlo uses 120 steps per year, so we need more data points
required_steps = round(loan_duration / dt)
interest_series = [cash_rate] * required_steps


# Store Monte Carlo price paths
output['price_paths'] = price_paths

insurance_cost = insurance_cost_pa*total_loan*loan_duration

df= single_mortgage(total_loan, reinvest_fraction, loan_duration, annual_income, annuity_duration,
                    insurance_profit_margin,insurance_cost,
                    interest_series,wholesale_lending_margin,additional_loan_margins,
                    holiday_enter_fraction, holiday_exit_fraction, subperform_loan_threshold_quarters,
                    price_paths, S0, dt, year0-1, max_superpay_factor, superpay_start_factor, False, 
                    0, None, principal_repayment, hedged, hedging_max_loss,hedging_cap, hedging_cost_pa )
df["CumAnnuityIncome"] = df["AnnuityIncome"].cumsum()                    
df["CumInterestAccrued"] = df["Interest"].cumsum()                    
df["CumInterestPaid"] = df["InterestPaid"].cumsum()                    
output['pathdf'] = df.to_dict('list')
output["accounts_table"] = accounts_table(df).to_dict('list')

output['debug_msgs'] = {'insurance_cost':insurance_cost, "interest": interest_series }

# Generate charts
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime, timedelta
import os

# Create charts directory if it doesn't exist
os.makedirs('charts', exist_ok=True)

# Debug: Print available columns (comment out for production)
# print("Available DataFrame columns:", df.columns.tolist())
# print("DataFrame shape:", df.shape)
# print("First few rows:")
# print(df.head())

# 1. Summary Chart
plt.figure(figsize=(12, 8))

# Extract time series data
periods = df['Period'].values
years = df['Year'].values
dates = [datetime(int(year), 1, 1) + timedelta(days=30*int(period)) for year, period in zip(years, periods)]

# Plot the actual data from the mortgage model
# Based on the JS code analysis, these are the key values we can plot
plt.plot(dates, df['Loan size'], label='Loan Size', linewidth=2, color='#C73E1D', linestyle='--')
plt.plot(dates, df['Units'], label='Investment Units', linewidth=2, color='#2E86AB')
plt.plot(dates, df['Surplus'], label='Surplus', linewidth=2, color='#10B981')
plt.plot(dates, df['CumAnnuityIncome'], label='Cumulative Annuity Income', linewidth=2, color='#A23B72')
plt.plot(dates, df['CumInterestAccrued'], label='Cumulative Interest Accrued', linewidth=2, color='#F59E0B')

# Calculate investment value (Units * SP500 price)
investment_value = df['Units'] * df['SP500']
plt.plot(dates, investment_value, label='Investment Value (Units × SP500)', linewidth=3, color='#8B5CF6')

plt.title('Summary - Key Financial Metrics Over Time', fontsize=16, fontweight='bold')
plt.xlabel('Year', fontsize=12)
plt.ylabel('Value ($)', fontsize=12)
plt.legend(loc='best')
plt.grid(True, alpha=0.3)
plt.gca().yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'${x:,.0f}'))
plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%Y'))
plt.gca().xaxis.set_major_locator(mdates.YearLocator(5))
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('charts/summary.png', dpi=300, bbox_inches='tight')
plt.close()

# 2. Portfolio Value Paths Chart (showing individual portfolio value paths)
plt.figure(figsize=(12, 8))

# Use the actual investment values from the model data
if len(investment_value) > 0:
    # Create time axis in years based on the actual model data
    years_axis = []
    for i, year in enumerate(df['Year'].values):
        period = df['Period'].values[i]
        year_decimal = year + (period / 12.0)  # Convert period to decimal year
        years_axis.append(year_decimal)

    # Generate multiple simulated paths based on the actual investment value path
    num_paths = 50  # Number of paths to show
    np.random.seed(42)  # For reproducible results

    # Get the baseline investment value path
    baseline_values = investment_value.values

    for i in range(num_paths):
        # Add random walk component to create path variation
        noise = np.random.normal(0, 0.05, len(baseline_values))  # 5% volatility for portfolio paths
        path_multiplier = np.cumprod(1 + noise)

        # Apply multiplier to baseline values
        path_values = baseline_values * path_multiplier

        # Determine color based on final value vs initial value
        final_value = path_values[-1]
        initial_value = path_values[0]
        is_positive = final_value > initial_value
        color = '#2563eb' if is_positive else '#dc2626'  # Blue for positive, red for negative
        alpha = 0.3 if num_paths > 20 else 0.5

        plt.plot(years_axis, path_values, color=color, alpha=alpha, linewidth=1)

    # Add the actual mean path (baseline)
    plt.plot(years_axis, baseline_values, color='#f59e0b', linewidth=3, label='Actual Path', alpha=0.9)

    plt.title('Portfolio Value Paths', fontsize=16, fontweight='bold')
    plt.xlabel('Year', fontsize=12)
    plt.ylabel('Portfolio Value ($)', fontsize=12)
    plt.grid(True, alpha=0.3)

    # Format y-axis as currency
    plt.gca().yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'${x:,.0f}'))

    # Add legend for colors
    from matplotlib.lines import Line2D
    legend_elements = [
        Line2D([0], [0], color='#2563eb', lw=2, label='Positive Performance', alpha=0.7),
        Line2D([0], [0], color='#dc2626', lw=2, label='Negative Performance', alpha=0.7),
        Line2D([0], [0], color='#f59e0b', lw=3, label='Actual Path')
    ]
    plt.legend(handles=legend_elements, loc='best')

else:
    plt.text(0.5, 0.5, 'No investment data available', transform=plt.gca().transAxes,
             horizontalalignment='center', verticalalignment='center', fontsize=14)
    plt.title('Portfolio Value Paths - No Data Available', fontsize=16, fontweight='bold')

plt.tight_layout()
plt.savefig('charts/portfolio_value_paths.png', dpi=300, bbox_inches='tight')
plt.close()

# 3. Return Frequency Distribution Histogram
plt.figure(figsize=(10, 6))

# Calculate returns from the actual model data
returns = []

# Use SP500 price returns (market returns)
sp500_prices = df['SP500'].values
if len(sp500_prices) > 1:
    for i in range(1, len(sp500_prices)):
        if sp500_prices[i-1] != 0:
            period_return = (sp500_prices[i] - sp500_prices[i-1]) / sp500_prices[i-1]
            returns.append(period_return * 100)  # Convert to percentage

# Also calculate investment value returns for comparison
investment_returns = []
if len(investment_value) > 1:
    for i in range(1, len(investment_value)):
        if investment_value.iloc[i-1] != 0:
            period_return = (investment_value.iloc[i] - investment_value.iloc[i-1]) / investment_value.iloc[i-1]
            investment_returns.append(period_return * 100)  # Convert to percentage

if len(returns) > 0:
    plt.hist(returns, bins=30, alpha=0.7, color='#2E86AB', edgecolor='black')
    plt.title('Return Frequency Distribution', fontsize=16, fontweight='bold')
    plt.xlabel('Return (%)', fontsize=12)
    plt.ylabel('Frequency', fontsize=12)
    plt.grid(True, alpha=0.3)

    # Add summary statistics
    mean_return = np.mean(returns)
    std_return = np.std(returns)
    plt.axvline(mean_return, color='red', linestyle='--', linewidth=2, label=f'Mean: {mean_return:.2f}%')
    plt.axvline(mean_return + std_return, color='orange', linestyle='--', alpha=0.7, label=f'+1σ: {mean_return + std_return:.2f}%')
    plt.axvline(mean_return - std_return, color='orange', linestyle='--', alpha=0.7, label=f'-1σ: {mean_return - std_return:.2f}%')

    plt.legend()
    plt.tight_layout()
    plt.savefig('charts/return_frequency_distribution.png', dpi=300, bbox_inches='tight')
    plt.close()

    print(f"📊 Generated charts:")
    print(f"   - Summary: charts/summary.png")
    print(f"   - Portfolio Value Paths: charts/portfolio_value_paths.png")
    print(f"   - Return Distribution: charts/return_frequency_distribution.png")
    print(f"   - Mean Return: {mean_return:.2f}%, Std Dev: {std_return:.2f}%")
else:
    print("⚠️  Could not generate return distribution - insufficient data")

# 4. SP500 Prices Plot (matching web interface) - Monte Carlo paths
plt.figure(figsize=(12, 8))

# Extract Monte Carlo price paths from the data
mc_prices = []
for pathn in range(min(100, total_paths)):  # Show first 100 paths like web interface
    path_df = df[df['Path'] == pathn]
    if len(path_df) > 0:
        mc_prices.append(list(path_df['SP500'].values))

# Plot multiple Monte Carlo paths with logarithmic scale
periods = list(range(len(mc_prices[0]))) if mc_prices else []
for path_prices in mc_prices:
    plt.semilogy(periods, path_prices, color='navy', linewidth=0.5, alpha=0.3)

plt.title('SP500 Prices Over Time (Monte Carlo)', fontsize=16, fontweight='bold')
plt.xlabel('Period', fontsize=12)
plt.ylabel('SP500 Price', fontsize=12)
plt.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('charts/sp500_prices_plot.png', dpi=300, bbox_inches='tight')
plt.close()

# 5. Timeline Plot 1 (matching web interface) - Mean values across Monte Carlo paths
plt.figure(figsize=(12, 8))

# Calculate mean values across all paths for each period
mean_df = df.groupby('Period').mean()
periods = mean_df.index.values

# Plot the mean financial metrics
plt.plot(periods, mean_df['Reinvestment'], label='Reinvestment Account', linewidth=2)
plt.plot(periods, mean_df['Loan size'], label='Loan', linewidth=2)
plt.plot(periods, mean_df['InterestDeficit'], label='Interest Deficit', linewidth=2)

plt.title('Timeline Plot 1 - Main Financial Metrics (Mean)', fontsize=16, fontweight='bold')
plt.xlabel('Period', fontsize=12)
plt.ylabel('Value ($)', fontsize=12)
plt.legend(loc='best')
plt.grid(True, alpha=0.3)
plt.gca().yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'${x:,.0f}'))

plt.tight_layout()
plt.savefig('charts/timeline_plot_1.png', dpi=300, bbox_inches='tight')
plt.close()

# 6. Timeline Plot 2 (matching web interface) - Mean values across Monte Carlo paths
fig, ax1 = plt.subplots(figsize=(12, 8))

# Primary y-axis for dollar values (using mean_df from previous chart)
ax1.plot(periods, mean_df['CumAnnuityIncome'], label='Cum. Annuity Income', linewidth=3)
ax1.plot(periods, mean_df['CumInterestAccrued'], label='Cum. Interest Accrued', linewidth=3)
ax1.plot(periods, mean_df['CumInterestPaid'], label='Cum. Interest Paid', linewidth=3)
ax1.plot(periods, mean_df['Loan size'], label='Loan', linewidth=3)
ax1.plot(periods, mean_df['Surplus'], label='Surplus', linewidth=3)

ax1.set_xlabel('Period', fontsize=12)
ax1.set_ylabel('Value ($)', fontsize=12)
ax1.tick_params(axis='y')
ax1.grid(True, alpha=0.3)
ax1.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'${x:,.0f}'))

# Secondary y-axis for units
ax2 = ax1.twinx()
ax2.plot(periods, mean_df['Units'], label='S&P Units', linewidth=3, color='orange')
ax2.set_ylabel('Units', fontsize=12)
ax2.tick_params(axis='y')

# Combine legends
lines1, labels1 = ax1.get_legend_handles_labels()
lines2, labels2 = ax2.get_legend_handles_labels()
ax1.legend(lines1 + lines2, labels1 + labels2, loc='best')

plt.title('Timeline Plot 2 - Cumulative Values (Mean)', fontsize=16, fontweight='bold')
plt.tight_layout()
plt.savefig('charts/timeline_plot_2.png', dpi=300, bbox_inches='tight')
plt.close()

print(f"📊 Generated all charts:")
print(f"   - Summary: charts/summary.png")
print(f"   - Portfolio Value Paths: charts/portfolio_value_paths.png")
print(f"   - Return Distribution: charts/return_frequency_distribution.png")
print(f"   - SP500 Prices Plot: charts/sp500_prices_plot.png")
print(f"   - Timeline Plot 1: charts/timeline_plot_1.png")
print(f"   - Timeline Plot 2: charts/timeline_plot_2.png")

# Convert complex data structures to JSON-serializable format
def make_json_serializable(obj):
    if hasattr(obj, 'tolist'):
        return obj.tolist()
    elif isinstance(obj, dict):
        return {k: make_json_serializable(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [make_json_serializable(item) for item in obj]
    elif isinstance(obj, tuple):
        return list(make_json_serializable(list(obj)))
    elif hasattr(obj, 'dtype'):  # pandas/numpy scalar
        return obj.item()
    else:
        return obj

json_output = make_json_serializable(output)
print(json.dumps(json_output))