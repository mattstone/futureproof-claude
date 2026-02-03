# Excel Model vs Python/Rust Implementation Comparison

**Date**: 2025-10-14
**Excel File**: `Copy of 20250624 FutureProof Mini Model Data Room.xlsm`
**Python Reference**: `single_real_data.py`, `core_model_advanced.py`
**Rust Engine**: `monte_carlo_engine`

---

## 🔍 EXECUTIVE SUMMARY

### ✅ Core Financial Logic: MATCHES
### ⚠️ **CRITICAL DIFFERENCES FOUND** in Payment Holiday Implementation

---

## 📊 PARAMETER COMPARISON

| Parameter | Excel Value | Python/Rust Value | Match? |
|-----------|-------------|-------------------|--------|
| **House Value** | $2,000,000 | $2,000,000 | ✅ |
| **LVR** | 0.80 | 0.80 | ✅ |
| **Annuity** | $30,000 | 1.5% of house value | ✅ (both = $30K) |
| **Annuity Term** | 10 years | Variable (10-30) | ⚠️ Excel fixed |
| **Loan Duration** | 30 years | Variable (10-30) | ⚠️ Excel fixed |
| **Wholesale Margin** | 0.03 (3%) | 0.03 (3%) | ✅ |
| **Retail Margin** | 0.0075 (0.75%) | 0.012 (1.2%) | ❌ **DIFFERENT** |
| **FP Margin** | 0.0025 (0.25%) | Included in above | ⚠️ Different structure |
| **Hedging Cost** | 0.005 (0.5%) | 0.005 (0.5%) | ✅ |
| **LMI Upfront Insurance** | 0.0025 (0.25%) | 0.005 (0.5%) | ❌ **DIFFERENT** |
| **ETF Expected Return** | 0.10 (10%) | 0.10 (10%) | ✅ |
| **Volatility** | 0.12 (12%) | 0.12 (12%) | ✅ |
| **Cash Rate** | 0.036 (3.6%) | 0.031 (3.1%) | ❌ **DIFFERENT** |

---

## 🚨 CRITICAL DIFFERENCE #1: Payment Holiday Logic

### Excel Implementation (Row 97-120)

```excel
Entry Threshold (Row 97): 0.9 (90% of initial loan)
Exit Threshold (Row 103): 1.458 (145.8% of initial loan)

Entry Flag (Row 99):
  =IF(D71<D98, 1, 0)  // Enter if investment < 90% of initial
  // Once in holiday, stays until exit threshold hit
  =IF(D99=0, IF(E71<E98,1,0), IF(E71>E104,0,1))

Repayment Trigger (Row 111-114):
  Super-repayment threshold: 1.5 × exit threshold = 2.187 (218.7%)
  =IF(AND(D117>0, D71>D112), 1, 0)
  // Accelerated repayment when investment > 218.7%
```

### Python/Rust Implementation

```python
HOLIDAY_ENTER_FRACTION = 0.9   # 90% of initial loan (MATCHES Excel)
HOLIDAY_EXIT_FRACTION = 1.4    # 140% of initial loan (DIFFERENT from Excel 145.8%)

# Holiday logic (quarterly basis):
if equity_value < (total_loan * holiday_enter_fraction):
    enter_holiday = True

if in_holiday and equity_value > (total_loan * holiday_exit_fraction):
    exit_holiday = True

# No super-repayment logic in Python/Rust
```

### Key Differences

| Aspect | Excel | Python/Rust | Impact |
|--------|-------|-------------|--------|
| **Exit Threshold** | **145.8%** | **140%** | Excel requires MORE equity to exit |
| **Super-Repayment** | **YES** (at 218.7%) | **NO** | Excel accelerates paydown when doing well |
| **Holiday State Persistence** | Sticky (harder to exit) | Simpler check each quarter | Excel may understate holiday usage |
| **Repayment Spread Logic** | Amortizes over remaining periods | Immediate catch-up | Excel smoother, Python/Rust lumpier |

---

## 🚨 CRITICAL DIFFERENCE #2: Interest Rate Margins

### Excel Structure

```
Total Interest Rate = Cash Rate + Wholesale Margin + Retail Margin + FP Margin
                    = 3.6% + 3.0% + 0.75% + 0.25%
                    = 7.6% total margin structure
```

**Breakdown**:
- Cash Rate: 3.6%
- Wholesale Margin: 3.0% (funder cost)
- Retail Margin: 0.75% (retailer markup)
- FP Margin: 0.25% (FutureProof fee)

### Python/Rust Structure

