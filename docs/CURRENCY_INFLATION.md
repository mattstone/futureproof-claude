# Currency & Inflation Framework — FutureProof EPM

**Version:** 1.0  
**Created:** 2026-03-06  
**Scope:** Foreign exchange risk, inflation impact on EPM income, purchasing power preservation, currency hedging strategies, and regional inflation dynamics across AU, US, NZ, and UK

---

## Table of Contents

1. [Why Currency & Inflation Matter for EPM](#1-why-currency--inflation-matter-for-epm)
2. [The FX Problem](#2-the-fx-problem)
3. [Currency Hedging Strategies](#3-currency-hedging-strategies)
4. [Inflation & Purchasing Power](#4-inflation--purchasing-power)
5. [Regional Inflation Profiles](#5-regional-inflation-profiles)
6. [Income Adjustment Mechanisms](#6-income-adjustment-mechanisms)
7. [Property Value & Inflation](#7-property-value--inflation)
8. [Portfolio Construction for Inflation Protection](#8-portfolio-construction-for-inflation-protection)
9. [Stress Scenarios](#9-stress-scenarios)
10. [Platform Implementation](#10-platform-implementation)
11. [Implementation Checklist](#11-implementation-checklist)

---

## 1. Why Currency & Inflation Matter for EPM

EPM has a fundamental currency mismatch and a long-duration inflation exposure:

```
CURRENCY MISMATCH:
  Consumer lives in:        AU / NZ / UK (local currency)
  Portfolio invested in:    Predominantly USD assets (S&P 500, US bonds)
  Income paid in:           Local currency
  
  → Portfolio returns earned in USD must be converted to local currency
  → FX movements can amplify OR erode income

INFLATION EXPOSURE:
  EPM term:                 15-30 years
  Consumer's costs:         Rise with local inflation (food, energy, healthcare, rates)
  EPM income:               Fixed in nominal terms (unless adjusted)
  
  → $1,000/month in 2026 buys ~$550 of goods in 2046 (at 3% inflation)
  → Without inflation adjustment, EPM income loses half its value over 20 years
```

**These are not theoretical risks.** Over a 20-30 year EPM, currency and inflation will materially affect whether the consumer can maintain their lifestyle.

---

## 2. The FX Problem

### 2.1 Currency Pairs

| Consumer Region | Local Currency | Portfolio Currency | Key FX Pair |
|----------------|---------------|-------------------|-------------|
| AU | AUD | ~70% USD, ~15% AUD, ~15% other | AUD/USD |
| US | USD | ~85% USD, ~15% international | No material FX risk |
| NZ | NZD | ~70% USD, ~15% NZD, ~15% other | NZD/USD |
| UK | GBP | ~60% USD, ~20% GBP, ~20% EUR | GBP/USD |

### 2.2 Historical FX Volatility

| Pair | 20-Year Range | Annualised Volatility | Impact on $640K Portfolio |
|------|--------------|----------------------|--------------------------|
| AUD/USD | 0.48 – 1.10 | ~12% | ±$77,000/year at peak volatility |
| NZD/USD | 0.39 – 0.88 | ~13% | ±$83,000/year |
| GBP/USD | 1.07 – 2.11 | ~10% | ±$64,000/year |

### 2.3 FX Impact on Monthly Income

**Example: AU consumer, $640K portfolio, $1,000/month income target**

| AUD/USD Rate | Portfolio in AUD | Income in AUD | vs Baseline |
|-------------|-----------------|---------------|-------------|
| 0.80 (strong AUD) | $800,000 | $1,000 | Baseline |
| 0.70 (moderate) | $914,000 | $1,143 | +14% |
| 0.60 (weak AUD) | $1,067,000 | $1,333 | +33% |
| 0.50 (very weak) | $1,280,000 | $1,600 | +60% |

**A weaker local currency INCREASES portfolio value and income in local terms.** This is actually favourable for non-US EPM consumers — when global equities fall, the local currency often weakens too, partially offsetting portfolio losses.

However, this "natural hedge" is unreliable and shouldn't be relied upon for product design.

---

## 3. Currency Hedging Strategies

### 3.1 Options

| Strategy | Description | Cost | Effectiveness | Complexity |
|----------|-------------|------|--------------|-----------|
| **No hedge** | Accept FX exposure as part of portfolio risk | 0% | Low — income volatile | Low |
| **Full hedge** | Hedge 100% of USD exposure back to local currency | 1.5-3% p.a. | High — eliminates FX risk | Medium |
| **Partial hedge** | Hedge 50% of USD exposure | 0.75-1.5% p.a. | Medium — reduces volatility, retains some upside | Medium |
| **Income-only hedge** | Hedge only the next 12 months of income payments | 0.2-0.5% p.a. | Medium — protects near-term income | Low |
| **Natural hedge** | Allocate portion of portfolio to local-currency assets | 0% (but lower returns) | Medium — reduces but doesn't eliminate | Low |

### 3.2 Recommended Approach by Region

| Region | Strategy | Rationale |
|--------|----------|-----------|
| **AU** | Partial hedge (50%) + local allocation (15% ASX) | AUD/USD volatile but often acts as natural hedge. Full hedge too expensive. |
| **US** | No hedge required | Portfolio and income in same currency |
| **NZ** | Income-only hedge + local allocation (15% NZX) | NZD/USD highly volatile. Hedge income stream, accept portfolio-level FX. |
| **UK** | Partial hedge (50%) + local allocation (20% FTSE) | GBP more stable than AUD/NZD but Brexit-era volatility warrants hedging |

### 3.3 Hedging Mechanics

```
INCOME-ONLY HEDGE (Recommended minimum for all non-US regions):

Each quarter, the lender:
1. Calculates next quarter's income obligations in local currency
2. Purchases 3-month FX forward contracts:
   - Sell USD / Buy local currency
   - Notional = next quarter's total income payments
3. At settlement, forwards deliver local currency at locked-in rate
4. Income payments made from forward proceeds

Cost: ~0.2-0.5% of income amount (small relative to total portfolio)
Benefit: Consumer receives predictable income regardless of FX moves
```

### 3.4 Hedging Cost Impact on Income

| Strategy | Annual Cost (on $640K portfolio) | Monthly Income Reduction |
|----------|----------------------------------|------------------------|
| No hedge | $0 | $0 (but volatile) |
| Income-only hedge | ~$1,500 | ~$125 |
| Partial hedge (50%) | ~$6,400 | ~$533 |
| Full hedge | ~$12,800 | ~$1,067 |

**Full hedging is prohibitively expensive** — it would consume most or all of the consumer's income in some interest rate environments. Income-only hedging is the pragmatic minimum.

---

## 4. Inflation & Purchasing Power

### 4.1 The Silent Erosion

| Years | Cumulative Inflation (at 3%) | $1,000/month Buys |
|-------|-----------------------------|--------------------|
| 0 | 0% | $1,000 of goods |
| 5 | 16% | $863 of goods |
| 10 | 34% | $744 of goods |
| 15 | 56% | $642 of goods |
| 20 | 81% | $554 of goods |
| 25 | 109% | $478 of goods |
| 30 | 143% | $412 of goods |

**After 20 years at 3% inflation, EPM income buys 45% less.** For a product targeting retirees who may live 20-30 years post-inception, this is a critical design issue.

### 4.2 Consumer Costs That Rise Fastest

| Cost Category | Typical Inflation Rate | Impact on Retirees |
|--------------|----------------------|-------------------|
| Healthcare | 4-6% p.a. (above general CPI) | High — increasing healthcare needs with age |
| Aged care | 5-7% p.a. | Very high — if consumer enters residential care |
| Council rates / property tax | 3-5% p.a. | Medium — consumer must pay as property owner |
| Energy (electricity, gas) | 3-8% p.a. (volatile) | High — fixed income consumers disproportionately affected |
| Food | 2-4% p.a. | Medium — essential spending |
| Insurance (buildings) | 4-8% p.a. | High — mandatory for EPM, premiums rising sharply |
| General CPI | 2-3% p.a. (target) | Baseline |

**Healthcare and insurance costs rising at 2-3× CPI mean the real purchasing power erosion is worse than headline inflation suggests.**

---

## 5. Regional Inflation Profiles

### 5.1 Central Bank Targets

| Region | Central Bank | Inflation Target | Recent History (2020-2025) |
|--------|-------------|-----------------|---------------------------|
| AU | RBA | 2-3% | Peaked ~7.8% (2022), returning to band |
| US | Federal Reserve | 2% | Peaked ~9.1% (2022), returning to target |
| NZ | RBNZ | 1-3% | Peaked ~7.3% (2022), returning to band |
| UK | Bank of England | 2% | Peaked ~11.1% (2022), returning to target |

### 5.2 Long-Term Inflation Assumptions for EPM Modelling

| Scenario | Rate | Use Case |
|----------|------|----------|
| **Base case** | 2.5% p.a. | Central bank targets achieved |
| **Elevated** | 4.0% p.a. | Structural inflation (deglobalisation, energy transition) |
| **High** | 6.0% p.a. | Sustained inflation shock (1970s-style) |
| **Low** | 1.0% p.a. | Deflationary/disinflationary environment |

### 5.3 Inflation Divergence Risk

EPM operates across four currency zones with independent monetary policies. Inflation may diverge:

```
Example scenario (2030s):
  AU: 4% inflation (commodity boom, housing shortage)
  US: 2% inflation (stable)
  NZ: 3% inflation (moderate)
  UK: 5% inflation (energy crisis, fiscal expansion)

Impact on EPM:
  AU consumer: Portfolio grows at ~7% USD, but needs 4% AUD adjustment → net real return reduced
  UK consumer: Portfolio grows at ~7% USD, but needs 5% GBP adjustment → net real return further reduced
  
  If income isn't inflation-adjusted, UK consumer's purchasing power
  falls TWICE: once from inflation, once from any GBP weakness vs USD
```

---

## 6. Income Adjustment Mechanisms

### 6.1 Options

| Mechanism | How It Works | Pros | Cons |
|-----------|-------------|------|------|
| **Fixed nominal** | Income stays the same ($1,000/month forever) | Simple, predictable, easy to model | Purchasing power erodes significantly |
| **CPI-linked annual adjustment** | Income increases by local CPI each year | Maintains purchasing power | Portfolio must generate CPI + margin + income |
| **Fixed escalation** | Income increases by fixed % p.a. (e.g., 2%) | Predictable, simple | May undershoot or overshoot actual inflation |
| **Performance-linked** | Income adjusts based on actual portfolio returns | Aligns income with reality | Volatile — consumer can't plan |
| **Hybrid floor + CPI** | CPI-linked with a floor (never decreases) | Best consumer outcome | Most expensive for lender |

### 6.2 Recommended Approach by Variant

| Variant | Adjustment Method | Rationale |
|---------|------------------|-----------|
| **Standard** | CPI-linked annual adjustment | Flagship product must protect purchasing power |
| **Growth** | Performance-linked (after deferral) | Higher risk/reward — consumer accepted growth profile |
| **Flex** | N/A (drawdown — no regular income) | Consumer controls timing and amount |
| **Protect** | Fixed escalation (2% p.a.) + floor | Certainty is the whole point of Protect |
| **Legacy** | CPI-linked | Estate focus but still need adequate lifetime income |

### 6.3 CPI-Linked Income Calculation

```ruby
# Annual income adjustment (each review date)
def adjusted_income(base_income, years, cpi_rates)
  current = base_income
  years.times do |y|
    current *= (1 + cpi_rates[y])
  end
  current
end

# Example: $1,000/month base, 3% average CPI over 20 years
# Year 1:  $1,000
# Year 5:  $1,159
# Year 10: $1,344
# Year 15: $1,558
# Year 20: $1,806

# Portfolio must sustain increasing withdrawals:
# Year 1:  $12,000/year withdrawn
# Year 10: $16,128/year withdrawn
# Year 20: $21,672/year withdrawn
```

### 6.4 Sustainability Analysis

**Can the portfolio sustain CPI-linked income over 20-30 years?**

| Assumption | Value |
|-----------|-------|
| Initial portfolio | $640,000 |
| Portfolio return | 7% nominal |
| CPI (income escalation) | 3% p.a. |
| Lender margin | 3% p.a. |
| Initial income | $12,000/year (1.5% of $800K property) |

| Year | Portfolio Value | Annual Income | Income as % of Portfolio |
|------|---------------|--------------|-------------------------|
| 0 | $640,000 | $12,000 | 1.9% |
| 5 | $706,000 | $13,910 | 2.0% |
| 10 | $771,000 | $16,128 | 2.1% |
| 15 | $828,000 | $18,697 | 2.3% |
| 20 | $866,000 | $21,672 | 2.5% |
| 25 | $870,000 | $25,122 | 2.9% |
| 30 | $821,000 | $29,120 | 3.5% |

**Result:** Portfolio sustains CPI-linked income for 25+ years before withdrawal rate becomes concerning. At year 30, the 3.5% withdrawal rate is still within safe withdrawal guidelines — but the buffer is thin.

**For 30-year terms, either:**
1. Start with lower income rate (1.2% instead of 1.5%) to extend sustainability, or
2. Cap CPI adjustment at 4% p.a. (prevent runaway escalation in high-inflation scenarios), or
3. Include a sustainability review at year 20 (reduce income if portfolio is below threshold)

---

## 7. Property Value & Inflation

### 7.1 Property as Inflation Hedge

Historically, residential property has been an effective long-term inflation hedge:

| Region | 20-Year Average Property Growth | Average Inflation | Real Growth |
|--------|-------------------------------|-------------------|-------------|
| AU | ~6.5% p.a. | ~2.5% p.a. | ~4.0% p.a. |
| US | ~4.5% p.a. | ~2.5% p.a. | ~2.0% p.a. |
| NZ | ~7.0% p.a. | ~2.5% p.a. | ~4.5% p.a. |
| UK | ~5.5% p.a. | ~2.5% p.a. | ~3.0% p.a. |

**This is positive for EPM.** Property value growth:
1. Increases the consumer's equity buffer (reduces NNEG risk)
2. Provides headroom for the mortgage balance to grow (lender margin accrual)
3. Means the estate benefits from property appreciation even with the EPM mortgage

### 7.2 Property Value vs Mortgage Balance

```
Key relationship:
  IF property_growth > lender_margin THEN equity increases over time
  IF property_growth < lender_margin THEN equity decreases over time
  IF property_growth < 0 (sustained) THEN NNEG risk rises

Historical perspective:
  Property growth: 4.5-7% p.a. (nominal)
  Lender margin:   3% p.a.
  Gap:             1.5-4% p.a. in favour of equity growth

Even in real terms (inflation-adjusted), property growth exceeds 
the lender margin in all four regions historically.
```

### 7.3 NNEG Inflation Sensitivity

| Inflation Environment | Property Impact | NNEG Risk |
|----------------------|-----------------|-----------|
| Low inflation (1%) | Property growth slows to 2-3% | Moderate — margin accrual may outpace property |
| Target inflation (2-3%) | Property growth 4-6% | Low — healthy equity buffer |
| High inflation (5%+) | Property growth 7-10%+ | Very low — property outpaces everything |
| Deflation | Property may fall | High — NNEG most likely to trigger |

**Counterintuitive insight:** Higher inflation is actually GOOD for NNEG risk management (property values rise faster), but BAD for consumer purchasing power (income buys less). The lender and consumer have opposite inflation preferences, which makes product design a balancing act.

---

## 8. Portfolio Construction for Inflation Protection

### 8.1 Inflation-Hedging Assets

| Asset | Inflation Protection | Used In Portfolio? |
|-------|--------------------|--------------------|
| **Equities** | Good long-term (earnings grow with prices) | ✅ Core holding (60-90%) |
| **Inflation-linked bonds (TIPS/ILBs)** | Direct CPI linkage | ✅ Recommended for Protect variant (10-20%) |
| **Real estate (REITs)** | Good (rents adjust with inflation) | ⚠️ Optional (5-10%) — avoid double property exposure |
| **Commodities** | Good in supply-driven inflation | ⚠️ Optional (0-5%) — volatile |
| **Gold** | Traditional inflation hedge but volatile | ⚠️ Optional (0-5%) |
| **Cash** | Poor — loses value in real terms | Minimal (liquidity buffer only) |
| **Nominal bonds** | Poor — fixed coupons lose real value | Reduce in high-inflation environment |

### 8.2 Inflation-Aware Portfolio Allocation

| Environment | Equities | IL Bonds | Nominal Bonds | Cash | Other |
|-------------|----------|----------|--------------|------|-------|
| **Normal (2-3% CPI)** | 70% | 5% | 20% | 5% | 0% |
| **Elevated (3-5% CPI)** | 70% | 15% | 10% | 5% | 0% |
| **High (5%+ CPI)** | 65% | 20% | 5% | 5% | 5% (commodities) |
| **Deflation** | 50% | 0% | 40% | 10% | 0% |

**The portfolio should be dynamically rebalanced** based on the inflation environment. This is a lender/investment manager responsibility under Model B.

### 8.3 Regional Bond Allocation

| Region | Inflation-Linked Bond | Issuer |
|--------|----------------------|--------|
| AU | Treasury Indexed Bonds (TIBs) | Australian Government |
| US | TIPS (Treasury Inflation-Protected Securities) | US Treasury |
| NZ | Inflation-Indexed Bonds (IIBs) | NZ Government (limited supply) |
| UK | Index-Linked Gilts | UK Government |

**For non-US consumers, include local IL bonds** to match the consumer's local inflation exposure. A portfolio of US TIPS protects against US inflation, which may diverge from AU/NZ/UK inflation.

---

## 9. Stress Scenarios

### 9.1 Scenario 1: 1970s-Style Stagflation

```
Inflation:    8% p.a. for 5 years, then 4% for 5 years
Equities:     -2% real return for 10 years (nominal ~6%)
Property:     +10% p.a. (nominal, driven by inflation)
FX (AUD/USD): Weakens from 0.75 to 0.55

INCOME IMPACT (AU consumer, CPI-linked):
  Year 0:  $1,000/month
  Year 5:  $1,469/month (CPI-adjusted)
  Year 10: $1,784/month

PORTFOLIO IMPACT:
  Nominal growth: ~6% (barely keeping pace with inflation)
  Less margin: -3%
  Less CPI income escalation: -8% (year 1-5)
  Portfolio under stress: declining in real terms
  
  AUD weakness HELPS: portfolio worth more in AUD
  
  RESULT: Portfolio survives but is strained. May trigger 
  sustainability review at year 10. Income floor needed.
```

### 9.2 Scenario 2: Japanese Deflation

```
Inflation:    -1% p.a. for 10 years
Equities:     +2% nominal (positive but low)
Property:     -2% p.a. (nominal decline)
Bonds:        Rally (yields fall, prices rise)

INCOME IMPACT:
  CPI-linked: Income DECREASES if CPI-linked allows downward adjustment
  With floor: Income stays at original level (deflation = no adjustment)

PORTFOLIO IMPACT:
  Bonds outperform, equities weak
  Conservative allocation outperforms growth
  
  NNEG RISK: HIGH — property declining while mortgage accrues
  
  Property: $800K → $653K (year 10)
  Mortgage: $640K → $860K (year 10, 3% margin)
  NNEG triggered: Estate owes $653K, lender absorbs $207K loss
  
  RESULT: Worst case for NNEG. This is what NNEG insurance and
  reserves are designed for.
```

### 9.3 Scenario 3: Currency Crisis (AUD/NZD Collapse)

```
Trigger:     China hard landing, commodity bust
AUD/USD:     Falls from 0.70 to 0.40 over 18 months
NZD/USD:     Falls from 0.65 to 0.35

PORTFOLIO IMPACT (unhedged AU consumer):
  USD portfolio: $640,000 USD (unchanged)
  In AUD terms: $640K / 0.40 = $1,600,000 AUD (was $914K at 0.70)
  
  Portfolio DOUBLED in local terms due to FX!

INCOME IMPACT:
  If income paid from USD returns → converts to more AUD
  $1,000/month in USD = $2,500/month in AUD (at 0.40)
  
  GOOD for consumer (more income in local terms)
  BAD if AUD recovers → income drops back

INCOME-ONLY HEDGE IMPACT:
  Forward contracts locked in old rate → consumer gets stable income
  Portfolio FX gain sits in portfolio (unrealised)
  
  RESULT: Unhedged consumers benefit from currency weakness.
  Hedged consumers have stable income but miss the windfall.
  Neither outcome is catastrophic.
```

### 9.4 Scenario 4: Sustained High Inflation + Rising Rates

```
Inflation:    5% p.a. sustained for 10 years
Interest rates: Rise to 8%+
Equities:     Volatile but +5% real (nominal ~10%)
Property:     +7% nominal (lagging inflation slightly)
Bonds:        Heavy losses (rising rates destroy bond values)

PORTFOLIO IMPACT:
  Equities: Strong (companies pass through inflation)
  Bonds: Weak (-15 to -30% drawdown, then recover at higher yields)
  Overall 70/30: Moderate — equity strength offsets bond weakness
  
  Hedging cost INCREASES (interest rate differential widens)
  Full hedge cost: 3-5% p.a. (approaching income level)

INCOME IMPACT:
  CPI-linked: Income rises 5% p.a. — $1,000 → $1,629 at year 10
  Portfolio needs to sustain accelerating withdrawals
  
  RESULT: Equity returns support CPI escalation. Bond allocation
  should shift to IL bonds and short-duration. Monitor withdrawal
  rate — if exceeding 3%, trigger sustainability review.
```

### 9.5 Scenario Summary

| Scenario | Income | Portfolio | NNEG | Overall |
|----------|--------|-----------|------|---------|
| 1970s Stagflation | ⚠️ Strained | ⚠️ Strained | ✅ Low (property rises) | ⚠️ Survivable |
| Japanese Deflation | ✅ Stable (floor) | ⚠️ Weak | ❌ **High risk** | ❌ Worst case |
| Currency Crisis | ✅ Windfall (unhedged) | ✅ Strong (local terms) | ✅ Low | ✅ Favourable |
| Sustained High Inflation | ⚠️ Rising fast | ✅ Equities strong | ✅ Low | ⚠️ Manageable |

**Key takeaway:** Deflation is EPM's worst enemy (property falls, NNEG triggers, portfolio weak). Inflation is manageable. Currency weakness is actually beneficial for non-US consumers.

---

## 10. Platform Implementation

### 10.1 Quote Engine — Inflation Scenarios

Every EPM quote must show income projections under multiple inflation scenarios:

```
┌──────────────────────────────────────────────────┐
│          YOUR EPM INCOME PROJECTION               │
│                                                    │
│  Starting income: $1,000/month                     │
│                                                    │
│  Adjusted for inflation (CPI-linked):              │
│                                                    │
│         Year 5    Year 10   Year 15   Year 20      │
│  Low    $1,051    $1,105    $1,161    $1,220       │
│  Base   $1,159    $1,344    $1,558    $1,806       │
│  High   $1,338    $1,791    $2,397    $3,207       │
│                                                    │
│  ⚠️ These projections assume your income is        │
│  adjusted annually in line with CPI. Actual        │
│  adjustments depend on portfolio performance.      │
│                                                    │
│  In real terms (today's dollars), your income      │
│  maintains approximately the same purchasing       │
│  power under the CPI-linked adjustment.            │
└──────────────────────────────────────────────────┘
```

### 10.2 FX Display

For non-US consumers, show FX sensitivity:

```
Your income is generated from a globally diversified portfolio.
Currency movements may affect your income at annual review.

Current AUD/USD rate: 0.70
If AUD strengthens to 0.80: Income may decrease ~12%
If AUD weakens to 0.60:    Income may increase ~17%

Your income is [hedged for the next 12 months / partially hedged / unhedged].
```

### 10.3 Annual Review Process

```
ANNUAL INCOME REVIEW (each anniversary):

1. Calculate portfolio return for the year (net of fees, margin)
2. Obtain local CPI for the year (ABS, BLS, Stats NZ, ONS)
3. Apply income adjustment:
   a. CPI-linked: Adjust by actual CPI (cap at 4% to limit stress)
   b. Fixed escalation: Apply fixed rate (Protect variant)
   c. Performance-linked: Calculate sustainable withdrawal rate
4. FX adjustment:
   a. If hedged: No FX component
   b. If unhedged: Adjust for FX movement
5. Sustainability check:
   a. Is withdrawal rate < 3.5% of portfolio? → Continue
   b. Is withdrawal rate 3.5-4.5%? → Flag for review
   c. Is withdrawal rate > 4.5%? → Reduce income or trigger lender discussion
6. Communicate new income to consumer (30 days before change)
```

### 10.4 Data Sources

| Data | Source | Frequency | Used For |
|------|--------|-----------|----------|
| AU CPI | ABS (Australian Bureau of Statistics) | Quarterly | Income adjustment |
| US CPI | BLS (Bureau of Labor Statistics) | Monthly | Income adjustment |
| NZ CPI | Stats NZ | Quarterly | Income adjustment |
| UK CPI | ONS (Office for National Statistics) | Monthly | Income adjustment |
| AUD/USD | RBA / market data | Daily | FX hedging, portfolio valuation |
| NZD/USD | RBNZ / market data | Daily | FX hedging, portfolio valuation |
| GBP/USD | BoE / market data | Daily | FX hedging, portfolio valuation |
| Property indices | CoreLogic (AU/NZ), Case-Shiller (US), Nationwide/Halifax (UK) | Monthly | NNEG monitoring, LTV tracking |

---

## 11. Implementation Checklist

### Portfolio & Hedging

- [ ] Currency hedging policy documented and approved (per region)
- [ ] Income-only hedge mechanism implemented (minimum for AU/NZ/UK)
- [ ] FX forward contract provider selected (bank or prime broker)
- [ ] Inflation-linked bond allocation defined per variant
- [ ] Dynamic rebalancing triggers defined (inflation environment shifts)
- [ ] Quarterly rebalancing process documented

### Quote Engine

- [ ] Inflation scenarios in quote output (low/base/high CPI)
- [ ] FX sensitivity display for non-US consumers
- [ ] Real vs nominal income comparison
- [ ] 20-year and 30-year income sustainability projections
- [ ] CPI escalation cap disclosed (recommend 4% p.a. maximum)

### Annual Review

- [ ] CPI data feed integrated (ABS, BLS, Stats NZ, ONS)
- [ ] Annual income adjustment calculation engine
- [ ] Sustainability check (withdrawal rate monitoring)
- [ ] Consumer notification template for income changes
- [ ] FX adjustment calculation (hedged vs unhedged)
- [ ] 30-day advance notice process for income changes

### Stress Testing

- [ ] Four stress scenarios modelled (stagflation, deflation, FX crisis, sustained inflation)
- [ ] NNEG stress testing under deflation scenario
- [ ] Portfolio sustainability under high CPI escalation
- [ ] Annual stress test report to board / risk committee
- [ ] Scenario results influence portfolio allocation decisions

### Disclosures

- [ ] FX risk disclosure in all non-US consumer documents
- [ ] Inflation risk disclosure (purchasing power erosion without adjustment)
- [ ] CPI adjustment methodology explained in product documentation
- [ ] Hedging cost impact on income disclosed
- [ ] "Past inflation is not a guide to future inflation" warning

---

*Currency and inflation risks are the slow-moving threats to EPM viability. Unlike a data breach or platform outage, they erode value gradually over years. The framework must be embedded in product design, not bolted on after launch. Review annually against actual inflation and FX outcomes.*
