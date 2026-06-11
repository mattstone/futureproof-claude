# FutureProof Regional Compliance Audit & Gap Analysis

**Version:** 1.2  
**Created:** 2026-03-06  
**Scope:** Financial regulations, security standards, currency/tax treatment per region (AU, NZ, UK, US)  
**Purpose:** Identify gaps in REFACTOR_PROMPT.md and build implementation plan

---

> ## ⏱️ STATUS UPDATE — 2026-06-03
>
> **This document is the originating gap analysis. The gaps it identified have since been closed.** The four per-market compliance documents it proposes now exist:
> `docs/compliance/AUSTRALIA_COMPLIANCE.md`, `NZ_COMPLIANCE.md`, `UK_COMPLIANCE.md`, `US_COMPLIANCE.md` (plus `REGULATORY_ASSESSMENT_AU.md`).
>
> - **Board-level summary:** use `docs/pdfs/FutureProof_Regional_Regulatory_Readiness_Jun2026.pdf` — the distilled, decision-focused briefing built from this analysis and the per-market docs.
> - **Sections 6, 7 and 9** (model selection, token/timeline budgeting, the "should we do Phase 0A?" decision) describe the *internal build process*, which is now complete. They are retained only as a historical record.
> - **Terminology:** the EPM is a **mortgage**, not a loan the customer repays — the customer receives income and makes **no repayments**; the lender bears the investment risk. Where "loan" appears below in that consumer-obligation sense, read "mortgage / EPM". Genuine regulatory terms (e.g. "loan-to-value", the US "Loan Estimate", "Australian Credit Licence") are left as-is.
> - **Two factual corrections** were applied: UK tax treatment (§3.2) and the insurance framing (§4.2) — see those sections.
> - **AU classification fork added** (§1.1) — the binding AU question is **ACL vs AFSL** (personal-advice AFSL is a ~6–12 month path), plus the comparison-rate problem and the Age Pension income test. See the board briefing for the cross-market view of this fork.
>
> ---

## EXECUTIVE SUMMARY

**Current State:** REFACTOR_PROMPT.md includes basic multi-region skeleton (config.yml, routing, contract templates) but **lacks critical regional specifics** for:

1. **Financial Regulations** — No lending/mortgage framework details per region
2. **Security/Compliance Standards** — No data residency, certification, audit requirements
3. **Tax Treatment** — No guidance on income tax, capital gains, inheritance implications
4. **Product Variations** — EPM model assumes one-size-fits-all; regions require adjustments
5. **Insurance/Risk Management** — Region-specific insurance regulations undefined

**Gap Impact:** Contracts, financial model, and security documentation will be incomplete/incorrect without these details.

**Action:** Fill gaps via 5 new tasks + integrate into existing phases.

---

## SECTION 1: REGULATORY GAPS — FINANCIAL & LENDING

### 1.1 Australia (AU) — Missing Regulatory Details

> **⚠️ Update (2026-06-03) — the AU classification fork.** Subsequent analysis (`docs/compliance/AUSTRALIA_COMPLIANCE.md`, `docs/compliance/REGULATORY_ASSESSMENT_AU.md`, and the board briefing PDF) shows the binding AU question is **ACL vs AFSL**, not the ACL alone. An **ACL** (credit) is almost certain; but managing the investment portfolio and giving income projections **likely triggers an AFSL**. *General*-advice-only is the lighter route; ***personal* advice** is much heavier — Statement of Advice, Best Interests Duty, qualified advisers — a ~6–12 month path. Two more AU-specific items confirmed since: the **comparison-rate problem** (the mandatory comparison rate assumes repayments the EPM does not have — needs ASIC guidance/exemption) and the **Age Pension income test** (EPM income is assessable and can reduce pension entitlements — must be disclosed). Net: AU is **not** the clear "fast" market the gap list below implies — its timeline depends entirely on this fork.

**What's Missing:**

| Requirement | Current Prompt | Gap |
|---|---|---|
| Responsible Lending Rules | ❌ Not mentioned | Specify responsible lending assessment (NCC Act 2009) |
| LVR Limits | ❌ Not mentioned | Define max LVR (typically 80% for residential mortgages) |
| Interest Rate Disclosure | ❌ Not mentioned | Specify fixed vs. variable, comparison rates |
| Consumer Guarantees | ❌ Not mentioned | ACL guarantees re: fitness for purpose |
| Lender's Mortgage Insurance | ❌ Not mentioned | When required, who pays, typical cost (0.5-2% LVR) |
| Financial Services License | ❌ Not mentioned | Specify AFSL/ACL requirements if arranging loans |
| Superannuation Interaction | ❌ Not mentioned | EPM may affect superannuation accessibility |
| First Home Buyer Concessions | ❌ Not mentioned | Stamp duty exemptions, FHSS interaction |

