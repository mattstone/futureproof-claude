# FutureProof EPM — Australian Regulatory Assessment

**Date:** 2026-03-07  
**Status:** DRAFT — Requires Legal Review  
**Jurisdiction:** Australia (Commonwealth + State/Territory)

---

## 1. LICENSING REQUIREMENTS

### 1.1 Australian Credit Licence (ACL)

**Requirement:** Under the National Consumer Credit Protection Act 2009 (NCCP Act), any person engaging in credit activities must hold an ACL or be authorised by an ACL holder.

**Assessment for FutureProof EPM:**

| Question | Answer | Impact |
|----------|--------|--------|
| Does FutureProof provide credit? | **LIKELY YES** — EPM involves capital disbursement secured by property | ACL required |
| Is the product regulated credit? | **NEEDS LEGAL OPINION** — EPM is not traditional mortgage; equity participation model may fall outside Credit Code | Critical determination |
| Who is the credit provider? | The lender (not FutureProof) | FutureProof may need ACL as credit intermediary |
| Does FutureProof provide credit assistance? | **YES** — matching borrowers to lenders is credit assistance | ACL or authorised representative |

**Action Required:**
- [ ] Obtain formal legal opinion on whether EPM falls under NCCP Act
- [ ] If yes: Apply for ACL (ASIC Form FS01) — timeline 45 business days
- [ ] If no: Document the legal basis for exemption
- [ ] Consider: Authorised representative arrangement with existing ACL holder

**Estimated Cost:** $5,000-$15,000 (legal opinion + application if needed)  
**Timeline:** 4-8 weeks

### 1.2 Australian Financial Services Licence (AFSL)

**Assessment:** If EPM distributions constitute a "financial product" (managed investment scheme, derivative, or other), an AFSL may be required.

**Key Question:** Are monthly annuity payments from property equity a "financial product" under Corporations Act s764A?

**Preliminary View:** Likely NOT a managed investment scheme if:
- Borrower retains property ownership
- No pooling of funds across borrowers
- Each loan is bilateral (one lender, one borrower)

**Action Required:**
- [ ] Include in legal opinion request (above)
- [ ] If AFSL required: Application timeline 6-12 months, cost $20,000-$50,000

### 1.3 Real Property / Mortgage Broker Licensing

**State Requirements:**
- NSW: Requires licence under Property and Stock Agents Act 2002 (if acting as mortgage broker)
- VIC: Requires registration under Consumer Affairs Victoria
- QLD: Office of Fair Trading licence
- Other states: Vary

**Action Required:**
- [ ] Determine if FutureProof is "arranging" mortgages (trigger state licensing)
- [ ] If launching in specific states, obtain relevant licences
- [ ] Consider: National approach through ACL covers most state requirements

---

## 2. NATIONAL CREDIT CODE COMPLIANCE

### 2.1 Responsible Lending Obligations (NCCP Act Part 3-1)

If the Credit Code applies, FutureProof/lenders must:

| Obligation | Current Status | Gap |
|-----------|----------------|-----|
| Make reasonable inquiries about consumer's financial situation | ❌ Not implemented | Application form collects basic info only |
| Make reasonable inquiries about consumer's requirements/objectives | ❌ Not implemented | No suitability assessment |
| Take reasonable steps to verify financial situation | ❌ Not implemented | No income/expense verification |
| Make preliminary assessment (not unsuitable) | ❌ Not implemented | No assessment framework |
| Provide assessment if requested | ❌ Not implemented | No consumer access mechanism |
| Keep records of assessment | ❌ Not implemented | No audit trail for lending decisions |

**Implementation Required:**
- [ ] Suitability assessment questionnaire in application flow
- [ ] Income/expense verification workflow
- [ ] Automated preliminary assessment (rule-based + manual override)
- [ ] Assessment storage and consumer access endpoint
- [ ] Audit trail for all lending decisions

### 2.2 Disclosure Requirements

| Document | Current Status | Gap |
|----------|----------------|-----|
| Credit Guide | ❌ Missing | Must be provided before any credit assistance |
| Key Facts Sheet | ❌ Missing | Must be provided before credit contract |
| Pre-contractual disclosure | ⚠️ Partial | Contract exists but not in prescribed format |
| Information Statement | ❌ Missing | Required for credit contracts |

**Implementation Required:**
- [ ] Credit Guide (template + delivery mechanism before application)
- [ ] Key Facts Sheet generator (auto-populated from loan terms)
- [ ] Information Statement (prescribed form)
- [ ] Delivery tracking (proof consumer received documents)

### 2.3 Hardship Provisions (NCC Part 4)

**Requirement:** Lenders must have a hardship process for borrowers experiencing financial difficulty.

**Current Status:** ❌ Not implemented

