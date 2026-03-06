# Insurance Framework — FutureProof EPM

**Version:** 1.0  
**Created:** 2026-03-06  
**Scope:** Insurance requirements, consumer obligations, lender protections, and portfolio insurance across AU, US, NZ, and UK

---

## Table of Contents

1. [Insurance in the EPM Structure](#1-insurance-in-the-epm-structure)
2. [Property Insurance (Mandatory)](#2-property-insurance-mandatory)
3. [Title Insurance](#3-title-insurance)
4. [Mortgage Protection Insurance](#4-mortgage-protection-insurance)
5. [Portfolio Insurance & Hedging](#5-portfolio-insurance--hedging)
6. [NNEG Insurance (Lender Side)](#6-nneg-insurance-lender-side)
7. [Consumer Life & Health Insurance](#7-consumer-life--health-insurance)
8. [Professional Indemnity & Platform Insurance](#8-professional-indemnity--platform-insurance)
9. [Regional Requirements](#9-regional-requirements)
10. [Implementation Checklist](#10-implementation-checklist)

---

## 1. Insurance in the EPM Structure

EPM creates a multi-layered insurance picture. The property secures the mortgage, the portfolio generates income, and the NNEG guarantee exposes the lender to tail risk. Insurance is required at every layer.

```
┌──────────────────────────────────────────────────┐
│                  CONSUMER LAYER                   │
│  Buildings insurance (mandatory)                  │
│  Contents insurance (recommended)                 │
│  Life insurance (optional — may reduce premiums)  │
└──────────────────────────┬───────────────────────┘
                           │
┌──────────────────────────▼───────────────────────┐
│                  PROPERTY LAYER                   │
│  Title insurance (US: standard, others: optional) │
│  Flood/natural disaster cover                     │
│  Subsidence/structural cover                      │
└──────────────────────────┬───────────────────────┘
                           │
┌──────────────────────────▼───────────────────────┐
│                 PORTFOLIO LAYER                   │
│  No direct insurance — managed via hedging        │
│  Put options / tail-risk hedging                  │
│  Currency hedging (non-USD regions)               │
└──────────────────────────┬───────────────────────┘
                           │
┌──────────────────────────▼───────────────────────┐
│                  LENDER LAYER                     │
│  NNEG reserve / reinsurance                       │
│  Professional indemnity                           │
│  Cyber insurance                                  │
│  Directors & officers (D&O)                       │
└──────────────────────────────────────────────────┘
```

---

## 2. Property Insurance (Mandatory)

### 2.1 Requirement

**All EPM consumers must maintain buildings insurance for the duration of the EPM.** This is a standard mortgage condition — the property is the lender's security.

| Requirement | Detail |
|-------------|--------|
| Cover type | Buildings insurance (not just contents) |
| Minimum cover | Full reinstatement value (not market value) |
| Named interest | Lender noted as interested party on policy |
| Continuity | Must be maintained continuously — lapse is an EPM default event |
| Evidence | Annual proof of insurance provided to lender |
| Excess | Maximum excess of $2,500 / £2,000 |

### 2.2 What Must Be Covered

| Peril | Required? | Notes |
|-------|-----------|-------|
| Fire | ✅ | Standard |
| Storm/flood | ✅ | Regional — see flood zone requirements |
| Earthquake | ✅ (NZ, CA) | Mandatory in seismic regions |
| Subsidence | ✅ (UK) | Critical for UK properties |
| Impact (vehicle, aircraft) | ✅ | Standard |
| Burst pipes/water damage | ✅ | Standard |
| Theft/vandalism damage | ✅ | Structural damage only |
| Natural disaster | ✅ | Regional coverage varies |

### 2.3 Flood Zone Properties

| Region | Flood Risk Assessment | EPM Policy |
|--------|----------------------|------------|
| AU | Flood maps (state-based) | High flood risk: LTV capped at 60%, insurance must include flood |
| US | FEMA flood maps | Zone A/V: Flood insurance mandatory (NFIP or private). Zone X: standard. |
| NZ | Council flood hazard maps | Known flood-prone: LTV capped at 60% |
| UK | Environment Agency flood maps | Flood Re scheme available for residential. High risk: LTV capped at 60% |

### 2.4 Consumer Obligation

The EPM contract must include:

```
INSURANCE COVENANT

The Borrower shall:
(a) Maintain buildings insurance with a reputable insurer for the full 
    reinstatement value of the Property;
(b) Note the Lender as an interested party on the policy;
(c) Provide evidence of current insurance annually by [date];
(d) Not allow the policy to lapse, be cancelled, or materially altered 
    without the Lender's written consent;
(e) Notify the Lender within 14 days of any claim, change of insurer, 
    or material change to the policy.

BREACH: Failure to maintain insurance is an Event of Default. The Lender 
may arrange insurance at the Borrower's cost and add the premium to the 
mortgage balance.
```

### 2.5 Lender-Placed Insurance (Force-Placed)

If the consumer fails to maintain insurance:

| Step | Timeline | Action |
|------|----------|--------|
| 1 | Day 0 | Insurance lapse detected (annual check or notification) |
| 2 | Day 1 | Written notice to consumer: "Reinstate insurance within 30 days" |
| 3 | Day 30 | If not reinstated: lender places insurance on consumer's behalf |
| 4 | Ongoing | Premium added to mortgage balance (typically 2-3× consumer's cost) |
| 5 | Review | If consumer reinstates own policy, lender-placed cover cancelled |

**Platform feature:** Automated insurance expiry tracking with 60-day, 30-day, and 14-day reminders to consumer.

---

## 3. Title Insurance

### 3.1 By Region

| Region | Title Insurance | Status | Cost |
|--------|----------------|--------|------|
| **US** | **Standard practice** — virtually all mortgage transactions | Required | $1,000-$3,000 (one-off) |
| **AU** | Available but uncommon — Torrens title system provides statutory guarantee | Recommended | $300-$800 |
| **NZ** | Available but uncommon — Torrens system | Optional | $300-$600 |
| **UK** | Growing market — protects against title defects, fraud, boundary disputes | Recommended | £200-£500 |

### 3.2 Why Title Insurance Matters for EPM

EPM has a longer expected term than standard mortgages (15-30 years vs 5-7 year average hold). Over this period:

- Boundary disputes may emerge
- Planning/zoning changes may affect value
- Historical title defects may surface
- Fraud risk increases with time (identity theft, forged transfers)

**Recommendation:** Require title insurance for US (standard). Strongly recommend for AU, NZ, UK. Cost is one-off and modest relative to portfolio size.

---

## 4. Mortgage Protection Insurance

### 4.1 Traditional MPI vs EPM

Traditional mortgage protection insurance (MPI) pays out on death/disability to clear the mortgage. For EPM:

| Factor | Traditional Mortgage | EPM |
|--------|---------------------|-----|
| Consumer makes repayments | Yes — MPI covers repayments | No — consumer pays nothing |
| Death triggers repayment | Loan called in | Loan called in (same) |
| MPI purpose | Protect family from losing home | Protect estate from mortgage debt |
| NNEG alternative | No NNEG — full debt owed | NNEG caps debt at property value |

### 4.2 Is MPI Needed for EPM?

**Generally no.** The NNEG guarantee provides the protection that MPI would normally offer:

- Consumer dies → NNEG ensures estate owes ≤ property value
- Consumer can't make repayments → There are no repayments to make
- Property value declines → Lender absorbs loss, not estate

**Exception:** If the consumer wants to guarantee that beneficiaries inherit the property **mortgage-free**, a decreasing term life policy could be structured to pay off the EPM balance at death. This is optional and consumer-funded.

### 4.3 Platform Disclosure

```
MORTGAGE PROTECTION INSURANCE

FutureProof EPM includes a No Negative Equity Guarantee (NNEG). This means 
your estate will never owe more than your property is worth when the EPM 
is settled.

Because of the NNEG, mortgage protection insurance is NOT required for 
your EPM. However, if you wish to ensure your beneficiaries inherit your 
property entirely mortgage-free, you may choose to arrange a life insurance 
policy separately. This is optional and not a condition of your EPM.

We recommend discussing this with your financial adviser.
```

---

## 5. Portfolio Insurance & Hedging

### 5.1 The Portfolio Cannot Be "Insured" Traditionally

Investment portfolios are not insurable assets — you cannot buy a policy that pays out when the market drops. Instead, portfolio risk is managed through:

| Mechanism | How It Works | Cost |
|-----------|-------------|------|
| **Diversification** | 70/30 equity/bond split reduces drawdown severity | Free (built into allocation) |
| **Put options** | Buy puts on major index holdings — floor on losses | 0.5-2% p.a. of portfolio value |
| **Tail-risk hedging** | Deep OTM puts for crash protection (>20% decline) | 0.3-0.8% p.a. |
| **Currency hedging** | Forward contracts to reduce FX volatility | 0.5-1.5% p.a. |
| **Rebalancing** | Quarterly return to target allocation | Free (trading costs minimal for ETFs) |
| **Cash buffer** | 3-6 months income held in cash within portfolio | Opportunity cost only |

### 5.2 Portfolio Drawdown Protection

For EPM Protect variant (income floor guarantee), the portfolio must maintain reserves:

```
Margin reserve calculation:
  Annual income obligation:    $12,000
  Income floor (80%):          $9,600
  Reserve required:            24 months × floor = $19,200
  Reserve location:            Cash/money market within portfolio
  
  IF portfolio drawdown > 15%:
    Reduce equity allocation by 10% → increase cash/bonds
    Maintain income floor from reserve
    Rebuild reserve from future returns when markets recover
```

### 5.3 Stress Testing Requirements

The portfolio must be stress-tested against historical scenarios:

| Scenario | Equity Drawdown | Duration | Portfolio Impact | Income Impact |
|----------|----------------|----------|-----------------|---------------|
| GFC 2008 | -55% | 18 months | -38% (balanced) | Reduced 20-30% |
| COVID 2020 | -34% | 1 month | -24% (balanced) | Brief reduction |
| Dot-com 2000 | -49% | 30 months | -34% (balanced) | Sustained reduction |
| 1970s stagflation | -48% | 21 months | -25% (bonds help) | Moderate reduction |
| Japan 1989 | -80% | 13 years | N/A (diversified away from single-country) | — |

**Key finding:** A balanced 70/30 portfolio has never failed to recover within 5 years in any historical scenario. The EPM's long time horizon (15-30 years) provides substantial recovery runway.

---

## 6. NNEG Insurance (Lender Side)

### 6.1 NNEG as an Embedded Put Option

The NNEG is economically equivalent to the lender writing a **put option** on the property to the consumer. The consumer has the right to "put" the property to the lender at a price equal to the mortgage balance.

```
NNEG payoff at settlement:
  IF property_value >= mortgage_balance:
    Lender receives: mortgage_balance (from property sale)
    Consumer/estate keeps: surplus
    NNEG cost: $0

  IF property_value < mortgage_balance:
    Lender receives: property_value only
    Lender loss: mortgage_balance - property_value
    NNEG cost: the loss amount
```

### 6.2 NNEG Pricing

The lender must price the NNEG risk into the margin. Pricing factors:

| Factor | Impact on NNEG Cost |
|--------|-------------------|
| LTV ratio | Higher LTV → higher NNEG cost (less equity buffer) |
| Property volatility | More volatile markets → higher cost |
| Consumer age | Younger → longer term → more uncertainty → higher cost |
| Interest rate environment | Higher rates → higher mortgage accrual → higher cost |
| Property type | Apartments/flats: higher volatility than houses |
| Property location | Prime locations: lower volatility |

### 6.3 NNEG Reserve vs Reinsurance

| Approach | Pros | Cons |
|----------|------|------|
| **Self-reserve** | Full control, no third-party dependency | Ties up capital, concentration risk |
| **Reinsurance** | Transfers tail risk, frees capital | Cost (1-3% of exposure), counterparty risk |
| **Hybrid** | First-loss retained, catastrophic reinsured | Balanced approach |

**Recommendation:** Hybrid approach. Lender retains first 10% of NNEG losses (self-reserve from margin), reinsures catastrophic losses (>10% portfolio-wide NNEG activation).

### 6.4 UK-Specific: PRA Requirements

The UK Prudential Regulation Authority (PRA) issued supervisory statement SS3/17 on equity release mortgage pricing, specifically addressing NNEG:

| PRA Requirement | Detail |
|-----------------|--------|
| NNEG must use Black-Scholes or equivalent | Option pricing for reserving |
| No deferment rate below long-term risk-free | Conservative valuation |
| Stress testing required | 30%+ property decline scenarios |
| Board attestation | Board must confirm NNEG reserves are adequate |

---

## 7. Consumer Life & Health Insurance

### 7.1 Not Required, But Relevant

EPM does not require life insurance (NNEG protects the estate). However, the consumer's health and life expectancy affect EPM economics:

| Consumer Event | EPM Impact | Insurance Relevant? |
|----------------|-----------|-------------------|
| Death | EPM terminates, property sold or refinanced | Life insurance could clear mortgage for beneficiaries |
| Permanent disability | No impact — no repayments to make | Not relevant to EPM |
| Aged care entry | May trigger EPM review (property no longer occupied) | Long-term care insurance could fund care without selling home |
| Cognitive decline | Consumer may lack capacity for EPM decisions | Power of Attorney must be in place |

### 7.2 Long-Term Care Insurance Interaction

If the consumer enters aged care:

| Region | Occupancy Requirement | EPM Impact |
|--------|----------------------|-----------|
| AU | Must be owner-occupied | ⚠️ 12-month grace period, then EPM review. If property vacant >12 months, lender may require repayment or rental arrangement. |
| US | Must be primary residence | ⚠️ HECM precedent: 12-month absence triggers due and payable. EPM should follow similar standard. |
| NZ | Must be owner-occupied | ⚠️ Similar to AU — grace period then review |
| UK | ERC standards allow indefinite if spouse remains | ✅ If surviving partner remains in property, EPM continues |

### 7.3 Power of Attorney Requirement

**All EPM consumers should be strongly encouraged to have a current Power of Attorney (PoA) in place.** If the consumer loses capacity:

- PoA holder can manage EPM correspondence and decisions
- Without PoA, estate/family must apply to court for guardianship — delays settlement
- EPM contract should name PoA holder (or require one within 12 months of inception)

| Region | PoA Type | Authority |
|--------|----------|-----------|
| AU | Enduring Power of Attorney | State-based legislation |
| US | Durable Power of Attorney | State-based (UPC or state statute) |
| NZ | Enduring Power of Attorney | Protection of Personal and Property Rights Act 1988 |
| UK | Lasting Power of Attorney (Property & Financial Affairs) | Mental Capacity Act 2005 |

---

## 8. Professional Indemnity & Platform Insurance

### 8.1 FutureProof Platform Insurance Requirements

| Insurance Type | Cover | Required By |
|----------------|-------|-------------|
| **Professional Indemnity (PI)** | Errors in advice, calculation mistakes, system failures | All regions (regulatory condition of licensing) |
| **Cyber Insurance** | Data breach, ransomware, system outage | Best practice (increasingly mandated) |
| **Directors & Officers (D&O)** | Personal liability of directors | Standard corporate governance |
| **Public Liability** | Third-party claims (unlikely for platform, but standard) | Standard |
| **Business Interruption** | Revenue loss from system outage | Recommended |
| **Crime/Fidelity** | Employee fraud, misappropriation | Required for financial services |

### 8.2 PI Minimum Cover

| Region | Minimum PI Cover | Regulatory Source |
|--------|-----------------|-------------------|
| AU | $2M per claim, $5M aggregate (AFSL standard) | ASIC RG 126 |
| US | Varies by state — typically $1M/$3M | State licensing requirements |
| NZ | $1M per claim (FAP licence condition) | FMA standard conditions |
| UK | £1M per claim (FCA minimum for mortgage advisers) | FCA MIPRU 3.2 |

### 8.3 Cyber Insurance

Given the PII held by the platform (see SECURITY_FRAMEWORK.md), cyber insurance is essential:

| Cover Element | Detail |
|--------------|--------|
| First-party costs | Forensic investigation, notification costs, credit monitoring for affected consumers |
| Third-party liability | Consumer claims for data breach |
| Regulatory fines | Defence costs and fines (where insurable) |
| Business interruption | Revenue loss during incident |
| Ransomware | Negotiation, payment (controversial — policy decision), recovery |
| Minimum cover | $5M (given volume of PII and financial data) |

---

## 9. Regional Requirements

### 9.1 Australia

| Requirement | Detail | Status |
|-------------|--------|--------|
| Buildings insurance (consumer) | Standard mortgage condition | ✅ In contract terms |
| PI insurance (platform) | AFSL condition RG 126 | Required before AFSL grant |
| Cyber insurance | Not mandated but APRA CPS 234 recommends | Recommended |
| Lenders mortgage insurance (LMI) | Not applicable — lender bears risk via NNEG | N/A |
| Strata insurance | Body corporate must maintain (if applicable) | Consumer to verify |

### 9.2 United States

| Requirement | Detail | Status |
|-------------|--------|--------|
| Homeowners insurance (HO-3 or HO-5) | Standard mortgage condition | ✅ In contract terms |
| Flood insurance (FEMA zones) | Mandatory in Zone A/V | ✅ In eligibility criteria |
| Title insurance | Standard practice | ✅ Required |
| Errors & Omissions (E&O) | State licensing condition | Required per state |
| Fidelity bond | Required for NMLS licensees | Required |
| Force-placed insurance disclosure | RESPA requires specific notice before force-placing | ✅ In process |

### 9.3 New Zealand

| Requirement | Detail | Status |
|-------------|--------|--------|
| Buildings insurance (consumer) | Standard mortgage condition | ✅ In contract terms |
| EQC levy | Included in all residential policies (Toka Tū Ake EQC) | Automatic |
| PI insurance (platform) | FAP licence condition | Required before FAP grant |
| Natural disaster cover | Standard in NZ policies (EQC + private) | ✅ |

### 9.4 United Kingdom

| Requirement | Detail | Status |
|-------------|--------|--------|
| Buildings insurance (consumer) | Standard mortgage condition | ✅ In contract terms |
| PI insurance (platform) | FCA MIPRU 3.2 | Required before FCA authorisation |
| Subsidence cover | Critical in UK (clay soils, mining areas) | ✅ Required in policy |
| Flood Re | Government-backed flood insurance scheme for residential | Available |
| ERC insurance standards | ERC members must ensure consumers have adequate cover | ✅ ERC compliance |

---

## 10. Implementation Checklist

### Consumer-Facing

- [ ] Insurance covenant clause in EPM contract (all regions)
- [ ] Insurance verification workflow (annual check + automated reminders)
- [ ] Force-placed insurance process and disclosure notices
- [ ] Insurance summary in consumer portal (policy expiry, cover amount, insurer)
- [ ] PoA recommendation and tracking (flag if no PoA after 12 months)
- [ ] Aged care / vacancy protocol documented and disclosed

### Platform / Corporate

- [ ] PI insurance obtained (minimum per regional requirements)
- [ ] Cyber insurance obtained ($5M minimum)
- [ ] D&O insurance obtained
- [ ] Crime/fidelity bond obtained (US)
- [ ] Business interruption insurance
- [ ] Annual insurance review (platform policies)

### Lender / Portfolio

- [ ] NNEG pricing model built (Black-Scholes or equivalent)
- [ ] NNEG reserve policy defined (hybrid: self-reserve + reinsurance)
- [ ] Portfolio stress testing framework (5 historical scenarios minimum)
- [ ] Currency hedging policy documented
- [ ] Tail-risk hedging budget approved (0.3-0.8% p.a.)
- [ ] Cash buffer policy (3-6 months income per consumer)
- [ ] UK PRA SS3/17 compliance (if UK lender entity)

### Quote Engine Integration

- [ ] Insurance cost estimate in quote (buildings insurance annual premium)
- [ ] Flood zone check (automated via regional flood maps / APIs)
- [ ] Title insurance cost included in establishment fees (US)
- [ ] MPI disclosure ("not required due to NNEG")
- [ ] PoA prompt during application process

---

*Insurance requirements should be reviewed annually and updated when regulations change. Lender NNEG pricing must be actuarially certified before product launch.*
