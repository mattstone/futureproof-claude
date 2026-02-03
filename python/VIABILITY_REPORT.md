# Equity Preservation Mortgage - Viability Analysis

## Executive Summary

**Question**: What do we need to do to make the original Equity Preservation Mortgage work?

**Answer**: The product CAN be made marginally viable (2-2.3% XIRR), but requires significant changes that make it unattractive to borrowers.

## Current Status (BASELINE)

**Parameters:**
- LTV: 80%
- Lending Margin: 2.0%
- Additional Margin: 1.5%
- Annual Income to Borrower: $30,000
- Insurance Cost PA: 2.0%

**Results:**
- Mean XIRR: ~1.5% (Interest Only) / ~1.4% (Principal+Interest)
- Insurance Payout Probability: 55%
- **Status**: ❌ NOT VIABLE - Returns below risk-free rate (4%)

---

## What Changes Make It Viable?

### Minimum Viable Scenario (2.28% XIRR)

**Required Parameter Changes:**

| Parameter | Current | Required | Change |
|-----------|---------|----------|--------|
| **LTV** | 80% | 80% | No change |
| **Lending Margin** | 2.0% | 3.0% | +1.0% ✅ |
| **Additional Margin** | 1.5% | 1.5% | No change |
| **Annual Income** | $30,000 | $15,000 | **-50%** ⚠️ |
| **Insurance Cost PA** | 2.0% | 1.0% | -1.0% ✅ |

**Expected Results:**
- XIRR: 2.28%
- CAGR: 7.19%
- Insurance Payout Risk: 24%

**⚠️ CRITICAL ISSUE**: Cutting annual income from $30K to $15K makes the product unattractive to borrowers.

---

## Analysis of All 1,500 Scenarios Tested

### Return Distribution

- **Scenarios with XIRR ≥ 2%**: 7 out of 1,425 (0.5%)
- **Scenarios with XIRR ≥ 4%**: 0 (0.0%)
- **Mean XIRR**: -0.23%
- **Median XIRR**: 0.39%

**XIRR Distribution:**
- Below 0%: 536 scenarios (37.6%)
- 0-2%: 882 scenarios (61.9%)
- 2-4%: 7 scenarios (0.5%)
- 4%+: 0 scenarios (0.0%)

---

## Key Findings: What Makes a Scenario Viable?

### 1. Annual Income (MOST IMPORTANT)

**Income must be drastically reduced:**

| Annual Income | Mean XIRR | Viable Scenarios |
|---------------|-----------|------------------|
| $15,000 | 0.90% | 7/375 (1.9%) ✅ |
| $20,000 | 0.29% | 0/375 (0.0%) ❌ |
| $25,000 | -0.84% | 0/360 (0.0%) ❌ |
| $30,000 | -1.52% | 0/315 (0.0%) ❌ |

**💡 KEY INSIGHT**: Only $15K annual income produces ANY viable scenarios.

### 2. Insurance Cost (CRITICAL)

**Insurance cost must be minimized:**

| Insurance Cost PA | Mean XIRR | Viable Scenarios |
|-------------------|-----------|------------------|
| 1.0% | 0.86% | 7/300 (2.3%) ✅ |
| 1.5% | -0.01% | 0/300 (0.0%) ❌ |
| 2.0% | 0.04% | 0/285 (0.0%) ❌ |
| 2.5%+ | Negative | 0 ❌ |

**💡 KEY INSIGHT**: Only 1.0% insurance cost produces viable scenarios.

### 3. LTV (SURPRISING RESULT)

**Counter-intuitively, HIGHER LTV performs better:**

| LTV | Mean XIRR | Viable Scenarios |
|-----|-----------|------------------|
| 40% | -2.53% | 0/240 (0.0%) ❌ |
| 50% | -0.64% | 0/285 (0.0%) ❌ |
| 60% | 0.12% | 1/300 (0.3%) |
| 70% | 0.58% | 3/300 (1.0%) ✅ |
| 80% | 0.82% | 3/300 (1.0%) ✅ |

**💡 KEY INSIGHT**: Lower LTV doesn't help - it reduces loan amount available for S&P 500 investment, hurting returns.

### 4. Lending Margins (MIXED EFFECT)

**Higher margins help slightly, but not enough alone:**