**Implementation Required:**
- [ ] Hardship application form/workflow
- [ ] Assessment criteria and decision framework
- [ ] Response timeline tracking (21 days to respond)
- [ ] IDR (Internal Dispute Resolution) process
- [ ] AFCA (Australian Financial Complaints Authority) membership

### 2.4 Cooling-Off Period

**Requirement:** 14-day cooling-off period for credit contracts (some exemptions).

**Current Status:** ❌ Not implemented

**Implementation Required:**
- [ ] Track contract signing date
- [ ] Enforce 14-day cooling-off before disbursement
- [ ] Cancel/unwind mechanism during cooling-off
- [ ] Notification to borrower of cooling-off rights

---

## 3. AML/CTF COMPLIANCE

### 3.1 Anti-Money Laundering and Counter-Terrorism Financing Act 2006

**Applicability:** Financial services providers must comply with AML/CTF obligations.

| Obligation | Current Status | Gap |
|-----------|----------------|-----|
| Customer Identification (KYC) | ⚠️ Basic model exists | No electronic verification, no document matching |
| Customer Due Diligence (CDD) | ❌ Missing | No risk-based CDD framework |
| Enhanced Due Diligence (EDD) | ❌ Missing | No high-risk customer process |
| Ongoing Customer Due Diligence | ❌ Missing | No periodic review |
| Transaction Monitoring | ❌ Missing | No threshold reporting |
| Suspicious Matter Reporting (SMR) | ❌ Missing | No reporting to AUSTRAC |
| AML/CTF Program | ❌ Missing | No formal program document |
| Record Keeping | ⚠️ Partial | Basic records exist, retention not compliant |

**Implementation Required:**
- [ ] Electronic identity verification (integrate with provider: GreenID, Equifax, etc.)
- [ ] Risk-based CDD framework (low/medium/high risk classifications)
- [ ] EDD workflow for high-risk customers (PEPs, high-value transactions)
- [ ] Transaction monitoring rules ($10,000 threshold, patterns)
- [ ] SMR workflow and AUSTRAC reporting integration
- [ ] Formal AML/CTF Program document
- [ ] Staff training program
- [ ] Annual review process
- [ ] Record retention (7 years minimum)

**Estimated Cost:** $15,000-$30,000 (identity verification setup + program development)  
**Timeline:** 4-6 weeks

---

## 4. PRIVACY ACT 1988 COMPLIANCE

### 4.1 Australian Privacy Principles (APPs) Assessment

| APP | Description | Current Status | Gap |
|-----|-------------|----------------|-----|
| APP 1 | Open and transparent management | ⚠️ Privacy policy exists | Not APP-compliant format |
| APP 2 | Anonymity and pseudonymity | ❌ Not implemented | No option for anonymous browsing |
| APP 3 | Collection of solicited info | ⚠️ Partial | Collection points not documented |
| APP 4 | Dealing with unsolicited info | ❌ Not implemented | No process defined |
| APP 5 | Notification of collection | ❌ Not implemented | No collection notices at point of collection |
| APP 6 | Use or disclosure | ⚠️ Partial | Privacy policy covers, but no enforcement |
| APP 7 | Direct marketing | ❌ Not assessed | Marketing consent not tracked |
| APP 8 | Cross-border disclosure | ❌ Not implemented | Server location/data flow not documented |
| APP 9 | Adoption/disclosure of government IDs | ⚠️ Partial | KYC uses IDs but rules not enforced |
| APP 10 | Quality of personal information | ❌ Not implemented | No data quality process |
| APP 11 | Security of personal information | ❌ Critical gap | No encryption at rest, no security audit |
| APP 12 | Access to personal information | ❌ Not implemented | No data access request mechanism |
| APP 13 | Correction of personal information | ❌ Not implemented | No data correction mechanism |

**Critical Actions:**
- [ ] Rewrite Privacy Policy to APP-compliant format (in progress — show_au.html.erb)
- [ ] Implement data access request endpoint (APP 12)
- [ ] Implement data correction request endpoint (APP 13)
- [ ] Implement collection notices at each data collection point (APP 5)
- [ ] Encrypt personal information at rest (APP 11) — **CRITICAL**
- [ ] Document cross-border data flows (Neon.com database, Fly.io hosting)
- [ ] Implement marketing consent tracking (APP 7)
- [ ] Data retention schedule and automated deletion

### 4.2 Notifiable Data Breaches (NDB) Scheme

**Requirement:** Must notify OAIC and affected individuals of eligible data breaches.

**Current Status:** ❌ Not implemented

**Implementation Required:**
- [ ] Data breach response plan
- [ ] OAIC notification template and process
- [ ] Individual notification templates
- [ ] Breach assessment criteria (likely vs unlikely serious harm)
- [ ] Breach register

---