**Why It Matters:**
- Non-compliance = ASIC enforcement action
- Product design depends on regulatory framework (e.g., RLA, NLIS requirements)
- Terms & Conditions must reference NCC Act obligations
- Broker agreements need AFSL/ACL declarations

**Solution Task:** Create AUSTRALIA_COMPLIANCE.md specifying:
- Responsible lending checklist (serviceability, hardship, Debt-to-Income limits)
- LVR framework (80% max, LMI triggers)
- Disclosure requirements (comparison rates, fee breakdown)
- Consumer guarantee commitments
- Superannuation interaction rules

---

### 1.2 United Kingdom (UK) — Missing Regulatory Details

**What's Missing:**

| Requirement | Current Prompt | Gap |
|---|---|---|
| FCA Regulation | ❌ Not mentioned | Specify MCOB rules (mortgage conduct of business) |
| Affordability Rules | ❌ Not mentioned | FCA "affordability test" (not just credit scoring) |
| Product Governance | ❌ Not mentioned | Target Market Determination (TMD) required |
| Interest Rate Type | ❌ Not mentioned | Fix, variable, tracker, discount (UK-specific products) |
| Equity Release Rules | ❌ Not mentioned | Different from mortgages; ERC (early repayment charge) |
| Inheritance Tax Interaction | ❌ Not mentioned | EPM affects IHT on estate |
| PSD2 Compliance | ❌ Not mentioned | Strong Customer Authentication (SCA) for payments |
| FCA Complaints | ❌ Not mentioned | FOS (Financial Ombudsman) dispute handling |

**Why It Matters:**
- FCA enforcement is strict; non-compliance = fines (e.g., Nationwide £12.7M 2021)
- "Equity release" is highly regulated; different from EPM but similar structure
- TMD must identify who product is NOT suitable for
- IHT implications major selling point for UK market

**Solution Task:** Create UK_COMPLIANCE.md specifying:
- FCA MCOB rules (ICOBS, ICOBS 2, ICOBS 3)
- Affordability assessment process
- Target Market Determination template
- ERC (Early Repayment Charge) framework
- Inheritance Tax interaction & disclosure
- FOS complaints handling process

---

### 1.3 New Zealand (NZ) — Missing Regulatory Details

**What's Missing:**

| Requirement | Current Prompt | Gap |
|---|---|---|
| LVR Rules | ❌ Not mentioned | RBNZ LVR limits (80% max, exceptions) |
| Responsible Lending | ❌ Not mentioned | CCCR (Credit Contracts) responsible lending principles |
| Interest Disclosure | ❌ Not mentioned | NZFMA vs. floating rates, fixed term variations |
| KiwiSaver Interaction | ❌ Not mentioned | EPM may block KiwiSaver first home withdrawal |
| Maori Land Restrictions | ❌ Not mentioned | Special rules for Maori-owned freehold land |
| FMA Regulation | ❌ Not mentioned | Financial Markets Authority oversight (if securities involved) |
| Consumer Credit | ❌ Not mentioned | Credit Contracts & Consumer Finance Act (CCCFA) 2003 |

**Why It Matters:**
- RBNZ LVR limits strict; violating = regulatory action
- CCCR "responsible lending" is narrower than AU/UK
- KiwiSaver interaction critical for marketing (may NOT be suitable for many)
- FMA oversight applies if investment component treated as security

**Solution Task:** Create NZ_COMPLIANCE.md specifying:
- RBNZ LVR framework & exemptions
- CCCFA responsible lending checklist
- Interest rate disclosure rules (NZFMA, floating)
- KiwiSaver interaction & exclusion rules
- Maori land mortgage restrictions
- FMA securities framework (if applicable)

---

### 1.4 United States (US) — Missing Regulatory Details

**What's Missing:**

| Requirement | Current Prompt | Gap |
|---|---|---|
| Mortgage Licensing | ❌ Not mentioned | NMLS registration, state-level licensing required |
| CFPB Regulation | ❌ Not mentioned | TRID (Loan Estimate, Closing Disclosure) requirements |
| Appraisal Rules | ❌ Not mentioned | FIRREA compliance, independent appraisal mandatory |
| Servicing Requirements | ❌ Not mentioned | DODD-FRANK servicer obligations (if externally serviced) |
| Truth in Lending Act | ❌ Not mentioned | TILA disclosure (APR, finance charges, payment schedule) |
| State-Level Variations | ❌ Not mentioned | Different rules per state (CA, NY, TX, FL, etc.) |
| Reverse Mortgage Rules | ❌ Not mentioned | If product similar to HECM, FHA rules apply |
| Tax Treatment | ❌ Not mentioned | 1099 reporting, mortgage interest deductibility |

