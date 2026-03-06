# Australia Compliance — FutureProof EPM

**Version:** 1.0  
**Created:** 2026-03-06  
**Scope:** Part 1 — Responsible lending, LVR, disclosure, consumer guarantees  
**Regulator:** ASIC (Australian Securities and Investments Commission)  
**Key Legislation:** National Consumer Credit Protection Act 2009 (NCCP), National Credit Code (NCC)

---

## 1. REGULATORY CLASSIFICATION

### 1.1 Is EPM a "Credit Product" Under Australian Law?

**Yes — almost certainly.** Under the NCCP Act, a "credit contract" exists when:

1. A debtor is provided credit (✅ — loan secured against home equity)
2. A charge is made for providing credit (✅ — lender margin/fees)
3. The credit is provided in the course of business (✅)

**However — EPM has unique characteristics:**
- Consumer makes **no repayments** (lender bears repayment risk)
- Consumer receives **income** (not a traditional loan purpose)
- Loan is repaid from **investment returns**, not consumer cash flow

**Regulatory Risk:** ASIC may classify EPM as:
- A **credit facility** (NCC applies) — most likely
- A **managed investment scheme** (Corporations Act, Chapter 5C) — if investment component is emphasised
- A **financial product** (AFSL required) — if income stream is the primary offering

**Recommendation:** Seek ASIC no-action letter or formal product ruling before launch. Design contracts to fit within NCC framework (simpler licensing path).

### 1.2 Required Licences

| Licence | Purpose | Required? | Notes |
|---|---|---|---|
| Australian Credit Licence (ACL) | Engage in credit activities | ✅ Yes | Mandatory for any credit provider |
| Australian Financial Services Licence (AFSL) | Provide financial product advice | ⚠️ Likely | If advising on investment component |
| Authorised Representative | Broker/referral network | ✅ Yes | Brokers must be authorised reps |

**Key Point:** FutureProof (or its lender partners) must hold an ACL. If FutureProof operates as a platform connecting customers to lenders, it may need ACL as a **credit intermediary** under s29 NCCP Act.

---

## 2. RESPONSIBLE LENDING OBLIGATIONS

### 2.1 Overview

Under Part 3-2 of the NCCP Act, credit providers must:

1. **Make reasonable inquiries** about the consumer's financial situation
2. **Take reasonable steps** to verify the consumer's financial situation  
3. **Make an assessment** that the credit contract is "not unsuitable" for the consumer

### 2.2 EPM-Specific Responsible Lending

**Critical distinction:** Because the consumer makes NO repayments, the traditional "can they afford repayments?" test doesn't apply in the usual sense. Instead:

**Inquiries Required:**

| Inquiry | Purpose | EPM Relevance |
|---|---|---|
| Income & expenses | Assess affordability | ⚠️ Less relevant (no repayments) but still required |
| Assets & liabilities | Assess net position | ✅ Critical — home value, existing mortgages |
| Existing debts | Assess over-commitment | ✅ Any existing mortgage affects LVR |
| Requirements & objectives | Why they want credit | ✅ Income needs, retirement planning |
| Age & life expectancy | Suitability assessment | ✅ EPM term linked to expected occupancy |

**"Not Unsuitable" Assessment for EPM:**

The credit contract is **unsuitable** if:
- It does not meet the consumer's requirements or objectives (e.g., they need more income than EPM provides)
- The consumer could not meet financial obligations IF ANY exist (e.g., property maintenance, insurance, rates)
- The consumer would suffer substantial hardship

**EPM-Specific Suitability Factors:**
1. Consumer understands they are pledging home equity
2. Consumer has no better alternative (e.g., reverse mortgage comparison)
3. Consumer's ongoing property obligations (rates, insurance, maintenance) remain affordable
4. Consumer understands estate implications (beneficiaries informed)
5. Consumer is not under undue pressure or influence

### 2.3 Documentation Requirements

**For each EPM application, lender must retain:**

1. **Preliminary Assessment** — Written record of suitability determination
2. **Credit Guide** — Provided before entering contract (s126 NCC)
3. **Pre-contractual Disclosure** — Key facts sheet (terms, fees, total cost)
4. **Verification Records** — Payslips, bank statements, property valuation
5. **Consent Records** — Consumer acknowledged understanding of EPM structure

**Retention Period:** 7 years after contract ends (s186 NCCP Act)

---

## 3. LOAN-TO-VALUE RATIO (LVR)

