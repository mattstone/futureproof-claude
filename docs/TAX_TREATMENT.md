# Tax Treatment — FutureProof EPM (All Regions)

**Version:** 1.0  
**Created:** 2026-03-06  
**Scope:** Income tax, capital gains, estate/inheritance tax, portfolio taxation, and consumer disclosure obligations across AU, US, NZ, and UK  
**Disclaimer:** This document is for product design and platform disclosure purposes. It does not constitute tax advice. All consumers must be directed to seek independent tax advice.

---

## Table of Contents

1. [EPM Income — Tax Classification](#1-epm-income--tax-classification)
2. [Australia](#2-australia)
3. [United States](#3-united-states)
4. [New Zealand](#4-new-zealand)
5. [United Kingdom](#5-united-kingdom)
6. [Portfolio Ownership — The Critical Decision](#6-portfolio-ownership--the-critical-decision)
7. [Estate & Inheritance Tax](#7-estate--inheritance-tax)
8. [Cross-Regional Comparison](#8-cross-regional-comparison)
9. [Platform Disclosure Requirements](#9-platform-disclosure-requirements)
10. [Implementation Checklist](#10-implementation-checklist)

---

## 1. EPM Income — Tax Classification

The fundamental tax question for EPM is: **What is the monthly income the consumer receives?**

There are two possible classifications:

| Classification | Tax Treatment | Analogy |
|----------------|---------------|---------|
| **Loan proceeds** (advances from mortgage) | **Not taxable** | Reverse mortgage / HECM draws |
| **Investment income** (returns from portfolio) | **Taxable** | Managed fund distributions |

**The answer depends on product structure and jurisdiction.**

### 1.1 The Core Mechanism

```
Consumer's home → Mortgage (80% LTV) → Loan funds → Investment portfolio
                                                          ↓
                                     Monthly income ← Portfolio returns
                                          ↓
                              Consumer receives income
```

**Key question:** Is the monthly payment to the consumer:
- (a) A **loan advance** (the lender draws down the mortgage and pays the consumer), or
- (b) An **investment distribution** (the portfolio generates returns paid to the consumer)?

**Product design recommendation:** Structure as **(a) loan advances** wherever possible. This provides the most favourable tax treatment in all jurisdictions.

---

## 2. Australia

### 2.1 Income Tax

| Income Stream | Tax Treatment | Authority |
|---------------|---------------|-----------|
| EPM monthly income (as loan proceeds) | **Not assessable income** | ATO — loan proceeds are not income (TR 2005/2) |
| EPM monthly income (as investment distributions) | **Assessable income** at marginal rate | ITAA 1997 s6-5 (ordinary income) |
| Interest on EPM mortgage (accrued) | Not deductible (no nexus to assessable income) | ITAA 1997 s8-1 |
| Capital gains on portfolio (if consumer owns) | **CGT event** on disposal | ITAA 1997 Div 104 |
| Capital gains on portfolio (if lender/trust owns) | Not consumer's event | N/A |

### 2.2 If Structured as Loan Proceeds (Recommended)

The consumer receives regular advances from their mortgage. These are **not income** under Australian tax law, the same way drawing down a home equity line of credit is not income.

**Tax-free monthly income** — the strongest consumer selling point.

**Conditions for this treatment:**
- EPM must be a genuine credit facility (not disguised income)
- Loan is secured against the property (registered mortgage)
- Consumer has a genuine obligation to repay (even if only from property sale proceeds)
- Non-recourse feature does not change the income characterisation — it limits the *enforcement*, not the *obligation*

### 2.3 Centrelink / Age Pension Impact

**This is a critical disclosure issue for Australian consumers.**

| Means Test | Impact |
|------------|--------|
| **Income test** | Loan proceeds are NOT income for Centrelink. However, if proceeds are invested and earn returns, those returns ARE deemed income. |
| **Assets test** | The investment portfolio IS an assessable asset. At 80% LTV on a $800,000 home, the portfolio (~$640,000) exceeds the assets test threshold for full pension. |
| **Deeming rate** | Financial assets above threshold are deemed to earn income at the deeming rate (currently 0.25% on first $60,400, 2.25% above). |

**Example — Single homeowner, $800,000 property:**

| Without EPM | With EPM |
|-------------|----------|
| Home: exempt asset | Home: exempt asset |
| Financial assets: $50,000 | Financial assets: $690,000 (existing $50K + $640K portfolio) |
| Deemed income: ~$153/fn | Deemed income: ~$856/fn |
| Pension: Full rate | Pension: **Significantly reduced or NIL** |

**Disclosure requirement:** Consumer must be told that EPM may reduce or eliminate their Age Pension entitlement. This must appear in the Key Facts Sheet, the quote summary, and be confirmed during the advised sales process.

### 2.4 Capital Gains Tax (CGT)

| Event | CGT Treatment |
|-------|---------------|
| Property sale (to repay EPM) | Main residence exemption applies — **no CGT** |
| Portfolio disposal (if consumer owns) | CGT at marginal rate, 50% discount if held >12 months |
| Portfolio disposal (if lender/trust owns) | Not consumer's CGT event |
| EPM termination/rollover | No CGT event on the loan itself |

### 2.5 GST

EPM is a **financial supply** — input-taxed under GST. No GST is charged on EPM income or fees. Reduced input tax credits (RITCs) of 75% apply to related acquisitions.

---

## 3. United States

### 3.1 Federal Income Tax

**The US provides the cleanest tax treatment for EPM.**

| Income Stream | Tax Treatment | IRS Form |
|---------------|---------------|----------|
| EPM monthly income (loan proceeds) | **NOT taxable** | None — loan proceeds are not income |
| Investment returns (if consumer owns portfolio) | Taxable (ordinary income or capital gains) | 1099-DIV, 1099-B |
| Investment returns (if lender/trust owns portfolio) | Not consumer's income | N/A |
| Mortgage interest (consumer pays nothing) | No deduction available during EPM term | No 1098 issued |
| Accrued interest (paid at termination) | Potentially deductible when actually paid | 1098 at termination |

**This is EPM's most powerful US selling point: tax-free monthly income.**

The treatment mirrors HECM reverse mortgage advances, which the IRS has long accepted as non-taxable loan proceeds.

### 3.2 State Income Tax

| State | Income Tax | EPM Benefit |
|-------|-----------|-------------|
| **Florida** | None | EPM income completely untaxed |
| **Texas** | None | EPM income completely untaxed |
| **Arizona** | 2.5% flat | Minimal impact (and loan proceeds aren't income anyway) |
| **California** | Up to 13.3% | Significant benefit — loan proceeds avoid state income tax |
| **New York** | Up to 10.9% | Significant benefit — loan proceeds avoid state income tax |

**For high-tax states (CA, NY), the tax-free nature of EPM income is an enormous differentiator** versus drawing down retirement accounts (taxable) or selling investments (capital gains).

### 3.3 Social Security & Medicare

| Benefit | Impact |
|---------|--------|
| **Social Security** | Loan proceeds do NOT count toward provisional income. EPM does not trigger taxation of Social Security benefits. |
| **Medicare Part B premiums** | IRMAA surcharges based on Modified Adjusted Gross Income (MAGI). Loan proceeds not included in MAGI — no premium increase. |
| **Medicaid** | Asset test applies. Portfolio is a countable asset — may affect Medicaid eligibility (long-term care). Disclosure required. |

### 3.4 Estate Tax (Federal)

| Threshold | Amount (2026) |
|-----------|---------------|
| Federal exemption | ~$7 million (post-TCJA sunset, reverts from ~$13M) |
| Estate tax rate | 40% above exemption |
| Portability | Unused exemption transfers to surviving spouse |

**EPM Impact on Estate:**
- Property: included in estate at FMV
- Less: EPM mortgage balance (liability reduces taxable estate)
- Plus: Investment portfolio value (asset in estate)
- Net effect: Depends on portfolio growth vs. mortgage balance

**For most EPM consumers** (property <$2M), federal estate tax will not apply even with the lower exemption. State-level estate taxes (in states that have them) may be relevant.

### 3.5 1099 Reporting

FutureProof or the lender must issue:
- **No 1099 for loan proceeds** — not reportable income
- **1099-INT** at loan termination (if accrued interest is deductible)
- **1099-DIV / 1099-B** only if consumer directly owns portfolio and receives distributions

---

## 4. New Zealand

### 4.1 Income Tax

| Income Stream | Tax Treatment | Rate |
|---------------|---------------|------|
| EPM monthly income (loan proceeds) | **Not assessable** (if structured as loan) | N/A |
| EPM monthly income (investment distributions) | **Assessable** at marginal rate | 10.5% - 39% |
| Portfolio returns (if consumer owns) | Taxable under FIF rules (if offshore ETFs) | Marginal rate on deemed income |
| Portfolio returns (if lender/trust owns) | Not consumer's income | N/A |

### 4.2 Foreign Investment Fund (FIF) Rules — Critical Issue

**If the investment portfolio includes offshore ETFs (e.g., S&P 500), NZ's FIF regime applies.**

| Rule | Detail |
|------|--------|
| **Threshold** | Total FIF interests >$50,000 (NZD) |
| **FDR method** | Fair Dividend Rate — 5% of opening market value is deemed income |
| **Tax rate** | Consumer's marginal rate (10.5% - 39%) |
| **Who pays** | The person who *owns* the FIF interest |

**Example — $640,000 NZD portfolio in S&P 500 ETFs:**

```
Opening value:     $640,000
FDR deemed income: $640,000 × 5% = $32,000
Tax at 33%:        $10,560 per year
```

**This is a $10,560/year tax liability even if the portfolio returned 0% that year.**

**Critical product design implication:** If the consumer owns the portfolio, they face FIF tax annually — reducing their net EPM income by ~$880/month in this example. This significantly erodes the value proposition.

**Recommended structure for NZ:** Lender or trust entity owns the portfolio. Consumer receives loan advances only. FIF tax falls on the entity, factored into the lender margin — not a surprise annual bill for the consumer.

### 4.3 NZ Superannuation

| Factor | Treatment |
|--------|-----------|
| Loan proceeds | NOT income — does not reduce NZ Super |
| NZ Super itself | Taxed as income (PAYE) |
| Asset test | **NZ Super has no asset test** — EPM portfolio does not affect entitlement |

**NZ is significantly more favourable than Australia** — no means testing on NZ Super means EPM does not reduce retirement benefits.

### 4.4 Residential Care Subsidy

| Factor | Impact |
|--------|--------|
| Asset test threshold | ~$240,000 (single, 2025) |
| EPM portfolio | IS a countable asset — exceeds threshold |
| Home | May be exempt while spouse occupies |
| Impact | EPM consumers unlikely to qualify for residential care subsidy |

**Disclosure required:** EPM may affect eligibility for residential care subsidies.

---

## 5. United Kingdom

### 5.1 Income Tax

| Income Stream | Tax Treatment | Rate |
|---------------|---------------|------|
| EPM monthly income (loan proceeds) | **Not taxable** | N/A |
| EPM monthly income (investment distributions) | Assessable | 20% basic / 40% higher / 45% additional |
| Dividends (if consumer owns portfolio) | Dividend allowance £1,000 (2024/25), then dividend rates | 8.75% / 33.75% / 39.35% |
| Capital gains (if consumer owns portfolio) | CGT on disposal above £6,000 annual exempt amount | 10% / 20% (or 18% / 24% for residential property) |

### 5.2 Inheritance Tax (IHT) — Major Selling Point

**UK IHT at 40% above £325,000 (nil-rate band) makes EPM uniquely attractive.**

| Scenario | Estate Calculation |
|----------|-------------------|
| **Without EPM** | Home £800K + other assets £200K = £1M estate. Less NRB+RNRB £500K = £500K taxable. **IHT: £200,000** |
| **With EPM** | Home £800K − mortgage £640K + portfolio £720K + other £200K = £1.08M. Less NRB+RNRB £500K = £580K taxable. **IHT: £232,000** |

**The headline IHT number may increase — but the consumer has received potentially £600,000+ in tax-free income over 20 years.** Income spent during lifetime is NOT in the estate.

**Real comparison:**

| Factor | Without EPM | With EPM |
|--------|-------------|----------|
| Income received (lifetime) | £0 from home equity | ~£600,000 (tax-free) |
| Estate value at death | £1,000,000 | ~£1,080,000 |
| IHT payable | £200,000 | £232,000 |
| **Net benefit to family** | £800,000 estate | £600,000 income consumed + £848,000 estate = **£1,448,000 total value** |

**EPM delivers £648,000 more total value to the consumer and their family** in this scenario.

### 5.3 IHT Planning Opportunities

| Strategy | Detail |
|----------|--------|
| **Gift from income exemption** | EPM income spent on regular gifts is IHT-exempt (IHTA 1984 s21) |
| **7-year rule** | Lump sum gifts from EPM income fall out of estate after 7 years |
| **Charity exemption** | EPM income donated to charity reduces estate and IHT rate (to 36% if 10%+ left to charity) |
| **Spousal transfer** | No IHT between spouses — EPM on joint property follows normal spousal exemption |

### 5.4 State Pension

| Factor | Treatment |
|--------|-----------|
| State Pension | Qualification based on NI record, NOT means-tested |
| Pension Credit | IS means-tested — EPM portfolio is a countable asset |
| Council Tax Reduction | Local authority means test — EPM portfolio is countable |

**Disclosure:** EPM may affect eligibility for means-tested benefits including Pension Credit and Council Tax Reduction.

### 5.5 Stamp Duty Land Tax (SDLT)

EPM itself does not trigger SDLT (no property transfer). If the property is sold to repay the EPM, normal SDLT rules apply to the buyer — not the EPM consumer.

---

## 6. Portfolio Ownership — The Critical Decision

**This is the most consequential product design decision affecting tax treatment in all four regions.**

### 6.1 Three Models

| Model | Description | Tax Impact |
|-------|-------------|------------|
| **A. Consumer owns portfolio** | Consumer holds ETF units directly | Consumer bears all investment income tax, CGT, FIF (NZ) |
| **B. Lender owns portfolio** | Lender/SPV holds investments, pays consumer loan advances | Consumer has NO tax on investment returns; lender factors into margin |
| **C. Trust structure** | Purpose trust holds portfolio for consumer's benefit | Depends on trust type and jurisdiction — complex |

### 6.2 Recommendation by Region

| Region | Recommended Model | Reason |
|--------|-------------------|--------|
| **AU** | **B (Lender owns)** | Avoids assessable income, avoids Centrelink deeming on portfolio |
| **US** | **B (Lender owns)** | Clean — loan proceeds not taxable, no 1099 burden |
| **NZ** | **B (Lender owns)** | **Critical** — avoids FIF tax ($10K+/year on consumer) |
| **UK** | **B (Lender owns)** | Avoids dividend/CGT tax, simplifies IHT calculation |

**Model B is recommended for all regions.** It provides:
1. Tax-free income to consumer (loan proceeds only)
2. No annual tax compliance burden on consumer
3. Simpler consumer-facing product (no portfolio tax statements)
4. Lender absorbs portfolio tax into margin calculation

**Trade-off:** Model B means the consumer does not "own" the investments. The lender bears investment risk and tax, priced into the margin. Consumer gives up potential upside above the guaranteed income rate.

### 6.3 Impact on Net Income to Consumer

| Model | Monthly Income (on $640K portfolio) | Tax Payable by Consumer | Net After Tax |
|-------|--------------------------------------|------------------------|---------------|
| **A (Consumer owns)** — AU | $2,500 | ~$600/month (deeming + marginal rate) | ~$1,900 |
| **A (Consumer owns)** — NZ | $2,500 | ~$880/month (FIF) | ~$1,620 |
| **B (Lender owns)** — All | $2,200 (lower due to margin) | **$0** | **$2,200** |

**Model B delivers higher net income** in AU and NZ despite lower gross income, because consumer pays zero tax.

---

## 7. Estate & Inheritance Tax — Full Comparison

### 7.1 Summary by Region

| Region | Estate/Death Tax | Rate | Threshold | EPM Impact |
|--------|-----------------|------|-----------|------------|
| **AU** | **None** (no inheritance tax) | N/A | N/A | No estate tax impact. CGT on inherited assets with cost base reset. |
| **US** | Federal estate tax | 40% | ~$7M (2026 post-TCJA) | Below threshold for most EPM consumers |
| **NZ** | **None** (no estate or gift duty) | N/A | N/A | No estate tax impact |
| **UK** | Inheritance Tax (IHT) | 40% | £325K (+£175K RNRB) | **Major factor** — EPM mortgage reduces estate but portfolio adds back |

### 7.2 UK-Specific IHT Modelling

The platform must provide IHT impact modelling for UK consumers. Required calculations:

```ruby
# Simplified IHT model for UK EPM quotes
def iht_impact(property_value:, ltv:, years:, growth_rate:, income_rate:, other_assets:)
  mortgage = property_value * ltv
  portfolio_end = mortgage * ((1 + growth_rate) ** years)
  total_income_paid = mortgage * income_rate * years  # Consumed, not in estate
  
  # Estate at death
  estate = property_value + portfolio_end + other_assets - mortgage_balance_at_death
  
  # IHT (simplified — ignoring RNRB qualification nuances)
  nrb = 325_000
  rnrb = 175_000
  taxable = [estate - nrb - rnrb, 0].max
  iht = taxable * 0.40
  
  { estate:, iht:, total_income_received: total_income_paid }
end
```

---

## 8. Cross-Regional Comparison

### 8.1 Tax Treatment Matrix

| Factor | AU | US | NZ | UK |
|--------|-----|-----|-----|-----|
| **EPM income taxable?** | No (loan proceeds) | No (loan proceeds) | No (loan proceeds) | No (loan proceeds) |
| **Portfolio tax (Model B)** | Lender pays | Lender pays | Lender pays (avoids FIF) | Lender pays |
| **Retirement benefit impact** | ⚠️ **Age Pension reduced** (assets test) | ⚠️ Medicaid affected | ✅ **NZ Super unaffected** | ⚠️ Pension Credit affected |
| **Estate/death tax** | None | 40% above ~$7M | None | 40% above £500K |
| **CGT on property sale** | Exempt (main residence) | Exempt (up to $500K, §121) | Exempt (main residence) | Exempt (PPR relief) |
| **Consumer tax compliance** | None (Model B) | None (Model B) | None (Model B) | None (Model B) |

### 8.2 Best-to-Worst Tax Jurisdictions for EPM

1. **New Zealand** — No income tax on proceeds, no estate tax, no pension impact, no CGT. Best jurisdiction.
2. **United States (FL, TX, AZ)** — No income tax (federal or state), no estate tax for most, Social Security unaffected. Near-perfect in no-income-tax states.
3. **United States (CA, NY)** — Same federal treatment but state complexity around lender taxation.
4. **Australia** — Tax-free income BUT Centrelink impact is a significant negative for pension-age consumers.
5. **United Kingdom** — Tax-free income BUT IHT complexity requires careful modelling and disclosure.

---

## 9. Platform Disclosure Requirements

### 9.1 Mandatory Disclosures (All Regions)

Every EPM quote and application must include:

| Disclosure | Wording (Template) |
|------------|-------------------|
| **Tax advice** | "This product may have tax implications. The information provided is general in nature and does not constitute tax advice. You should seek independent tax advice before proceeding." |
| **Retirement benefits** | "[Region-specific] Your EPM may affect your eligibility for [Age Pension / Social Security / NZ Super / Pension Credit]. We recommend consulting [Centrelink / SSA / MSD / DWP] before proceeding." |
| **Estate impact** | "Your EPM will affect the value of your estate. We recommend discussing the estate implications with your solicitor or estate planner." |
| **Portfolio ownership** | "The investment portfolio is owned and managed by [lender/entity]. You receive monthly income as loan advances secured against your property." |

### 9.2 Region-Specific Disclosures

| Region | Additional Disclosure |
|--------|----------------------|
| **AU** | "Your EPM portfolio is an assessable asset for Centrelink purposes and may reduce your Age Pension entitlement. Deemed income from the portfolio will be included in your Centrelink income assessment." |
| **US** | "EPM loan advances are not taxable income for federal or state income tax purposes. No tax forms (1099) will be issued for your monthly income." |
| **NZ** | "Your EPM income (as loan advances) is not assessable income and does not affect your NZ Superannuation entitlement. However, the investment portfolio may affect eligibility for Residential Care Subsidy." |
| **UK** | "Your EPM may affect Inheritance Tax calculations for your estate. The mortgage liability reduces your estate value, but the investment portfolio may increase it. We recommend consulting a tax adviser. Your EPM does not affect your State Pension." |

### 9.3 Quote Engine Integration

The quote/calculator output must show:

```
Monthly income:          $2,200
Tax on EPM income:       $0 (loan proceeds — not taxable)
Estimated pension impact: [calculated per region]
Estate impact summary:   [calculated per region, UK only shows IHT]

⚠️ Seek independent tax advice before proceeding.
```

---

## 10. Implementation Checklist

### Platform Features Required

- [ ] **Tax disclaimer** on all quotes, applications, and marketing materials
- [ ] **Region-specific tax summary** in quote output (calculate pension impact per region)
- [ ] **UK IHT calculator** — Show before/after IHT estimate in quote engine
- [ ] **AU Centrelink estimator** — Show estimated pension impact based on portfolio size
- [ ] **NZ FIF disclosure** — If Model A is ever used, show FIF tax estimate
- [ ] **US state tax summary** — Show "no state income tax" benefit for FL/TX/AZ
- [ ] **Annual tax summary** — Generate downloadable statement for consumer's tax return (even if nil for Model B)
- [ ] **"Seek independent advice" prompt** — Required at quote, application, and contract stages
- [ ] **Portfolio ownership disclosure** — Clear statement of who owns investments

### Legal/Regulatory Actions

- [ ] **AU:** Confirm ATO treatment of EPM loan proceeds (private ruling or product ruling)
- [ ] **US:** Confirm IRS treatment mirrors HECM (engage tax counsel)
- [ ] **NZ:** Confirm IRD treatment; resolve FIF implications for Model B entity
- [ ] **UK:** Confirm HMRC treatment; IHT modelling validated by tax counsel
- [ ] **All regions:** Portfolio ownership structure finalised (Model B recommended)

### Unresolved Questions

| Question | Impact | Owner |
|----------|--------|-------|
| Portfolio ownership model (A/B/C) — final decision | Affects tax in ALL regions | Product/Legal |
| AU: Does NNEG (no negative equity guarantee) affect ATO loan characterisation? | Could reclassify as financial product | AU tax counsel |
| NZ: If lender entity owns portfolio, which entity? AU parent? NZ subsidiary? | FIF and corporate tax implications | NZ tax counsel |
| UK: Does EPM qualify for RNRB (passing residence to descendants)? | £175K additional IHT exemption at stake | UK tax counsel |
| US: If TCJA sunsets in 2026, estate tax exemption halves — update modelling | US estate tax becomes relevant for more consumers | US tax counsel |

---

*This document consolidates tax treatment from the four regional compliance documents. It should be reviewed by qualified tax advisers in each jurisdiction before product launch. Update annually or when tax legislation changes.*
