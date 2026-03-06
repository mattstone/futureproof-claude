# EPM Variants — Product Structures & Market Segments

**Version:** 1.0  
**Created:** 2026-03-06  
**Scope:** EPM product variations, eligibility tiers, portfolio strategies, payout structures, and regional adaptations across AU, US, NZ, and UK

---

## Table of Contents

1. [Core EPM Product](#1-core-epm-product)
2. [Variant 1: EPM Income (Standard)](#2-variant-1-epm-income-standard)
3. [Variant 2: EPM Growth (Deferred Income)](#3-variant-2-epm-growth-deferred-income)
4. [Variant 3: EPM Flex (Drawdown)](#4-variant-3-epm-flex-drawdown)
5. [Variant 4: EPM Protect (Conservative)](#5-variant-4-epm-protect-conservative)
6. [Variant 5: EPM Legacy (Estate-Optimised)](#6-variant-5-epm-legacy-estate-optimised)
7. [Portfolio Strategies](#7-portfolio-strategies)
8. [LTV Tiers & Eligibility](#8-ltv-tiers--eligibility)
9. [Regional Adaptations](#9-regional-adaptations)
10. [Payout Structures](#10-payout-structures)
11. [Product Comparison Matrix](#11-product-comparison-matrix)
12. [Implementation Roadmap](#12-implementation-roadmap)

---

## 1. Core EPM Product

All variants share the same underlying mechanics:

```
Property → Mortgage (LTV%) → Funds invested in portfolio → Returns generate income
                                                                    ↓
                                                          Consumer receives payouts
                                                                    ↓
                                                    Lender retains margin from returns
                                                                    ↓
                                            Mortgage repaid at sale/death/termination
```

**Universal features across all variants:**
- NNEG (No Negative Equity Guarantee)
- Non-recourse (consumer never owes more than property value)
- No monthly repayments from consumer
- Lender owns and manages portfolio (Model B — see TAX_TREATMENT.md)
- Consumer retains right to live in property
- Available across AU, US, NZ, UK (with regional adaptations)

**What differs between variants:**
- Payout timing and structure
- Portfolio risk profile
- LTV ratio
- Target consumer segment
- Fee structure

---

## 2. Variant 1: EPM Income (Standard)

**The flagship product. Monthly tax-free income from day one.**

### 2.1 Overview

| Parameter | Value |
|-----------|-------|
| **Target consumer** | Retirees seeking regular income supplement |
| **Age range** | 60+ (55+ with restrictions) |
| **LTV** | Up to 80% |
| **Payout** | Monthly income, fixed for 12-month periods |
| **Portfolio** | 70% equities / 30% fixed income (balanced) |
| **Income rate** | ~1.5% of property value p.a. (Pavel model) |
| **Lender margin** | ~3% p.a. on mortgage balance |
| **Review** | Annual — income adjusted based on portfolio performance |

### 2.2 Income Calculation

```ruby
# Simplified EPM Income calculation
property_value = 800_000
ltv = 0.80
portfolio = property_value * ltv  # $640,000
annual_income_rate = 0.015        # 1.5% of property value
lender_margin = 0.03              # 3% of mortgage balance

monthly_income = (property_value * annual_income_rate) / 12
# = $1,000/month

# Portfolio must generate: income + margin
required_return = annual_income_rate + (lender_margin * ltv)
# = 1.5% + 2.4% = 3.9% minimum (well below historical equity returns)
```

### 2.3 Consumer Profile

- Owns home outright (or near-fully paid off)
- Wants regular income without selling home
- Comfortable with 80% LTV
- Doesn't need to access lump sums
- Primary motivation: **lifestyle income**

---

## 3. Variant 2: EPM Growth (Deferred Income)

**No income in early years. Portfolio compounds. Higher income later.**

### 3.1 Overview

| Parameter | Value |
|-----------|-------|
| **Target consumer** | Pre-retirees (55-65) or those with adequate current income |
| **Age range** | 55+ |
| **LTV** | Up to 70% (lower — longer time horizon increases lender risk) |
| **Payout** | No income for years 1-5 (or 1-10). Full income thereafter. |
| **Portfolio** | 80% equities / 20% fixed income (growth-tilted) |
| **Income rate** | 0% years 1-5, then ~2.0-2.5% of property value p.a. |
| **Lender margin** | ~2.5% p.a. (lower margin — portfolio has time to compound) |
| **Review** | Annual after income commences |

### 3.2 Why Defer?

Compounding transforms the income potential:

| Deferral Period | Portfolio (from $560K at 70% LTV) | Monthly Income (at 2% of property p.a.) | Income vs Standard |
|----------------|-----------------------------------|----------------------------------------|-------------------|
| 0 years (Standard) | $560,000 | $1,000 | Baseline |
| 5 years | $785,000 | $1,400 | +40% |
| 10 years | $1,101,000 | $1,900 | +90% |

*Assumes 7% portfolio return, no distributions during deferral.*

### 3.3 Consumer Profile

- Still working or has pension/super income
- Wants to maximise future income (e.g., planning for age 70+ when costs rise)
- Comfortable deferring gratification
- May have health concerns and wants higher income in later years (aged care costs)
- Primary motivation: **future income maximisation**

### 3.4 Hybrid Option

Allow consumers to take **partial income** during deferral:

```
Years 1-5:   50% of standard income ($500/month)
Years 6+:    150% of standard income ($1,500/month)
```

This provides some immediate benefit while still capturing compounding gains.

---

## 4. Variant 3: EPM Flex (Drawdown)

**No regular income. Consumer draws funds as needed.**

### 4.1 Overview

| Parameter | Value |
|-----------|-------|
| **Target consumer** | Those who need occasional large sums (renovations, medical, travel) |
| **Age range** | 55+ |
| **LTV** | Up to 60% (lower — irregular drawdowns harder to model) |
| **Payout** | On-demand drawdown, subject to available balance |
| **Portfolio** | 60% equities / 40% fixed income (conservative — must maintain liquidity) |
| **Income rate** | N/A — drawdown from available balance |
| **Lender margin** | ~3.5% p.a. (higher — liquidity premium) |
| **Drawdown limit** | Maximum 20% of portfolio value per year |

### 4.2 How It Works

```
Initial portfolio:         $480,000 (60% LTV on $800K)
Year 1: No drawdown        Portfolio grows to ~$514,000
Year 2: $50,000 drawdown   Portfolio: $464,000 → grows to $496,000
Year 3: No drawdown        Portfolio grows to ~$531,000
Year 4: $80,000 drawdown   Portfolio: $451,000 → grows to $483,000
...

Available balance = Portfolio value - minimum reserve (10% of original)
Drawdown request → 5 business days processing → funds to consumer
```

### 4.3 Consumer Profile

- Doesn't need regular income
- Wants a financial safety net (medical emergencies, home repairs)
- May travel extensively and need lump sums periodically
- Values flexibility over predictability
- Primary motivation: **financial flexibility / emergency fund**

### 4.4 Fee Structure

| Fee | Amount | When |
|-----|--------|------|
| Establishment fee | 1.5% of mortgage | At inception |
| Annual management | 3.5% of mortgage balance | Accrued monthly |
| Drawdown fee | $0 (first 4 per year), $250 thereafter | Per drawdown |
| Minimum drawdown | $5,000 | Per request |

---

## 5. Variant 4: EPM Protect (Conservative)

**Lower income, lower risk. Capital preservation focus.**

### 5.1 Overview

| Parameter | Value |
|-----------|-------|
| **Target consumer** | Risk-averse retirees, those concerned about market volatility |
| **Age range** | 65+ |
| **LTV** | Up to 50% (conservative) |
| **Payout** | Monthly income, guaranteed minimum floor |
| **Portfolio** | 30% equities / 70% fixed income + cash |
| **Income rate** | ~0.8-1.0% of property value p.a. |
| **Lender margin** | ~2.0% p.a. (lower — reduced risk) |
| **Special feature** | **Income floor guarantee** — minimum income never drops below 80% of initial rate |

### 5.2 Income Floor Guarantee

Unlike Standard EPM (where income adjusts annually based on portfolio performance), EPM Protect guarantees a minimum:

```
Initial income:    $500/month (1.0% of $600K property, 50% LTV)
Good year:         $550/month (performance uplift)
Bad year:          $500/month (floor holds — never below 80% = $400/month)
Terrible year:     $400/month (absolute floor — lender subsidises from margin reserve)
```

The income floor is funded by a **margin reserve**: a portion of returns in good years is set aside to subsidise income in bad years.

### 5.3 Consumer Profile

- Very risk-averse (may have been burned by investments before)
- Prioritises certainty of income over maximum income
- Typically older (75+) with shorter expected term
- May be advised into this variant by financial adviser who assesses low risk tolerance
- Primary motivation: **income certainty and peace of mind**

---

## 6. Variant 5: EPM Legacy (Estate-Optimised)

**Maximise what beneficiaries inherit. Lower income, higher portfolio growth.**

### 6.1 Overview

| Parameter | Value |
|-----------|-------|
| **Target consumer** | Those who want income AND to leave a significant estate |
| **Age range** | 60+ |
| **LTV** | Up to 80% |
| **Payout** | Reduced monthly income (50-70% of Standard rate) |
| **Portfolio** | 90% equities / 10% fixed income (aggressive growth) |
| **Income rate** | ~0.8-1.0% of property value p.a. (lower than Standard) |
| **Lender margin** | ~2.5% p.a. |
| **Special feature** | Portfolio surplus above mortgage balance is **guaranteed to estate** |

### 6.2 How It Works

By taking less income, more returns stay in the portfolio. Over time, the portfolio grows significantly above the mortgage balance. The surplus is contractually guaranteed to the estate.

```
Standard EPM (20 years):
  Portfolio:    $1,200,000
  Mortgage:     $778,000
  Surplus:      $422,000 (to estate)
  Income taken: $600,000

Legacy EPM (20 years):
  Portfolio:    $1,800,000 (more growth — less drawn out)
  Mortgage:     $720,000 (lower margin)
  Surplus:      $1,080,000 (to estate)
  Income taken: $380,000
```

**Trade-off:** Consumer receives $220,000 less income over 20 years, but estate receives $658,000 more.

### 6.3 Consumer Profile

- Has other income sources (pension, super, investments)
- Wants to use EPM primarily as an estate-building tool
- Concerned about leaving an inheritance (especially UK — IHT mitigation)
- May be using EPM Legacy + gifts from income strategy (s21 IHTA in UK)
- Primary motivation: **intergenerational wealth transfer**

### 6.4 UK IHT Strategy with Legacy

```
EPM Legacy income:           £1,200/month
Gift to children (s21):      £800/month (regular gift from income — immediately IHT-exempt)
Retained for living:         £400/month

After 20 years:
  Gifts made:                £192,000 (all IHT-exempt under s21)
  Portfolio surplus to estate: £1,080,000
  Total value transferred:    £1,272,000

IHT on portfolio surplus:    £232,000 (40% of amount above NRB)
NET to beneficiaries:        £1,040,000

Without EPM:
  Property in estate:        £1,100,000
  IHT:                       £240,000
  NET to beneficiaries:      £860,000

EPM Legacy advantage:        +£180,000 to beneficiaries + £96,000 retained income
```

---

## 7. Portfolio Strategies

### 7.1 Model Portfolios

| Strategy | Equities | Fixed Income | Cash | Target Return | Volatility | Used By |
|----------|----------|-------------|------|---------------|------------|---------|
| **Aggressive Growth** | 90% | 10% | 0% | 8-10% p.a. | High | Legacy |
| **Balanced Growth** | 70% | 30% | 0% | 6-8% p.a. | Medium | Standard, Growth |
| **Conservative** | 30% | 60% | 10% | 3-5% p.a. | Low | Protect |
| **Liquidity** | 60% | 30% | 10% | 5-7% p.a. | Medium | Flex |

### 7.2 Investment Universe

| Asset Class | Instruments | Region Considerations |
|-------------|------------|----------------------|
| **US equities** | S&P 500 ETF (VOO/SPY), Total Market (VTI) | NZ: FIF tax applies if consumer-owned |
| **International equities** | MSCI World (VGS), FTSE All-World (VWRL) | Currency hedging required for non-USD regions |
| **AU equities** | ASX 200 (VAS/STW) | AU-only: franking credits benefit |
| **UK equities** | FTSE 100 (VUKE), FTSE 250 | UK-only: no FX risk |
| **Fixed income** | Aggregate bond ETFs (AGG/BND), govt bonds | Regional variants for currency matching |
| **Cash/money market** | High-interest cash, T-bills | For Protect and Flex liquidity |

### 7.3 Currency Hedging

| Consumer Region | Portfolio Currency | Hedging Required? |
|----------------|-------------------|-------------------|
| AU | Predominantly USD (S&P 500) | ✅ Yes — AUD/USD hedge to reduce income volatility |
| US | USD | No — domestic currency |
| NZ | Predominantly USD | ✅ Yes — NZD/USD hedge |
| UK | Mixed USD/GBP | ✅ Partial — hedge non-GBP exposure |

**Hedging cost:** ~0.5-1.5% p.a. depending on interest rate differential. Factored into lender margin.

### 7.4 Rebalancing

All portfolios rebalanced quarterly to target allocation. Rebalancing triggers:

- Drift >5% from target allocation
- Scheduled quarterly rebalance date
- Market stress event (>10% drawdown triggers review)

---

## 8. LTV Tiers & Eligibility

### 8.1 LTV by Variant

| Variant | Max LTV | Min Property Value | Min Age | Max Existing Mortgage |
|---------|---------|-------------------|---------|----------------------|
| Standard | 80% | $500,000 | 60 | 20% of value |
| Growth | 70% | $500,000 | 55 | 10% of value |
| Flex | 60% | $600,000 | 55 | 0% (must own outright) |
| Protect | 50% | $400,000 | 65 | 10% of value |
| Legacy | 80% | $500,000 | 60 | 20% of value |

### 8.2 Age-Adjusted LTV

Older consumers can access higher LTV because the expected term is shorter (lower lender risk):

| Age | Standard Max LTV | Protect Max LTV |
|-----|-----------------|-----------------|
| 55-59 | 60% | N/A |
| 60-64 | 70% | 40% |
| 65-69 | 75% | 45% |
| 70-74 | 80% | 50% |
| 75-79 | 80% | 50% |
| 80+ | 75% (declining — maintenance risk) | 45% |

### 8.3 Eligibility Criteria (All Variants)

| Criterion | Requirement |
|-----------|-------------|
| Property type | Residential, owner-occupied, single dwelling |
| Property condition | Habitable, structurally sound, insured |
| Occupancy | Consumer must live in property as primary residence |
| Existing mortgage | Must be discharged from EPM proceeds (or below max threshold) |
| Legal capacity | Consumer must have capacity to enter contract |
| Independent advice | Required (AU: AFSL adviser, US: HUD counselor, NZ: FAP, UK: ERC adviser) |
| Joint applicants | Both must meet age requirements; youngest age used for LTV |

---

## 9. Regional Adaptations

### 9.1 Australia

| Adaptation | Detail |
|-----------|--------|
| **Centrelink disclosure** | Mandatory Centrelink impact estimate in quote |
| **AFSL adviser requirement** | Advised sales only (if AFSL classification) |
| **Franking credits** | AU equity allocation benefits from franking |
| **Property types** | Exclude: farms, rural (>5 acres), strata with <4 units |

### 9.2 United States

| Adaptation | Detail |
|-----------|--------|
| **HUD counseling** | Required for any product resembling reverse mortgage |
| **State-by-state rollout** | Phase 1: CA, NY, FL, AZ. Phase 2: TX, WA, IL, MA |
| **Non-recourse by law** | Several states mandate non-recourse for senior mortgages |
| **No-income-tax states** | Highlight tax-free benefit in FL, TX, AZ marketing |
| **Property types** | Include condos (with HOA review), exclude co-ops initially |

### 9.3 New Zealand

| Adaptation | Detail |
|-----------|--------|
| **No pension impact** | Market as "income that doesn't affect your NZ Super" |
| **Relationship property** | Both partners must consent (PRA 1976) |
| **Leasehold land** | Common in NZ — must assess remaining lease term (>50 years required) |
| **Weathertightness** | Properties must pass weather-tightness assessment (leaky buildings crisis legacy) |

### 9.4 United Kingdom

| Adaptation | Detail |
|-----------|--------|
| **ERC membership** | Mandatory for credibility and NNEG compliance |
| **Advised sales only** | FCA requires advice for lifetime mortgage products |
| **IHT calculator** | Must show IHT impact in every quote |
| **Leasehold** | Common in England/Wales — minimum 80 years remaining lease |
| **Scotland** | Different property law (Scots law) — separate legal review |
| **Right to remain** | Must survive consumer into protected tenancy |

---

## 10. Payout Structures

### 10.1 Monthly Income (Standard, Protect, Legacy)

```
Fixed monthly amount, reviewed annually.
Year 1: $1,000/month (set at inception based on quote model)
Year 2: $1,050/month (adjusted for portfolio performance + CPI)
Year 3: $980/month (portfolio underperformed — reduced, but floor applies for Protect)
```

### 10.2 Quarterly Income (Optional for Standard, Legacy)

Some consumers prefer quarterly payments (aligns with rates/insurance cycles):

```
Q1: $3,150 (Jan)
Q2: $3,150 (Apr)
Q3: $3,150 (Jul)
Q4: $3,150 (Oct)
```

### 10.3 Drawdown (Flex)

```
Consumer requests drawdown via portal or phone.
Minimum: $5,000
Maximum: 20% of current portfolio value per year
Processing: 5 business days
Funds to: Nominated bank account
```

### 10.4 Lump Sum + Income (Hybrid)

Available on Standard and Legacy variants:

```
At inception:
  Lump sum:     $50,000 (for home renovations, debt clearance)
  Remaining:    $590,000 invested in portfolio

Monthly income: $900/month (reduced due to lower portfolio base)
```

Lump sum capped at 15% of total mortgage to preserve income viability.

### 10.5 Inflation Adjustment

| Method | Detail | Used By |
|--------|--------|---------|
| **CPI-linked** | Income adjusted annually by regional CPI | Standard, Legacy |
| **Fixed escalation** | Income increases 2% p.a. regardless of CPI | Protect (predictability) |
| **Performance-linked** | Income adjusts based on actual portfolio return | Growth (after deferral) |

---

## 11. Product Comparison Matrix

| Feature | Standard | Growth | Flex | Protect | Legacy |
|---------|----------|--------|------|---------|--------|
| **Monthly income** | ✅ From day 1 | ❌ Deferred 5-10 yrs | ❌ On-demand | ✅ From day 1 | ✅ Reduced |
| **Income level** | Medium | High (after deferral) | Variable | Low | Low-Medium |
| **Risk profile** | Medium | Medium-High | Medium | Low | High |
| **Max LTV** | 80% | 70% | 60% | 50% | 80% |
| **Min age** | 60 | 55 | 55 | 65 | 60 |
| **Income floor** | ❌ | ❌ | ❌ | ✅ 80% minimum | ❌ |
| **Estate optimised** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Lump sum option** | ✅ (15% max) | ❌ | ✅ (core feature) | ❌ | ✅ (15% max) |
| **Best for** | Regular income | Future income | Flexibility | Peace of mind | Inheritance |
| **Launch phase** | Phase 1 | Phase 2 | Phase 2 | Phase 2 | Phase 3 |

---

## 12. Implementation Roadmap

### Phase 1 — MVP (Month 1-6)

**EPM Standard only.** Single product, all four regions.

- [ ] Standard variant fully modelled (Pavel + Tom models)
- [ ] Monthly income payout engine
- [ ] Annual review process
- [ ] NNEG calculation and disclosure
- [ ] Quote engine shows Standard projections
- [ ] Advised sales workflow (all regions)

### Phase 2 — Expansion (Month 7-12)

**Add Growth, Flex, and Protect variants.**

- [ ] Growth variant: deferral period logic, compounding model
- [ ] Flex variant: drawdown engine, liquidity management, balance tracking
- [ ] Protect variant: income floor calculation, margin reserve modelling
- [ ] Variant selector in quote engine ("Which EPM suits you?")
- [ ] Adviser guidance: risk assessment → variant recommendation
- [ ] Portfolio strategy selection per variant

### Phase 3 — Full Suite (Month 13-18)

**Add Legacy and hybrid options.**

- [ ] Legacy variant: estate projection, surplus guarantee
- [ ] UK IHT optimisation calculator (Legacy + s21 gifting)
- [ ] Hybrid payout structures (lump sum + income)
- [ ] Quarterly payout option
- [ ] Inflation adjustment methods (CPI, fixed, performance)
- [ ] Variant switching (consumer can change variant mid-term, subject to conditions)

### Phase 4 — Advanced (Month 19+)

- [ ] Custom portfolio allocation (consumer selects from approved models)
- [ ] Couple structures (different variants for each partner)
- [ ] Portfolio dashboard for consumers (read-only view of investment performance)
- [ ] Secondary market (transfer EPM to another property on downsizing)
- [ ] Commercial property EPM (separate product line)

---

*Each variant must be independently modelled, stress-tested, and approved by legal/compliance before consumer launch. The Pavel financial model (v10 spreadsheet) currently covers Standard only — Growth, Flex, Protect, and Legacy require separate model extensions.*