### 3.1 APRA Prudential Standards

APRA (Australian Prudential Regulation Authority) sets LVR guidelines for ADIs (Authorised Deposit-taking Institutions):

| LVR Band | Requirement | EPM Application |
|---|---|---|
| ≤60% | Standard — no additional requirements | ✅ Ideal EPM range |
| 60-80% | Standard — may require additional assessment | ✅ Acceptable with strong valuation |
| 80-90% | Requires LMI (Lender's Mortgage Insurance) | ⚠️ Avoid for EPM — adds cost |
| >90% | High risk — restricted, requires LMI + additional capital | ❌ Not suitable for EPM |

### 3.2 EPM LVR Framework (Recommended)

**Maximum LVR: 80%** (aligns with REFACTOR_PROMPT.md)

**EPM-Specific LVR Considerations:**
- Property valuation must be independent (APRA APS 220)
- Valuation provider: CoreLogic RP Data, or licensed valuer (API Qualified)
- Revaluation frequency: Annual (at minimum) or on trigger event
- LVR drift: If property value drops, LVR increases — trigger points needed

**Trigger Events (LVR Monitoring):**

| Trigger | LVR Threshold | Action |
|---|---|---|
| Annual review | >85% | Notify lender, assess portfolio adjustment |
| Market correction | >90% | Mandatory review, potential income pause |
| Consumer request | Any | Revaluation within 30 days |
| Property damage | Any | Reassess immediately |

### 3.3 Lender's Mortgage Insurance (LMI)

**If LVR exceeds 80%:**
- LMI required (protects LENDER, not consumer)
- LMI providers: QBE LMI, Helia (formerly Genworth)
- Cost: 0.5-3% of loan amount (varies by LVR and loan size)
- One-off premium, typically capitalised into loan

**EPM Approach:** Target LVR ≤80% to avoid LMI entirely. LMI adds complexity and cost without consumer benefit.

---

## 4. INTEREST RATE DISCLOSURE

### 4.1 NCC Disclosure Requirements

Under the National Credit Code (Schedule 1 of the NCCP Act):

**Pre-contractual disclosure must include:**

| Disclosure Item | NCC Reference | EPM Application |
|---|---|---|
| Annual percentage rate | s17 NCC | ✅ Lender's margin rate |
| Comparison rate | Regulations | ✅ Must calculate and display |
| Total amount of credit | s17 NCC | ✅ Loan amount (home value × LVR) |
| Total amount of interest | s17 NCC | ⚠️ Complex — interest paid from investment returns, not consumer |
| Fees and charges | s17 NCC | ✅ All fees itemised |
| Default rate | s17 NCC | ⚠️ N/A if consumer makes no repayments |

### 4.2 Comparison Rate

**Mandatory under NCCP Regulations:**
- Must display comparison rate alongside advertised rate
- Comparison rate includes fees and charges
- Calculated using standard methodology (Schedule 8, NCCP Regulations)

**EPM Challenge:** Comparison rate assumes repayments — EPM has none. Options:
1. Calculate comparison rate as if consumer were making repayments (may be misleading)
2. Seek ASIC exemption or guidance on alternative disclosure
3. Display effective cost rate (lender margin + fees as % of loan)

**Recommendation:** Engage ASIC early on comparison rate methodology for EPM. Standard comparison rate may not meaningfully apply.

### 4.3 Interest Rate Type

**EPM Interest Structure:**
- Lender charges interest on the mortgage (margin)
- Interest is paid from investment portfolio returns — NOT by consumer
- Consumer sees: monthly income amount (after lender margin deducted)

**Disclosure to Consumer:**
- "Your lender charges X% p.a. on the loan amount"
- "This is deducted from investment returns before your income is calculated"
- "You do not make interest payments directly"
- "If investment returns are insufficient, the lender absorbs the shortfall"

---

## 5. CONSUMER GUARANTEES & PROTECTIONS

### 5.1 Australian Consumer Law (ACL) — Schedule 2 of CCA

**Consumer guarantees that may apply:**

| Guarantee | ACL Section | EPM Application |
|---|---|---|
| Due care and skill | s60 | ✅ Platform and advisory services |
| Fit for purpose | s61 | ✅ EPM must deliver stated income |
| Reasonable time | s62 | ✅ Application processing timeframes |
| Acceptable quality | s54 | ⚠️ Less applicable (financial product) |

### 5.2 Unfair Contract Terms (UCT)

**Under Part 2-3 ACL:**
- Standard form contracts with consumers are subject to UCT review
- ASIC can challenge terms that are "unfair"
- A term is unfair if it:
  1. Causes significant imbalance in parties' rights (consumer disadvantaged)
  2. Is not reasonably necessary to protect legitimate interests
  3. Would cause detriment if relied on

**EPM Terms to Review for UCT:**
- Unilateral variation of income amount
- Unilateral property revaluation triggers
- Early termination clauses (if consumer wants to exit)
- Fee escalation clauses
- Assignment of loan without consumer consent

**Recommendation:** Have all consumer-facing contracts reviewed by consumer credit lawyer for UCT compliance before launch.

### 5.3 Hardship Provisions

**Under s72 NCC:**
- Consumer can apply for hardship variation if unable to meet obligations
- EPM context: Consumer's only obligation is maintaining property (rates, insurance, upkeep)
- If consumer cannot maintain property → may trigger default

**EPM Hardship Framework:**
1. Consumer notifies lender of hardship (property maintenance costs)
2. Lender assesses: Can income be redirected to cover property costs?
3. Options: Temporary income reduction to cover rates/insurance, or property sale facilitation
4. Documentation: Written hardship application + assessment + outcome

### 5.4 Dispute Resolution

**Mandatory under NCCP Act:**
- Must be member of AFCA (Australian Financial Complaints Authority)
- Consumer can lodge complaint with AFCA (free of charge)
- AFCA can make binding determinations up to $1.14M (credit disputes)

**EPM Platform Must:**
1. Display AFCA membership number on all consumer documents
2. Provide internal dispute resolution (IDR) process first
3. Respond to IDR complaints within 30 days
4. Notify consumer of right to escalate to AFCA if IDR fails

---

## 6. KEY DEFINITIONS (AU Context)

| Term | Definition |
|---|---|
| **ACL** | Australian Credit Licence — required to provide credit |
| **AFSL** | Australian Financial Services Licence — required to advise on financial products |
| **APRA** | Australian Prudential Regulation Authority — regulates ADIs |
| **ASIC** | Australian Securities and Investments Commission — consumer protection |
| **AFCA** | Australian Financial Complaints Authority — dispute resolution |
| **NCC** | National Credit Code — Schedule 1 of NCCP Act |
| **NCCP Act** | National Consumer Credit Protection Act 2009 |
| **LVR** | Loan-to-Value Ratio |
| **LMI** | Lender's Mortgage Insurance |
| **ADI** | Authorised Deposit-taking Institution |
| **UCT** | Unfair Contract Terms |

---

## 7. IMPLEMENTATION CHECKLIST

### Pre-Launch (Mandatory)

- [ ] Confirm ACL holder (FutureProof or lender partner)
- [ ] Confirm AFSL requirement (seek ASIC guidance)
- [ ] AFCA membership obtained
- [ ] Credit Guide drafted (s126 NCC)
- [ ] Pre-contractual disclosure template created
- [ ] Preliminary Assessment template created
- [ ] Responsible lending policy documented
- [ ] Comparison rate methodology confirmed (ASIC guidance)
- [ ] UCT review of all consumer contracts completed
- [ ] Hardship policy documented
- [ ] IDR process documented
- [ ] Document retention policy (7 years minimum)
- [ ] Broker authorised representative framework established

### Platform Implementation

- [ ] LVR calculator respects 80% maximum
- [ ] Property valuation integration (CoreLogic API or equivalent)
- [ ] Annual revaluation trigger system
- [ ] LVR monitoring dashboard (trigger alerts at 85%, 90%)
- [ ] Credit Guide served digitally (with acknowledgement)
- [ ] Pre-contractual disclosure generated per application
- [ ] Preliminary Assessment stored per application (7yr retention)
- [ ] AFCA details displayed on all consumer-facing pages
- [ ] Hardship application form accessible from customer dashboard
- [ ] IDR complaint form accessible from customer dashboard

---

---

# PART 2 — AFSL, Superannuation, Stamp Duty, AML/CTF, Privacy

---

## 8. AFSL REQUIREMENTS

### 8.1 When Is an AFSL Required?

Under the Corporations Act 2001 (Cth), an AFSL is required to:
- Provide financial product advice (personal or general)
- Deal in a financial product (issue, arrange, apply for)
- Operate a registered managed investment scheme

### 8.2 EPM & AFSL — Does It Apply?

**The investment component of EPM may trigger AFSL requirements:**

| Activity | AFSL Required? | Reasoning |
|---|---|---|
| Arranging the mortgage | ❌ No (ACL covers this) | Credit activity, not financial product |
| Managing the investment portfolio | ✅ Yes | Dealing in financial products (ETF, annuity) |
| Advising consumer on expected returns | ⚠️ Likely | Could be "personal financial product advice" |
| Providing income projections | ⚠️ Likely | Projections based on investment performance = advice |
| Displaying Monte Carlo scenarios | ⚠️ Possibly | General advice if disclaimered correctly |

**Key Risk:** If FutureProof tells a consumer "you can expect $3,200/month income" based on investment projections, that may constitute **personal financial product advice** under s766B Corporations Act.

### 8.3 Mitigation Strategies

**Option A: General Advice Only (Lower Burden)**
- All projections carry general advice warning
- No personalised recommendations on investment mix
- Consumer directed to seek independent financial advice
- Requires: General Advice AFSL authorisation

**Required Disclaimer (General Advice Warning):**
> "This information is general in nature and does not take into account your personal financial situation, objectives, or needs. You should consider whether it is appropriate for you and seek independent financial advice before making any decision."

**Option B: Personal Advice (Higher Burden)**
- FutureProof (or authorised representative) provides personalised recommendations
- Requires: Personal Advice AFSL authorisation
- Must prepare Statement of Advice (SoA) for each consumer
- Must meet Best Interests Duty (s961B Corporations Act)
- Must have compliant advisers (FASEA standards, relevant degree, CPD)

**Recommendation:** Launch with **Option A (General Advice Only)** — significantly simpler. Upgrade to Option B only if business model requires personalised advice.

### 8.4 Investment Manager Relationship

**If BlackRock (or equivalent) manages the portfolio:**
- Investment manager holds their own AFSL
- FutureProof acts as distributor, not manager
- FutureProof needs AFSL authorisation to "deal" (arrange acquisition of financial products)
- Product Disclosure Statement (PDS) from fund manager must be provided to consumer

**Platform Implementation:**
- [ ] General Advice Warning displayed on all projection/calculator pages
- [ ] Link to fund manager's PDS on customer dashboard
- [ ] "Seek independent advice" prompt before application submission
- [ ] No personalised investment recommendations in chat agents

---

## 9. SUPERANNUATION INTERACTION

### 9.1 How EPM Affects Superannuation

**Age Pension (Centrelink):**

| Factor | Impact | Detail |
|---|---|---|
| Income test | ✅ EPM income counts | Monthly EPM income is assessable income for Age Pension |
| Assets test | ⚠️ Complex | Home (principal residence) is exempt; investment portfolio may NOT be |
| Deeming | ✅ May apply | Investment portfolio deemed to earn income at deeming rates |

**Critical Issue:** If EPM income pushes consumer above Age Pension income threshold, they may lose pension entitlements. This MUST be disclosed.

**Deeming Rules (as at 2026):**
- First $60,400 (single) / $100,200 (couple): deemed at 0.25%
- Above threshold: deemed at 2.25%
- Investment portfolio value may be deemed regardless of actual returns

### 9.2 Superannuation Access

**EPM does NOT affect superannuation access directly**, but:
- Consumer may have super they could draw on instead of EPM
- Financial comparison: Is EPM better than drawing super? (general advice only)
- If consumer is pre-preservation age (<60), super is locked — EPM fills income gap

**Disclosure Required:**
> "Taking an EPM may affect your eligibility for the Age Pension. We recommend you contact Services Australia (Centrelink) or a financial adviser to understand the impact on your pension entitlements before proceeding."

### 9.3 First Home Super Saver Scheme (FHSSS)

**Not directly relevant** — EPM targets existing homeowners, not first home buyers. However, if consumer used FHSSS to purchase property, no additional restrictions on taking EPM.

---

## 10. STAMP DUTY & GOVERNMENT CHARGES

### 10.1 Mortgage Registration

**Stamp duty on mortgages varies by state/territory:**

| State/Territory | Mortgage Duty | Status |
|---|---|---|
| NSW | ❌ Abolished (2016) | No duty |
| VIC | ❌ Abolished (2004) | No duty |
| QLD | ❌ Abolished (2008) | No duty |
| WA | ❌ Abolished (2008) | No duty |
| SA | ✅ Still applies | $0-$4,000 depending on loan amount |
| TAS | ❌ Abolished | No duty |
| ACT | ❌ Abolished | No duty |
| NT | ❌ Abolished | No duty |

**Impact:** Only SA still charges mortgage duty. Minor cost, but must be disclosed in SA applications.

### 10.2 Land Titles Office Registration

**Mortgage must be registered with state Land Titles Office:**

| State | Registration Fee (approx.) |
|---|---|
| NSW | $157.40 |
| VIC | $125.30 |
| QLD | $198.00 |
| WA | $189.20 |
| SA | $183.00 |
| TAS | $144.56 |
| ACT | $160.00 |
| NT | $151.00 |

**These fees are payable by consumer or lender (negotiable in contract).**

### 10.3 Discharge Fees

**When EPM ends (sale, refinance, term expiry):**
- Mortgage discharge registration: ~$150-200 per state
- Lender discharge fee: Varies (should be disclosed upfront)
- Settlement agent/conveyancer fee: $500-$1,500

---

## 11. AML/CTF (Anti-Money Laundering / Counter-Terrorism Financing)

### 11.1 Obligations Under AML/CTF Act 2006

**FutureProof (or lender) is a "reporting entity" if providing a "designated service":**
- Lending money secured by real property = designated service (item 26, Table 1)
- Must enrol with AUSTRAC
- Must have AML/CTF program

### 11.2 Customer Identification (KYC)

**Minimum Verification Standard (MVS):**

| Requirement | Detail |
|---|---|
| Full name | Verified against government-issued ID |
| Date of birth | Verified against ID |
| Residential address | Verified (not PO Box) |
| ID documents | Minimum 1 primary (passport, driver licence) + 1 secondary (Medicare, birth cert) |

**Electronic Verification (eKYC) Acceptable:**
- Services: GreenID, Equifax IDMatrix, illion
- Must meet AUSTRAC safe harbour provisions
- Retain records for 7 years after relationship ends

### 11.3 Ongoing Monitoring

| Obligation | Frequency | Detail |
|---|---|---|
| Transaction monitoring | Ongoing | Flag unusual patterns (large withdrawals, atypical behaviour) |
| Enhanced Due Diligence | As needed | PEPs (Politically Exposed Persons), high-risk countries |
| Suspicious Matter Reports (SMR) | As needed | Lodge with AUSTRAC within 24 hours (terrorism) or 3 days |
| Threshold Transaction Reports (TTR) | Per transaction | Cash transactions ≥$10,000 |
| IFTI Reports | Per transaction | International fund transfers ≥$10,000 |

### 11.4 EPM-Specific AML Risks

| Risk | Scenario | Mitigation |
|---|---|---|
| Property used for laundering | Consumer purchases property with illicit funds, then takes EPM to "clean" equity | Verify property purchase history, source of deposit |
| Structuring | Multiple small EPM applications to avoid thresholds | Monitor across related parties |
| Terrorist financing | EPM income redirected to sanctioned entities | Ongoing transaction monitoring on income disbursements |

**Platform Implementation:**
- [ ] AUSTRAC enrolment completed
- [ ] AML/CTF program documented and board-approved
- [ ] eKYC integration (GreenID or equivalent)
- [ ] PEP screening at onboarding
- [ ] Sanctions screening (DFAT consolidated list)
- [ ] Transaction monitoring system (income disbursements)
- [ ] SMR lodgement process documented
- [ ] Staff AML/CTF training program (annual)
- [ ] Record retention: 7 years post-relationship

---

## 12. PRIVACY — AUSTRALIAN PRIVACY PRINCIPLES (APPs)

### 12.1 Privacy Act 1988 (Cth)

**FutureProof must comply with the 13 APPs if annual turnover >$3M (likely):**

| APP | Requirement | EPM Implementation |
|---|---|---|
| APP 1 | Open & transparent management | Privacy policy published, updated annually |
| APP 2 | Anonymity & pseudonymity | Allow anonymous browsing (calculator); identity required for application |
| APP 3 | Collection of personal info | Collect only what's necessary for EPM |
| APP 4 | Unsolicited personal info | Destroy if not needed |
| APP 5 | Notification of collection | Tell consumer what you're collecting and why |
| APP 6 | Use & disclosure | Only for stated purpose (EPM assessment) |
| APP 7 | Direct marketing | Opt-in only; easy unsubscribe |
| APP 8 | Cross-border disclosure | If data sent offshore (cloud hosting), inform consumer |
| APP 9 | Government identifiers | Don't use TFN/Medicare as identifier |
| APP 10 | Quality of personal info | Keep accurate, up-to-date |
| APP 11 | Security | Reasonable steps to protect (encryption, access controls) |
| APP 12 | Access | Consumer can request access to their data |
| APP 13 | Correction | Consumer can request correction |

### 12.2 Credit Reporting (Part IIIA Privacy Act)

**EPM involves credit reporting obligations:**

| Obligation | Detail |
|---|---|
| Credit reporting body (CRB) notification | Must notify Equifax/Experian/illion of new credit account |
| Comprehensive Credit Reporting (CCR) | Report positive and negative credit data |
| Hardship flag | If consumer enters hardship arrangement, flag on credit report |
| Default listing | If loan defaults (lender risk, but still reported) |
| Consumer access | Consumer can request free credit report annually |

**EPM-Specific:** Since consumer makes no repayments, there are no "repayment history" entries. However:
- Account opening is reported
- Account limit (loan amount) is reported
- Any default or hardship arrangement is reported
- This may affect consumer's capacity to obtain other credit

**Disclosure Required:**
> "Taking an EPM will be recorded on your credit report. This may affect your ability to obtain other credit products (personal loans, credit cards, other mortgages). The EPM will appear as a secured credit facility."

### 12.3 Notifiable Data Breaches (NDB) Scheme

**Under Part IIIC Privacy Act:**

| Requirement | Detail |
|---|---|
| Assessment | Assess suspected breach within 30 days |
| Notification trigger | "Likely to result in serious harm" |
| Who to notify | OAIC (Office of the Australian Information Commissioner) + affected individuals |
| Timeline | "As soon as practicable" after assessment confirms eligible breach |
| Form | OAIC NDB form (online) + individual notification (email/letter) |
| Penalty (failure) | Up to $50M or 30% of turnover (whichever greater) — Privacy Act 2022 amendments |

**Platform Implementation:**
- [ ] Privacy policy published (APP 1) — website footer
- [ ] Collection notice at application stage (APP 5)
- [ ] Data access request form on customer dashboard (APP 12)
- [ ] Data correction request form on customer dashboard (APP 13)
- [ ] Credit reporting consent obtained at application
- [ ] CRB integration (Equifax API or equivalent)
- [ ] NDB response plan documented
- [ ] NDB assessment process (30-day max)
- [ ] Data breach notification template (OAIC + consumer)
- [ ] Annual privacy impact assessment scheduled
- [ ] Cross-border data transfer register (if using offshore services)

---

## 13. CONSOLIDATED IMPLEMENTATION CHECKLIST

### Licensing & Registration
- [ ] ACL obtained (or lender partner holds ACL)
- [ ] AFSL assessment completed (general advice authorisation if needed)
- [ ] AUSTRAC enrolment completed
- [ ] AFCA membership obtained
- [ ] Land Titles Office registration process documented per state

### Consumer Protection
- [ ] Credit Guide (s126 NCC) — template created
- [ ] Pre-contractual disclosure — template created
- [ ] Preliminary Assessment — template created
- [ ] General Advice Warning — displayed on all projection pages
- [ ] Age Pension impact disclosure — displayed before application
- [ ] Credit reporting impact disclosure — displayed before application
- [ ] UCT review of all consumer contracts completed
- [ ] Hardship policy documented and accessible
- [ ] IDR + AFCA escalation process documented

### AML/CTF
- [ ] AML/CTF program documented
- [ ] eKYC integration operational
- [ ] PEP + sanctions screening operational
- [ ] Transaction monitoring operational
- [ ] SMR/TTR lodgement process documented
- [ ] Staff training program (annual)

### Privacy
- [ ] Privacy policy published
- [ ] Collection notice at application
- [ ] Data access/correction forms on dashboard
- [ ] CRB integration (credit reporting)
- [ ] NDB response plan documented
- [ ] Cross-border data transfer register maintained

### Ongoing Compliance
- [ ] Annual privacy impact assessment
- [ ] Annual AML/CTF program review
- [ ] Responsible lending policy review (biennial)
- [ ] AFCA complaint reporting (quarterly)
- [ ] ASIC regulatory updates monitoring

---

**Status:** AUSTRALIA_COMPLIANCE.md complete (Parts 1 & 2)  
**Next:** Work 3 — UK_COMPLIANCE.md Part 1