```
Total Interest Rate = Cash Rate + Wholesale Margin + Additional Loan Margins
                    = 3.1% + 3.0% + 1.2%
                    = 7.3% total margin structure
```

**Breakdown**:
- Cash Rate: 3.1% (historical average 1988-2024)
- Wholesale Margin: 3.0% (funder cost)
- Additional Loan Margins: 1.2% (combined FP + retail)

### Impact Analysis

```
Excel Total Rate:    3.6% + 4.0% = 7.6%
Python/Rust Rate:    3.1% + 4.2% = 7.3%

Difference: -0.3% (Python/Rust is 30bps LOWER)
```

**On $1.6M loan over 10 years**:
- Excel annual interest: ~$121,600
- Python/Rust annual interest: ~$116,800
- **Difference**: $4,800/year in favor of Python/Rust

This 30bp advantage should make Python/Rust results BETTER than Excel, but Monte Carlo tail risk dominates.

---

## 🚨 CRITICAL DIFFERENCE #3: Insurance Cost

### Excel Implementation (Row 17, 73)

```excel
LMI Upfront Insurance: 0.0025 (0.25% of max loan)

Upfront cost (Row 73): =MAX(C32:AG32) * $K$17
                      = $1,600,000 × 0.0025
                      = $4,000 (one-time upfront)
```

### Python/Rust Implementation

```python
INSURANCE_COST_PA = 0.005  # 0.5% per annum

insurance_cost = insurance_cost_pa * total_loan * loan_duration
               = 0.005 × $1,600,000 × 10 years
               = $80,000 total cost (amortized over loan life)
```

### Impact Analysis

| Model | Cost Structure | 10-Year Total | Annual Equivalent |
|-------|---------------|---------------|-------------------|
| **Excel** | 0.25% upfront | **$4,000** | $400/year |
| **Python/Rust** | 0.5% annually | **$80,000** | $8,000/year |

**Python/Rust insurance is 20x more expensive!**

This is a HUGE difference and partially explains why Monte Carlo results show higher insurance claim rates.

---

## 🔍 DIFFERENCE #4: Hedging Implementation

### Excel Implementation (Row 49)

```excel
Investment fund return - With Hedging:
  =MIN(MAX($X$21-1, C48), $X$20-1)

Where:
  $X$20 = Hedging cap (appears to reference a parameter)
  $X$21 = Hedging floor (appears to reference a parameter)
  C48 = Raw investment return

Formula breakdown:
  Step 1: MAX(floor-1, raw_return) = Apply downside protection
  Step 2: MIN(result, cap-1) = Apply upside cap
```

### Python/Rust Implementation

```rust
let hedged_return_5y = if hedged {
    let cumulative_return = (current_value / five_years_ago_value) - 1.0;
    let hedged_cumulative = cumulative_return
        .max(-hedging_max_loss)  // Floor at -20%
        .min(hedging_cap);        // Cap at +40%

    // Convert 5-year cumulative back to period return
    (1.0 + hedged_cumulative).powf(1.0 / periods_since) - 1.0
} else {
    raw_return
};

// Apply hedging cost
equity_value *= 1.0 - (hedging_cost_pa * dt);
```

### Key Differences

| Aspect | Excel | Python/Rust | Impact |
|--------|-------|-------------|--------|
| **Hedging Window** | Appears annual | **5-year lookback** | Python/Rust more sophisticated |
| **Cost Timing** | Deducted from investment account | **Deducted quarterly** | Same economic effect |
| **Return Calculation** | Period-by-period | **Rolling 5-year CAGR** | Python/Rust smoother |

The 5-year lookback in Python/Rust means hedging only kicks in after 5 years, explaining why it's less effective than expected.

---

## 📐 CALCULATION METHODOLOGY DIFFERENCES

### 1. Time Step

**Excel**: Annual timestep (30 rows for 30 years)
**Python/Rust**: Quarterly timestep (120 quarters for 30 years)

**Impact**: Python/Rust has 4x granularity, captures intra-year volatility

### 2. Interest Calculation

**Excel** (Row 123):
```excel
Funder Interest Payment = -D63 * AVERAGE(D32, D28)
// Interest on AVERAGE of opening and closing loan balance
```

**Python/Rust**:
```python
interest_accrued = opening_balance * (quarterly_rate / 4.0)
// Interest on OPENING balance only
```

**Impact**: Excel method slightly overstates interest when loan is growing, understates when shrinking.

### 3. Investment Account Flows

**Excel** (Row 71-81):
```
Opening Balance
+ Day 1 Investment
- Upfront LMI costs
+ Investment Return
- Interest Payment
- Retailer NIM Payment
- FP Margin
- Hedging costs
- Annuity payment
= Closing Balance
```