**Why It Matters:**
- CFPB enforcement strict & aggressive (Wells Fargo: $3B+ in penalties)
- NMLS requirement = multi-state licensing burden
- TRID Loan Estimate required within 3 days of application
- State-level variations make national product difficult
- Reverse mortgage overlap requires HUD compliance if HECM-like

**Solution Task:** Create US_COMPLIANCE.md specifying:
- NMLS state licensing requirements (which states first?)
- CFPB TRID workflow (Loan Estimate → Closing Disclosure)
- Appraisal standards (FIRREA, state appraiser boards)
- TILA APR calculation & disclosure
- State-level variations (at least CA, NY, TX focus)
- Reverse mortgage rules (if applicable)
- Tax reporting (1099, mortgage interest deduction)

---

## SECTION 2: SECURITY & COMPLIANCE STANDARDS GAPS

### 2.1 Data Residency & Localization

**Current Prompt:** Mentions "regional templates" but **no data residency requirements**

**What's Missing:**

| Requirement | AU | NZ | UK | US |
|---|---|---|---|---|
| Data Localization Required | ❌ No explicit rule | ❌ No explicit rule | ✅ **Yes (GDPR)** | ⚠️ Some states |
| Encryption Standard | ❌ Not specified | ❌ Not specified | ❌ Not specified | ❌ Not specified |
| Audit Trail Retention | ❌ Not specified | ❌ Not specified | ❌ Not specified | ❌ Not specified |
| Backup Location | ❌ Not specified | ❌ Not specified | ❌ Not specified | ❌ Not specified |
| Third-Party Processing | ❌ Not specified | ❌ Not specified | ✅ **DPA required** | ❌ Not specified |

**Regional Specifics:**

1. **UK (GDPR):**
   - Data MUST be processed/stored within UK/EEA
   - Fly.io Dublin (EU) acceptable, but document in privacy policy
   - Standard Contractual Clauses (SCC) if using non-UK processor
   - Data subject rights: access, deletion, portability

2. **Australia (Privacy Act):**
   - APPs (Australian Privacy Principles) apply
   - No data localization requirement (unlike GDPR)
   - Reasonable security steps required
   - Consumer data access rights mandatory

3. **New Zealand (Privacy Act 2020):**
   - Similar to AU/UK but lighter
   - No data localization requirement
   - Information Commissioner oversight
   - Consumer access/correction rights

4. **US (State-Level):**
   - No federal data residency requirement (yet)
   - California (CCPA): certain rights similar to GDPR
   - Texas, Virginia: emerging privacy laws
   - Some industries (healthcare, finance): stricter rules

**Solution Task:** Create SECURITY_FRAMEWORK.md specifying:
- Data residency rules per region (UK = EU, others = flexible)
- Encryption: AES-256 at rest, TLS 1.3 in transit (standardize)
- Audit trail: 7-year retention (meets all regions)
- Backup: Separate geographic location (Fly.io + secondary)
- Third-party DPAs: Template for processors
- Privacy controls: Data access, deletion, portability endpoints

---

### 2.2 Compliance Certifications

**Current Prompt:** Mentions "SOC2 Type II roadmap" but **no regional certification specifics**

**What's Missing:**

| Certification | AU | NZ | UK | US | Priority |
|---|---|---|---|---|---|
| ISO 27001 | ⚠️ Recommended | ⚠️ Recommended | ✅ Expected | ✅ Expected | High |
| SOC2 Type II | ⚠️ Nice-to-have | ⚠️ Nice-to-have | ✅ Expected | ✅ Expected | High |
| GDPR Compliant | N/A | N/A | ✅ Mandatory | N/A | Mandatory (UK) |
| CCPA Compliant | N/A | N/A | N/A | ✅ Mandatory (CA) | Medium (US-CA only) |
| PCI DSS (if payments) | ✅ Required | ✅ Required | ✅ Required | ✅ Required | High |
| Industry-Specific | ⚠️ ASIC | ⚠️ FMA | ✅ FCA | ✅ CFPB | High |

**For FutureProof specifically:**
- If handling payment processing → PCI DSS Level 1 or use Stripe (PCI compliant)
- If regulated as financial services → ISO 27001 baseline
- If operating in UK → GDPR compliance audit + DPA template
- If operating in US → State privacy law audit + data deletion SOP

