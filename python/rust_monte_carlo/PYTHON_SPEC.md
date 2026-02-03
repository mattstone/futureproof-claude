# Python Implementation Specification

## Critical Findings

### 1. Initial Loan Size Calculation
```python
loan_size = total_loan * reinvest_fraction + annual_income_quarter
```
**NOT** just `total_loan`! The loan size STARTS higher because of first annuity payment.

### 2. Annuity Payment Handling
After each quarter's calculations (line 322-326):
```python
if t < annuity_duration_quarters:
    if piProgressiveRepayment:
        holdings -= units_to_principal  # Sell units to pay principal
    else:
        loan_size += annual_income_quarter  # INCREASE loan size!
```

**Key**: Unless using progressive repayment, the loan size GROWS by annuity amount each quarter!

### 3. Holiday Logic
Initialization (line 167):
```python
in_holiday = holiday_enter_fraction > 1  # True if 1.35 > 1
```

In loop (lines 220-255):
```python
if in_holiday:
    if holdings_value > holiday_exit:  # Exit if above 195% threshold
        in_holiday = False
        holdings -= interest_due_per_share  # PAY interest
        interest_paid = interest_due
        holiday_quarters = 0
    else:
        holiday_quarters += 1  # Stay on holiday
        deferred += interest_due  # DON'T pay interest
else:  # Not on holiday
    if holdings_value < holiday_enter:  # Re-enter if below 135%
        deferred += interest_due
        in_holiday = True
        holiday_quarters += 1
    else:  # Normal operation
        holiday_quarters = 0
        holdings -= interest_due_per_share  # PAY interest
        interest_paid = interest_due
```

### 4. Interest Calculation
```python
interest_due = loan_size * loan_interest_rate * quarter_div
```
Where `loan_interest_rate = cash_rate + wholesale_margin + additional_margins`

**Key**: Interest is on `loan_size` which CHANGES every quarter (grows with annuity payments)!

### 5. Hedging Logic (lines 271-289)
```python
if hedged:
    if t % 4 == 0:  # Every year
        holdings -= holdings * hedging_cost_pa  # Deduct cost
        year_move = (s - last_yearly_hedge_price) / last_yearly_hedge_price
        if year_move < -hedging_max_loss:  # If down > 20%
            # Buy units to limit loss to 20%
            buy_units = ((last_yearly_hedge_price / s) * (1 - hedging_max_loss) - 1) * holdings
            holdings += buy_units
        last_yearly_hedge_price = s

    if t % 20 == 0:  # Every 5 years
        year_move = (s - last_5yearly_hedge_price) / last_5yearly_hedge_price
        adj_holds = holdings * (last_5yearly_hedge_price / s) * (1 + hedging_cap * 5)
        if holdings > adj_holds:  # If up too much, sell excess
            sell_units = holdings - adj_holds
            holdings -= sell_units
        last_5yearly_hedge_price = s
```

### 6. Variable Naming Differences
| Python | Rust Equivalent | Notes |
|--------|----------------|-------|
| `holdings` | `sp500_units` | Number of S&P500 units owned |
| `holdings_value` | `reinvestment` | Dollar value of holdings |
| `deferred` | `cum_interest_deficit` | Cumulative unpaid interest |
| `in_holiday` | `on_holiday` | Boolean holiday state |
| `holiday_enter` | `holiday_enter_threshold` | 135% threshold |
| `holiday_exit` | `holiday_exit_threshold` | 195% threshold |
| `loan_size` | ??? | **MISSING IN RUST** |

## Critical Missing Features in Rust

1. ❌ `loan_size` variable that grows with annuity payments
2. ❌ Annual hedging rebalance (buy on drops > 20%)
3. ❌ 5-year hedging cap (sell on gains > cap)
4. ❌ Correct initial loan_size calculation
5. ❌ Interest calculated on growing loan_size, not fixed total_loan

## Why Rust Results Are Wrong

1. **Interest too low**: Rust calculates on fixed `total_loan` ($800K), but Python calculates on growing `loan_size` (starts at $803,750 and grows!)

2. **Customer never exits holiday**: Because Rust doesn't properly track changing values

3. **Missing hedging protection**: Portfolio should rebalance on large moves

## Required Rust Changes

Must add:
- `loan_size` variable initialized to `total_loan * reinvest_fraction + quarterly_income`
- Interest calculation using `loan_size` not `total_loan`
- After each quarter: `loan_size += quarterly_income` (unless progressive repayment)
- Proper hedging logic with yearly and 5-yearly rebalancing