## 5. CONSUMER PROTECTION

### 5.1 Australian Consumer Law (ACL)

| Requirement | Current Status | Gap |
|-------------|----------------|-----|
| No misleading or deceptive conduct | ⚠️ Review needed | Marketing copy not legally reviewed |
| No unconscionable conduct | ⚠️ Review needed | Terms fairness not assessed |
| Unfair contract terms protection | ❌ Not assessed | Standard terms may contain unfair terms |
| Consumer guarantees | ⚠️ Review needed | Service guarantees not documented |

**Action Required:**
- [ ] Legal review of all customer-facing content for misleading claims
- [ ] Unfair contract terms assessment of standard loan terms
- [ ] Ensure cooling-off and cancellation rights comply with ACL
- [ ] Product disclosure review (financial product advertising rules)

---

## 6. DATA SECURITY REQUIREMENTS

### 6.1 Current Security Posture

| Area | Current Status | Risk Level |
|------|----------------|------------|
| Data encryption at rest | ❌ Not implemented | **CRITICAL** |
| Data encryption in transit | ✅ HTTPS/TLS | Low |
| Database access controls | ⚠️ Basic | Medium |
| Application security audit | ❌ Not done | **HIGH** |
| Penetration testing | ❌ Not done | **HIGH** |
| WAF (Web Application Firewall) | ❌ Not configured | Medium |
| Rate limiting | ❌ Not implemented | Medium |
| Session management | ⚠️ Devise defaults | Medium |
| CSRF protection | ✅ Rails default | Low |
| SQL injection protection | ✅ Rails ORM | Low |
| XSS protection | ✅ Rails default | Low |

**Critical Actions:**
- [ ] Implement column-level encryption for sensitive data (SSN, bank details)
- [ ] External security audit / penetration test
- [ ] WAF configuration on Fly.io
- [ ] Rate limiting on authentication and API endpoints
- [ ] Session timeout configuration (regulatory requirement)

---

## 7. COMPLIANCE CHECKLIST — LAUNCH READINESS

### Must-Have Before Launch (AU)

- [ ] Legal opinion on regulatory classification (ACL/AFSL/exemption)
- [ ] ACL application submitted (if required)
- [ ] APP-compliant Privacy Policy published
- [ ] Credit Guide available (if Credit Code applies)
- [ ] Key Facts Sheet generator working
- [ ] Hardship provisions implemented
- [ ] Cooling-off period enforced
- [ ] Electronic identity verification integrated
- [ ] AML/CTF Program documented
- [ ] AUSTRAC enrolment (if reporting entity)
- [ ] AFCA membership (dispute resolution)
- [ ] Data breach response plan
- [ ] Column-level encryption for sensitive data
- [ ] External security audit completed
- [ ] Unfair contract terms assessment completed

### Should-Have Before Launch

- [ ] EDD workflow for high-risk customers
- [ ] Transaction monitoring automated
- [ ] Consumer data access/correction endpoints
- [ ] Marketing consent management
- [ ] Staff training program
- [ ] Operational runbooks
- [ ] Incident response procedures

### Nice-to-Have (Post-Launch)

- [ ] Automated compliance reporting
- [ ] Real-time risk scoring
- [ ] AI-powered transaction monitoring
- [ ] Automated regulatory update monitoring

---

## 8. COST ESTIMATE

| Item | Estimated Cost | Timeline |
|------|---------------|----------|
| Legal opinion (ACL/AFSL) | $5,000-$15,000 | 2-4 weeks |
| ACL application (if required) | $5,000-$10,000 | 6-8 weeks |
| AML/CTF program + ID verification | $15,000-$30,000 | 4-6 weeks |
| External security audit | $10,000-$25,000 | 2-3 weeks |
| AFCA membership | $350/year | 1 week |
| Compliance documentation (agent-assisted) | $2,000-$5,000 | 2-3 weeks |
| Unfair terms review | $3,000-$5,000 | 1-2 weeks |
| **Total** | **$40,350-$90,350** | **8-16 weeks** |

---

## 9. RECOMMENDED SEQUENCE

1. **Week 1-2:** Legal opinion on regulatory classification
2. **Week 2-3:** Begin ACL application (if needed) + AML/CTF program
3. **Week 3-4:** Security audit engagement + encryption implementation
4. **Week 4-6:** Compliance documentation (Credit Guide, Key Facts Sheet, etc.)
5. **Week 6-8:** Identity verification integration + hardship workflow
6. **Week 8-10:** Testing + remediation from security audit
7. **Week 10-12:** AFCA membership + final compliance review
8. **Week 12+:** Soft launch with limited borrowers

---

*This document is a preliminary assessment and does NOT constitute legal advice. All regulatory determinations must be confirmed by qualified Australian legal counsel.*