**Solution Task:** Create CERTIFICATIONS_ROADMAP.md specifying:
- Phase 1 (MVP launch): Data security baseline (Fly.io SOC2 + own controls doc)
- Phase 2 (Y1): ISO 27001 certification path
- Phase 3 (Y2): SOC2 Type II if operating in US/UK
- Phase 4 (Y3): FCA/ASIC/FMA compliance certification (if regulated)
- Immediate: GDPR compliance checklist for UK
- Immediate: Privacy policy audit (Privacy Act / GDPR / CCPA)

---

### 2.3 Incident Response & Breach Notification

**Current Prompt:** **Completely missing**

**What's Missing:**

| Requirement | AU | NZ | UK | US |
|---|---|---|---|---|
| Breach Notification Timeline | 30 days | Reasonable delay | 72 hours | State-dependent |
| Who to Notify | ICO + users | Commissioner + users | ICO + users | State AG + users |
| Mandatory Disclosure | Yes | Yes | Yes | Yes (varies) |
| Documentation | Yes | Yes | Yes | Yes |
| Assessment Process | Yes | Yes | Yes | Yes |

**Regional Specifics:**

1. **UK (GDPR Article 33-34):**
   - ICO notification: 72 hours max
   - User notification: Without delay (GDPR 34)
   - Form: ICO online portal

2. **Australia (Privacy Act):**
   - Notification: Reasonable delay (no fixed timeline)
   - Office of the Australian Information Commissioner: Yes
   - Form: Letter + email required

3. **New Zealand (Privacy Act 2020):**
   - Commissioner notification: Yes
   - User notification: Reasonable delay
   - Form: Letter + email

4. **US (State-level):**
   - California (CCPA): 30 days
   - Massachusetts: 30 days
   - New York: "Without unreasonable delay"
   - Variable: No federal standard

**Solution Task:** Create INCIDENT_RESPONSE.md specifying:
- Detection process (monitoring, user reports)
- Assessment timeline (24h)
- Notification obligations per region (72h UK, 30d AU, etc.)
- Communications template (user letter, regulator notification)
- Documentation & logging
- Post-incident SOP (root cause, remediation, audit)

---

## SECTION 3: CURRENCY & TAX TREATMENT GAPS

### 3.1 Currency & Inflation Adjustment

**Current Prompt:** Specifies currencies (AUD, GBP, NZD, USD) but **no inflation/FX strategy**

**What's Missing:**

1. **Exchange Rate Risk Management**
   - If customer in AU, lender in UK → FX fluctuation risk
   - Should EPM lock FX or allow fluctuation?
   - Hedging strategy undefined

2. **Inflation Adjustment**
   - Home values inflate per region (AU 3-4%, UK 2-3%, etc.)
   - EPM model assumes fixed home value; reality: property appreciates
   - Should loan amount/LVR adjust annually?

3. **Interest Rate Benchmarks (Region-Specific)**
   - AU: BBSY, OCR (phased out), cash rate
   - NZ: NZOCR (Official Cash Rate)
   - UK: SONIA (Sterling Overnight Index Average)
   - US: Prime rate, SOFR (Secured Overnight Financing Rate)

**Solution Task:** Create CURRENCY_INFLATION.md specifying:
- FX policy: Lock rate at origination or adjust quarterly?
- Inflation adjustment: Annual LVR revaluation (property + loan adjustment?)
- Interest rate benchmarks per region
- Quarterly/annual review triggers
- Currency conversion rates source (RBA, BoE, etc.)

---

### 3.2 Tax Treatment Per Region

**Current Prompt:** Vaguely mentions "tax-free income" but **lacks regional tax details**

**What's Missing:**

| Tax Aspect | AU | NZ | UK | US |
|---|---|---|---|---|
| Income Tax (Monthly Disbursement) | ⚠️ Unclear | ⚠️ Unclear | ⚠️ Unclear | ⚠️ Unclear |
| Capital Gains on Investment | Taxable | Taxable | Taxable (wrapper-dependent) | Taxable |
| Inheritance Tax (Estate) | No IHT | No IHT | **Yes (40%)** | No federal IHT |
| Superannuation Impact | ⚠️ May block access | N/A | N/A | Affects Medicare |
| Debt Interest Deductibility | No (personal) | No (personal) | No (personal) | Yes (primary residence excluded) |
| Reporting Requirements | ATO | Inland Revenue | HMRC | IRS |

**Regional Specifics:**

1. **Australia:**
   - Monthly income = ordinary income (taxable)
   - Investment gains = capital gains tax (50% discount if held >1yr)
   - Superannuation: May affect age pension eligibility
   - Reporting: 1099 equivalent (not standard in AU)