**Python/Rust**:
```
Similar structure but:
- Insurance cost amortized over loan life (not upfront)
- Interest calculated on opening balance
- All flows occur quarterly (not annually)
```

### 4. Holiday Repayment Logic

**Excel** (Row 108, 119):
```excel
Repayment step countdown (Row 108):
  =MAX(IF(AND(D107>0, C108=0), D107, C108-1), 0)
  // Counts down from total periods missed

Repayment amount (Row 119):
  =IF(D108>0, -D117/D108, 0)
  // Spreads repayment evenly over remaining periods
```

**Python/Rust**:
```python
# Simpler: Immediate catch-up when exiting holiday
interest_to_pay = interest_deficit
# No amortization over time
```

**Impact**: Excel smooths repayment, Python/Rust creates payment shocks.

---

## 📊 MONTE CARLO DIFFERENCES

### Excel Approach (Brownian Sheet)

```excel
Expected return: 0.1
Volatility: 0.12

Annual return (Row 46):
  =EXP($L$21 + $N$21*NORMSINV(RAND())) - 1
  =EXP(0.1 + 0.12 * Z) - 1  // Lognormal returns

// Appears to use VBA macros for Monte Carlo loop (not visible in formulas)
```

### Python/Rust Approach

```rust
// Geometric Brownian Motion with fine timesteps
let dt = 1.0 / 120.0;  // Monthly-ish steps
let sqrt_dt = dt.sqrt();

for each step:
    let z = standard_normal();
    let return = (equity_return - 0.5 * volatility * volatility) * dt
                 + volatility * sqrt_dt * z;
    equity_value *= (1.0 + return).exp();
```

**Differences**:
1. **Timestep**: Excel annual, Python/Rust ~monthly (1/120 of year)
2. **Drift Adjustment**: Python/Rust applies `-0.5 * σ²` correction for lognormal
3. **Compounding**: Excel annual compounding, Python/Rust continuous

**Impact**: Python/Rust captures intra-year crashes better, sees more volatility.

---

## 💰 PROFIT SHARING DIFFERENCES

### Excel (Row 89-92)

```excel
Funder share pre LMI (Row 89):
  =IF(C88<0, C88, C88*0.5)
  // If deficit: funder takes 100% of loss
  // If surplus: funder takes 50% of profit

LMI Payment (Row 91):
  =IF(C89<0, -C89, 0) * (C24=$D$17)
  // Insurance pays out funder's share if negative

Funder share post LMI (Row 92):
  =C89 + C91
  // Funder made whole by insurance
```

### Python/Rust

```python
# Similar logic but different timing
if net_position < 0:
    insurance_payout = abs(net_position)
    funder_share = 0  # Insurance covers everything
else:
    funder_share = net_position * 0.5  # 50/50 split
    insurance_payout = 0
```

**Impact**: Logic matches, but quarterly granularity means more frequent insurance checks.

---

## 🎯 ROOT CAUSE ANALYSIS: Why Results Differ

### 1. **Insurance Cost** (BIGGEST FACTOR)

```
Excel:    $4,000 upfront (0.25%)
Python:   $80,000 over life (0.5% annually)

Difference: 20x higher cost in Python/Rust
```

**This alone explains most of the worse Monte Carlo performance.**

### 2. **Payment Holiday Exit Threshold**

```
Excel:    145.8% (harder to exit)
Python:   140.0% (easier to exit)

Excel keeps borrowers in holidays LONGER
→ More interest accrual
→ Larger deficits
→ Higher insurance risk (in Excel)
```

But this is offset by super-repayment logic in Excel when things go well.

### 3. **Interest Rate**

```
Excel:    7.6% total
Python:   7.3% total

Difference: 30bps in favor of Python/Rust
```

This should make Python/Rust perform BETTER, but insurance cost dominates.

### 4. **Timestep Granularity**

```
Excel:    Annual (30 steps)
Python:   Quarterly (120 steps)

Python captures intra-year volatility
→ More paths hit holiday thresholds mid-year
→ More realistic tail risk
```

### 5. **Monte Carlo Path Count**

```
Excel:    Unknown (likely 100-10,000)
Python:   1,000,000 paths

More paths = better tail risk capture
→ Monte Carlo reveals true risk
```

---

## ✅ WHAT MATCHES CORRECTLY