| Total Cost of Funds | Mean XIRR | Viable Scenarios |
|---------------------|-----------|------------------|
| 7.5% | -0.02% | 2/95 (2.1%) |
| 8.5% | -0.19% | 0/95 (0.0%) |
| 9.5% | -0.23% | 2/285 (0.7%) |
| 10.5%+ | Worse | 0 ❌ |

---

## Average Profile of Viable Scenarios (7 scenarios)

- **Average LTV**: 72.9%
- **Average Lending Margin**: 3.43%
- **Average Additional Margin**: 1.64%
- **Average Annual Income**: $15,000 (100% of viable scenarios)
- **Average Insurance Cost**: 1.00% (100% of viable scenarios)
- **Average XIRR**: 2.06%
- **Average Insurance Risk**: 35.4%

---

## The Fundamental Problem

Even with optimal parameters, the product faces three impossible constraints:

### 1. **Returns Too Low**
- Best case: 2.28% XIRR
- Risk-free rate: 4.0%
- Gap: -1.72%
- **Verdict**: Funders can get better returns with zero risk

### 2. **Borrower Value Destroyed**
- To achieve 2.28% funder returns, annual income must drop from $30K → $15K
- **This is a 50% cut in borrower benefit**
- Product becomes unattractive to the customer

### 3. **Insurance Still Required**
- Even "best" scenario has 24% insurance payout risk
- Average viable scenario: 35.4% insurance risk
- Overall mean: 88.2% insurance risk
- Insurance costs eat into already-thin returns

---

## Recommendations

### Option A: Accept Marginal Returns
**Change these parameters:**
- Annual Income: $30,000 → $15,000 (cut 50%)
- Lending Margin: 2.0% → 3.0% (increase 50%)
- Insurance Cost: 2.0% → 1.0% (cut 50%)

**Result:**
- Funder XIRR: 2.28%
- Still below risk-free rate
- Product unattractive to borrowers (only $15K/year income)

### Option B: Abandon This Model
**Consider alternatives:**
1. **Index-Linked Annuity** (already modeled - also not viable)
2. **Shared Equity Agreement** (no debt, share appreciation)
3. **Government-Backed Program** (subsidize insurance costs)
4. **Hybrid Model** (mix annuity + small equity exposure)

### Option C: Target Different Market
**Change the value proposition:**
- Target ultra-high-net-worth ($10M+ homes)
- Smaller income ($10K-15K/year)
- Marketing as "legacy planning" not "retirement income"
- Accept lower LTV (50-60%) for safety

---

## Mathematical Reality

**The core issue**: S&P 500 returns (9.75% expected) must cover:
1. Cash rate (4%)
2. Lending margins (3.5%)
3. Insurance costs (1-2%)
4. Annuity payments to borrower ($15K-30K/year)
5. Profit for funder (2-4% XIRR target)

**Total required**: ~15-20% returns to make everyone whole

**Reality**: S&P 500 isn't consistent enough. Even with 9.75% mean:
- Volatility (15%) creates downside scenarios
- Payment holidays during underperformance
- Insurance payouts in 24-88% of scenarios

**The math doesn't work without:**
- Cutting borrower income (defeats the purpose)
- Massive insurance subsidies (uneconomic for insurer)
- Government backing (political challenge)
- Much higher equity returns (unrealistic)

---

## Conclusion

**Can we make the numbers work?**

Technically yes, but only by:
1. Cutting borrower income by 50% ($30K → $15K)
2. Increasing lending margins by 50% (2% → 3%)
3. Cutting insurance costs by 50% (2% → 1%)

**Should we make these changes?**

❌ **NO** - The resulting product:
- Returns only 2.28% (below risk-free rate)
- Provides insufficient income to borrowers ($15K/year)
- Still requires insurance in 24% of scenarios
- Would not attract either funders OR borrowers

**Recommendation**: Explore fundamentally different product structures rather than trying to optimize an inherently unprofitable model.

---

## Supporting Data

- Tested: 1,500 parameter combinations
- Monte Carlo paths per scenario: 100
- Valid results: 1,425 scenarios
- Viable scenarios (XIRR ≥ 2%): 7 (0.5%)
- Results saved in: `sensitivity_results.csv`
- Analysis script: `analyze_sensitivity.py`