2. **New Zealand:**
   - Monthly income = taxable
   - Investment gains = taxable (no CGT yet for most assets, but coming)
   - KiwiSaver blocked if EPM uses home equity
   - Reporting: IRD return (FIR)

3. **United Kingdom:**
   - Monthly income = taxable (self-assessment)
   - Investment gains = **taxable (CGT), wrapper-dependent** — confirm with UK tax counsel; the genuine UK advantage is **Inheritance Tax efficiency** (below), not a CGT exemption
   - Inheritance: IHT on estate (40% >£325k threshold)
   - Reporting: HMRC self-assessment

4. **United States:**
   - Monthly income = taxable (Form 1040)
   - Investment gains = capital gains (long-term vs. short-term)
   - Primary residence: Special exemption ($250k/$500k)
   - Reporting: Form 1098 (mortgage interest), 1099-INT (interest income)

**Solution Task:** Create TAX_TREATMENT.md specifying:
- Tax classification per region (income, investment, capital gains)
- Reporting obligations (forms, deadlines, regulators)
- Tax optimization strategies (if allowed to advise)
- Disclaimer: "Not tax advice; consult accountant"
- Year-end reporting templates (for customers)
- Loan amount adjustment for tax implications (if needed)

---

### 3.3 Estate & Inheritance Impact

**Current Prompt:** Briefly mentions "preserve inheritance" but **lacks details** — and **assumes loan repayment on death** (INCORRECT)

**CRITICAL CORRECTION:** Consumer has **zero loan repayment risk**. The lender bears all risk. On consumer death:
- Loan does NOT get called due
- Investment portfolio continues under estate management
- Estate receives ongoing income distribution (or portfolio liquidation)
- Lender still owns the mortgage; consumer's heirs inherit investment upside

**What's ACTUALLY Missing:**

1. **Estate Planning & Succession**
   - Who manages portfolio post-death? (executor, trust, beneficiary)
   - Can estate liquidate portfolio if needed (funeral, admin costs)?
   - Beneficiary options (continue distributions, lump sum payout, etc.)

2. **Inheritance Tax (UK Primary — Major Selling Point)**
   - Loan structure reduces estate VALUE (lender owns mortgage)
   - Investment portfolio grows over time (beneficiary inheritance upside)
   - UK IHT benefit: Lender's mortgage is a liability against estate
   - Net effect: Lower IHT burden for heirs

3. **Estate Documentation**
   - Consumer will references EPM arrangement
   - Beneficiary notification requirements
   - Portfolio access/control post-death

**Solution Task:** Create ESTATE_BENEFITS.md specifying:
- Estate planning integration (will templates)
- Beneficiary options (continue, liquidate, transfer)
- Inheritance tax benefit (UK specific)
- Post-death portfolio management
- Estate executor documentation & forms

---

## SECTION 4: PRODUCT VARIATION GAPS

### 4.1 EPM Model Assumptions (Current)

**Current Prompt (Task 2.1):** Single "CalculationEngine" without regional variation

**Assumptions Made:**
- Home value + LVR → Loan amount (simple)
- 70% ETF + 30% annuity (fixed split)
- Quarterly interest payments (fixed)
- S&P 500 benchmark (US-centric)
- No regional adjustments

**What's Missing:**

| Variation | AU | NZ | UK | US |
|---|---|---|---|---|
| Property Valuation | CoreLogic AU | Quotable Value | Zoopla/Rightmove | Zillow/Redfin |
| Investment Benchmark | ASX 200 | NZX 50 | FTSE 100 | S&P 500 |
| Insurance Product | LMI providers | Bank-specific | ERC varies | PMI varies |
| Tax Optimization | CGT discount | N/A | **IHT benefit** | Interest deduction |
| Loan Termination | Fixed 25y | Fixed 25y | Flexible (ERC) | Flexible |
| Regulator Oversight | ASIC | FMA | FCA | CFPB |

**Solution Task:** Create EPM_VARIANTS.md specifying:
- Property valuation service per region
- Investment benchmark per region (local index vs. global)
- Insurance product requirements per region
- Tax optimization rules per region
- Loan term flexibility per region
- Regional regulator oversight model

---

### 4.2 Insurance & Risk Management

**Current Prompt:** Mentions "insurance coverage" but **undefined**