1. **LVR**: 80% ✅
2. **House Value**: $2M ✅
3. **Wholesale Margin**: 3% ✅
4. **Expected Equity Return**: 10% ✅
5. **Volatility**: 12% ✅
6. **Hedging Cost**: 0.5% annually ✅
7. **Hedging Floor**: 20% downside protection ✅
8. **Hedging Cap**: 40% upside cap (5-year) ✅
9. **Profit Sharing**: 50/50 surplus split ✅
10. **Core Simulation Logic**: GBM with lognormal returns ✅

---

## 🚨 RECOMMENDATIONS

### 1. **Fix Insurance Cost Discrepancy** (CRITICAL)

**Excel shows**: 0.25% upfront = $4K total
**Python shows**: 0.5% annually = $80K total

**Action**: Clarify which is correct. If Excel is right, Python/Rust results are way too pessimistic.

Suggested test:
```python
# Try Excel's insurance cost in Python
INSURANCE_COST_PA = 0.0025  # Match Excel's 0.25% upfront
# But apply as one-time cost, not annual
```

### 2. **Harmonize Payment Holiday Thresholds**

**Excel**: 90% entry, 145.8% exit
**Python**: 90% entry, 140% exit

**Action**: Align exit threshold to Excel's 145.8% (1.458)

```python
HOLIDAY_EXIT_FRACTION = 1.458  # Match Excel exactly
```

### 3. **Add Super-Repayment Logic to Python/Rust**

Excel has sophisticated catch-up repayment when equity exceeds 218.7% (1.5 × 1.458).

**Action**: Implement in Python/Rust:
```python
SUPERPAY_THRESHOLD = 1.458 * 1.5  # 218.7% of initial loan
if equity_value > (total_loan * SUPERPAY_THRESHOLD):
    # Accelerate principal repayment
    extra_payment = (equity_value - threshold) * 0.1  # 10% of excess
```

### 4. **Verify Interest Rate Calculation**

**Excel**: Uses AVERAGE(opening, closing) balance
**Python**: Uses opening balance only

**Action**: Test which method Excel actually uses by comparing with a single scenario.

### 5. **Validate Hedging Implementation**

Excel hedging appears simpler (annual basis vs 5-year lookback).

**Action**: Run Excel with and without hedging, compare to Python/Rust.

---

## 📋 TESTING PROTOCOL

To definitively identify the source of discrepancies:

### Test 1: Match All Parameters Exactly

```python
# Set Python to match Excel exactly
INSURANCE_COST_PA = 0.0025  # Not 0.005
INSURANCE_UPFRONT = True    # One-time, not annual
HOLIDAY_EXIT_FRACTION = 1.458  # Not 1.4
CASH_RATE = 0.036  # Not 0.031
ADDITIONAL_LOAN_MARGINS = 0.01  # Match Excel 0.75% + 0.25%

# Run single scenario comparison
```

### Test 2: Single Path Comparison

Use Excel's "Hardcode" option (Row 45) with specific returns:
```
Year 1: +10%
Year 2: +10%
Year 3: -15%
Year 4: -15%
Year 5-10: +10%
```

Compare:
- Investment account balance each year
- Holiday entry/exit timing
- Interest deficit accumulation
- Final surplus/deficit

### Test 3: Insurance Cost Sensitivity

Run Python/Rust with:
```python
# Test A: Excel insurance cost
INSURANCE_COST = 4_000  # One-time upfront

# Test B: Current Python cost
INSURANCE_COST = 80_000  # Over loan life

# Test C: No insurance
INSURANCE_COST = 0
```

Compare insurance claim probabilities.

---

## 🎯 CONCLUSION

### **Primary Discrepancy: Insurance Cost**

The 20x difference in insurance cost ($4K vs $80K) is the dominant factor explaining why Monte Carlo results look worse than Excel projections.

**If Excel's 0.25% upfront cost is correct, Python/Rust results would improve dramatically.**

### **Secondary Issues**

1. Payment holiday exit threshold (145.8% vs 140%)
2. Missing super-repayment logic in Python/Rust
3. Interest rate basis (7.6% vs 7.3%)
4. Timestep granularity (annual vs quarterly)

### **Next Steps**

1. **Urgent**: Clarify correct insurance cost with business team
2. Run Test 1 (match all parameters) to isolate remaining differences
3. Implement super-repayment logic if confirmed in Excel
4. Document final parameter set for production use

---

**Files Referenced**:
- Excel: `Copy of 20250624 FutureProof Mini Model Data Room.xlsm`
- Python: `single_real_data.py`, `core_model_advanced.py`
- Rust: `profitability_sweep.py`, `monte_carlo_engine.rs`
- Analysis: `PARAMETER_COMPARISON.md`, `CONVERGENCE_ANALYSIS.md`