**⚠️ Correction (2026-06-03):** An earlier version of this section framed insurance around the borrower being unable to make repayments (mortgage protection, income protection, "can't pay interest → default"). **That does not apply to the EPM** — the customer makes no repayments, so the failure mode those products exist to cover does not arise. The risks worth managing are property-side (the customer's responsibility) and lender-side (investment / tail risk).

**What actually matters:**

1. **Buildings insurance (customer obligation)**
   - The customer must keep the property insured and maintained — a disclosure and serviceability point (see the responsible-lending sections), not a product feature.

2. **Lender-side investment / tail risk**
   - Market downturns are borne by the lender and its funders, not the customer.
   - Managed through the reinsurance structure (see the EPM Reinsurance Structure paper), not through consumer insurance.

3. **Optional life cover (estate planning only)**
   - Not required by the product — no repayment falls due on death (see §3.3) — but customers may choose life cover for separate estate-planning reasons.

**Solution Task:** Folded into the per-market compliance docs and the reinsurance paper. The originally-proposed consumer-centric INSURANCE_FRAMEWORK.md is not required as scoped.

---

## SECTION 5: IMPLEMENTATION PLAN

### Phase 0A: Regional Compliance Audit (NEW — Pre-implementation)

**Objective:** Document all regional requirements before building features

**⚠️ CRITICAL CHANGE:** Work sequentially *in-session* (not sub-agents). Break into 4-6k token chunks to prevent timeout/waste.

**Tasks (In-Session, Sequential):**

| Task | Document | Scope | Tokens | Model | Sequence |
|---|---|---|---|---|---|
| 0A.1a | AUSTRALIA_COMPLIANCE.md (Part 1) | Responsible lending, LVR, disclosure rules | 4k | **Opus** | Work 1 |
| 0A.1b | AUSTRALIA_COMPLIANCE.md (Part 2) | Consumer guarantees, licensing, superannuation | 4k | **Opus** | Work 2 |
| 0A.2a | UK_COMPLIANCE.md (Part 1) | FCA MCOB, affordability, TMD | 4k | **Opus** | Work 3 |
| 0A.2b | UK_COMPLIANCE.md (Part 2) | Equity release rules, IHT, PSD2, complaints | 4k | **Opus** | Work 4 |
| 0A.3 | NZ_COMPLIANCE.md | LVR, CCCFA, KiwiSaver, Maori land | 5k | **Opus** | Work 5 |
| 0A.4a | US_COMPLIANCE.md (Part 1) | NMLS, CFPB TRID, appraisal standards | 5k | **Opus** | Work 6 |
| 0A.4b | US_COMPLIANCE.md (Part 2) | State variations, tax treatment, reverse mortgage | 5k | **Opus** | Work 7 |
| 0A.5 | SECURITY_FRAMEWORK.md | Data residency, encryption, audit trail, DPA | 5k | **Opus** | Work 8 |
| 0A.6 | TAX_TREATMENT.md | Income tax, CGT, IHT, reporting per region | 6k | **Opus** | Work 9 |
| 0A.7 | ESTATE_BENEFITS.md | Estate planning, beneficiary options, IHT benefit | 4k | **Opus** | Work 10 |
| 0A.8 | EPM_VARIANTS.md | Financial model adjustments per region | 5k | **Opus** | Work 11 |
| 0A.9 | INSURANCE_FRAMEWORK.md | Mortgage/investment protection per region | 4k | **Opus** | Work 12 |
| 0A.10 | CERTIFICATIONS_ROADMAP.md | ISO 27001, SOC2, GDPR timeline | 3k | Haiku | Work 13 |
| 0A.11 | INCIDENT_RESPONSE.md | Breach notification, regulator process | 3k | Haiku | Work 14 |
| 0A.12 | CURRENCY_INFLATION.md | FX policy, inflation adjustment, benchmarks | 3k | Haiku | Work 15 |
| | | | **60k tokens** | **Opus → Haiku** | **In-session, ~15 works** |

---

### Integration Points: Where Phase 0A Feeds Into REFACTOR_PROMPT.md

**Phase 1.2 (Multi-Region Routing):**
- Update `config/regions.yml` with regulatory flags from Task 0A.1-4
- Example: `au: { regulations: asic, gdpr: false, tax_framework: australian_income_tax }`

**Phase 2.1 (EPM Financial Model):**
- Use EPM_VARIANTS.md to adjust CalculationEngine per region
- Add benchmarks per region (ASX 200 vs. S&P 500)
- Tax optimization rules from TAX_TREATMENT.md

**Phase 2.2 (Contracts & Compliance):**
- Use compliance docs (AUSTRALIA_COMPLIANCE.md, etc.) to inform contract language
- Add regulatory disclosures (e.g., TRID for US, MCOB for UK)
- Include insurance requirements from INSURANCE_FRAMEWORK.md
- Add incident response & data handling from SECURITY_FRAMEWORK.md

**Phase 2.4 (Agent Performance Dashboard):**
- Agents should reference regional regulatory obligations
- Example: "Legal Agent" knows AU responsible lending rules, UK MCOB rules, etc.

**Phase 5.1 (Capabilities Document):**
- Reference Phase 0A documents for "Security & Compliance" section
- Include "Regional Regulatory Compliance Matrix" (summary table)

---

## SECTION 6: MODEL RECOMMENDATIONS (Opus vs. Haiku)

### When to Use Opus (Complex, Nuanced Work)

**Use Opus for:**
- ✅ Financial regulatory interpretation (multi-jurisdiction)
- ✅ Legal/compliance document drafting (high stakes)
- ✅ Tax treatment analysis (nuanced rules per region)
- ✅ Estate/beneficiary planning (complex scenarios)
- ✅ Insurance product design (lender risk mitigation)
- ✅ Product variant design (EPM adjustments per region)
- ✅ Work in-session (fast iteration, avoid sub-agent timeouts)

**Why Opus:**
- Regulatory language requires nuance (GDPR vs. Privacy Act difference)
- Tax rules complex & region-specific (UK CGT exemption important)
- Estate planning complex for lender (IHT benefit positioning)
- Insurance product design requires balancing multiple constraints
- **In-session work:** 4-6k token chunks = 10-15 min per work, no timeout

**Tasks Needing Opus (In-Session):**
- AUSTRALIA_COMPLIANCE.md (ASIC rules, responsible lending)
- UK_COMPLIANCE.md (FCA MCOB, IHT benefit)
- NZ_COMPLIANCE.md (CCCFA, KiwiSaver conflict)
- US_COMPLIANCE.md (CFPB, state variations, TILA)
- TAX_TREATMENT.md (complex per-region rules)
- ESTATE_BENEFITS.md (IHT benefit, beneficiary options)
- EPM_VARIANTS.md (product design per region)
- INSURANCE_FRAMEWORK.md (lender risk logic)
- SECURITY_FRAMEWORK.md (regulatory security requirements)

---

### When to Use Haiku (Straightforward, Structured Work)

**Use Haiku for:**
- ✅ Documentation/process flows (clear structure)
- ✅ Checklists & roadmaps (sequential tasks)
- ✅ Data templates & forms (structured output)
- ✅ Integration of pre-existing docs (summary/synthesis)
- ✅ Implementation planning (steps, timelines, dependencies)

**Why Haiku:**
- These don't require deep reasoning, just clear structure
- Haiku is faster & cheaper
- Once Opus has defined the rules, Haiku can implement them

**Tasks Suitable for Haiku:**
- SECURITY_FRAMEWORK.md (data residency table + implementation steps)
- CERTIFICATIONS_ROADMAP.md (timeline + checklist)
- INCIDENT_RESPONSE.md (process flowchart + templates)
- CURRENCY_INFLATION.md (currency benchmarks + calculation rules)

---

## SECTION 7: TIMELINE & SEQUENCING

### Sequential In-Session Approach (RECOMMENDED)

**Goal:** Generate compliance docs sequentially within single session, avoiding sub-agent timeout/waste

**Method:**
- Work 1-12: Opus tasks (4-6k tokens each, 10 min per work)
- Work 13-15: Haiku tasks (3k tokens each, 5 min per work)
- Total: ~2.5 hours elapsed, 60k tokens consumed
- All work in-session (no spawned agents)

**Breakdown:**

```
Work 1 (10 min):  AUSTRALIA_COMPLIANCE.md — Part 1 (Opus, 4k)
Work 2 (10 min):  AUSTRALIA_COMPLIANCE.md — Part 2 (Opus, 4k)
Work 3 (10 min):  UK_COMPLIANCE.md — Part 1 (Opus, 4k)
Work 4 (10 min):  UK_COMPLIANCE.md — Part 2 (Opus, 4k)
Work 5 (12 min):  NZ_COMPLIANCE.md (Opus, 5k)
Work 6 (12 min):  US_COMPLIANCE.md — Part 1 (Opus, 5k)
Work 7 (12 min):  US_COMPLIANCE.md — Part 2 (Opus, 5k)
Work 8 (12 min):  SECURITY_FRAMEWORK.md (Opus, 5k)
Work 9 (15 min):  TAX_TREATMENT.md (Opus, 6k)
Work 10 (10 min): ESTATE_BENEFITS.md (Opus, 4k)
Work 11 (12 min): EPM_VARIANTS.md (Opus, 5k)
Work 12 (10 min): INSURANCE_FRAMEWORK.md (Opus, 4k)
Work 13 (8 min):  CERTIFICATIONS_ROADMAP.md (Haiku, 3k)
Work 14 (8 min):  INCIDENT_RESPONSE.md (Haiku, 3k)
Work 15 (8 min):  CURRENCY_INFLATION.md (Haiku, 3k)
```

**Total: ~160 minutes (~2.5 hours), 60k tokens, all in-session**

**Why This Works:**
- No sub-agent timeouts (everything in-session)
- Small chunks = fast iterations (10-15 min per work)
- Allows course correction (adjust next doc based on previous output)
- Token efficient (avoid redundancy between docs)

---

### Skip Phase 0A (Alternative)

**If you want to move faster:** Skip Phase 0A entirely, build Phase 1-2 with REFACTOR_PROMPT.md, then retrofit compliance docs.

**Pros:**
- Faster to MVP
- Find gaps by building

**Cons:**
- Contract templates may be incomplete
- Financial model may miss tax optimization
- Rework: 4-6 weeks
- Regulatory risk

**Recommendation:** **Do Phase 0A.** 2.5 hours now saves 4+ weeks of rework post-launch.

---

## SECTION 8: UPDATED REFACTOR ROADMAP

### New Phase Sequencing (With Phase 0A)

```
PHASE 0: Setup & Rules (from REFACTOR_PROMPT.md)
PHASE 0A: Regional Compliance Audit (NEW - 12 days, 86k tokens)
    ├─ 0A.1: AUSTRALIA_COMPLIANCE.md
    ├─ 0A.2: UK_COMPLIANCE.md
    ├─ 0A.3: NZ_COMPLIANCE.md
    ├─ 0A.4: US_COMPLIANCE.md
    ├─ 0A.5: SECURITY_FRAMEWORK.md
    ├─ 0A.6: CERTIFICATIONS_ROADMAP.md
    ├─ 0A.7: INCIDENT_RESPONSE.md
    ├─ 0A.8: CURRENCY_INFLATION.md
    ├─ 0A.9: TAX_TREATMENT.md
    ├─ 0A.10: ESTATE_IMPACT.md
    ├─ 0A.11: EPM_VARIANTS.md
    └─ 0A.12: INSURANCE_FRAMEWORK.md
PHASE 1: Infrastructure & Upgrades (existing, but updated with 0A refs)
PHASE 2: Core Platform Completion (existing, but enhanced with 0A)
PHASE 3: UX & Mobile Optimization (existing)
PHASE 4: Testing & QA (existing, with regional test cases)
PHASE 5: Documentation & Demo Prep (existing, with 0A summaries)
PHASE 6: Cleanup & Optimization (existing)
```

**Total Tokens (All Phases):** 200k (original REFACTOR_PROMPT) + 60k (Phase 0A in-session) = **260k**

---

## SECTION 9: DECISION MATRIX

### Should You Do Phase 0A?

**Do Phase 0A if:**
- ✅ You plan to operate in UK (GDPR mandatory)
- ✅ You plan to raise VC funding (due diligence required)
- ✅ You plan to launch in multiple regions simultaneously (avoid rework)
- ✅ You want contracts/legal reviewed by counsel (need regulatory specifics first)
- ✅ You have 2-3 hours available (60k tokens, in-session, no sub-agent waste)

**Skip Phase 0A if:**
- ✅ Launching AU-only first (simpler regulatory landscape)
- ✅ Have external legal counsel already (they'll advise)
- ✅ Willing to rework contracts/model post-launch
- ✅ Want to move to Phase 1 immediately

**Recommended:** Do Phase 0A. It's 2.5 hours + 60k tokens, but saves 4+ weeks of compliance rework post-launch. Worth it for VC-ready product.

---

## SECTION 10: NEXT STEPS

1. **Decide:** Do Phase 0A now, or proceed with REFACTOR_PROMPT.md?

2. **If YES to Phase 0A:**
   - ✅ Use Opus, work in-session (this session), not spawned agents
   - ✅ Break into 4-6k chunks (10-15 min per work)
   - ✅ Start with Work 1: AUSTRALIA_COMPLIANCE.md Part 1 (Opus)
   - ✅ Document each as go
   - ✅ Commit compliance docs to git after every 2-3 works
   - ✅ Total: ~2.5 hours, 60k tokens, all in-session

3. **If NO to Phase 0A:**
   - Proceed with Phase 1.1 (Rails upgrade) from REFACTOR_PROMPT.md
   - Flag compliance gap for later review (pre-VC demo)

**Recommendation:** Do Phase 0A. It's faster than you think (2.5h), and compliance docs are non-negotiable before contract drafting.

---

**Document Version:** 1.0  
**Status:** Ready for decision  
**Author:** Zen  
**Date:** 2026-03-06 20:01 GMT+11
