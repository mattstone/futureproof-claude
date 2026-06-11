# Legal Document Templates — Enhancement Guide

## Status

**Platform: 99% Complete**
- ✅ Database models (5 tables)
- ✅ Service layer
- ✅ Admin controller
- ✅ **UI Views (all 8 files) — COMMITTED (11ea71f)**
- ✅ JavaScript (auto-save, tabs, diffs)
- ✅ CSS styling (plain, no compilation)
- ⏳ **Legal templates (enhancement pending)**

## What Needs to Happen

The 7 pre-seeded templates in `db/seeds/legal_document_templates.rb` need jurisdiction-specific regulatory enhancements:

### Current Templates (Basic)
Located in lines 1-429 of `db/seeds/legal_document_templates.rb`:
1. privacy_policy_au.md (~200 words)
2. terms_conditions_au.md (~250 words)
3. lender_agreement_au.md (~200 words)
4. privacy_policy_us.md (~200 words)
5. terms_conditions_us.md (~250 words)
6. privacy_policy_nz.md (~150 words)
7. privacy_policy_uk.md (~150 words)

### Enhanced Templates Required

Each template should follow the detailed specifications in the task brief below. Replace the basic versions with comprehensive, legally-rigorous versions.

## Australia (ASIC Compliance) — 3 Templates

### 1. Privacy Policy - Australia
**Target: 2000-2500 words**

Key sections:
- ASIC-specific collection/use disclosure
- Credit reporting disclosure (Privacy Act 1988 Cth, Section 21F)
  - What credit information is collected
  - Who receives it (lenders, credit bureaus, insurers)
  - How to correct errors
  - Dispute procedures
- OAIC (Office of the Australian Information Commissioner) escalation
  - Direct contact details
  - Complaint process & timeline
  - Investigation outcomes
- Breach notification requirements (Australian Cyber Security Incident Response Plan)
- Marketing preferences & opt-out
- Sensitive information handling
- Data security practices
- Overseas disclosure (to Australian partners)
- User rights (access, correction, complaint)
- Contact: {{contact_email}}, {{privacy_officer_name}}

### 2. Terms & Conditions - Australia
**Target: 3000-3500 words**

Key sections:
- Introduction with ASIC PDS reference
- EPM Explanation (plain language):
  - Customer retains property ownership
  - Mortgage secured against property
  - Proceeds invested
  - Monthly guaranteed income ({{income_percentage}}% p.a. of property value)
  - NO monthly loan repayments
  - Repaid on property sale or customer passing
- **No Negative Equity Guarantee (NNEG) — DETAILED:**
  - What it protects against
  - When it applies/doesn't apply
  - How it's funded
  - Examples (property value drops 20%, NNEG covers difference)
  - Limits and exclusions
  - Customer rights if triggered
- Cooling Off Period (14 days per ASIC):
  - Right to cancel penalty-free
  - Process: written notice to {{contact_address}}
  - Refunds: upfront fees returned within {{refund_days}} days
- **NCCP Act Obligations:**
  - Responsible lending (suitability, verification, affordability)
  - Regular review (annually)
  - Hardship management:
    - How to request {{hardship_contact}}
    - Loan modification options
    - 21-day response timeline
- **Complaint Handling (ASIC-compliant):**
  - Step 1: Internal complaint to {{complaint_email}}, 30-day response
  - Step 2: Escalation to Financial Ombudsman Service (FOS)
    - FOS investigation (30-180 days)
    - Decision within 5 business days
    - Compensation up to {{fos_limit}}
  - Step 3: ASIC escalation (www.asic.gov.au, 1300 300 630)
- Fees & charges table (Establishment, Annual, Valuation, Legal)
- Interest rate disclosure & variability
- Applicable law: Queensland & Commonwealth law
- Definitions (Property, Mortgage, Loan Amount, Term)

### 3. Lender Agreement - Australia
**Target: 2500-3000 words**

Key sections:
- Agreement parties: Futureproof (ABN: {{abn}}), Lender ({{lender_name}}, ACN: {{lender_acn}})
- **Responsible Lending Obligations (ASIC):**
  - Suitability assessment for each application
  - Information verification (income, assets, liabilities)
  - Affordability assessment
  - Documentation & customer disclosure
  - Annual review & hardship assistance
  - Compliance with ASIC RG 209
- **Capital Adequacy Standards:**
  - Maintain capital ratio of at least {{capital_ratio}}%
  - Reserve requirements: {{reserve_percentage}}% in liquid assets
- **Retail Investor Protections:**
  - All borrowers treated as retail investors
  - Enhanced disclosure (PDS before settlement)
  - Financial advice rights
- **Reporting Obligations:**
  - Monthly: Distribution statements (amount, property valuations, performance)
  - Quarterly: Portfolio review (loan count, performance metrics, risk assessment)
  - Annual: Compliance certification (ASIC suitability compliance, auditor sign-off)
- **Insurance & Indemnity:**
  - Lender insurance: {{insurance_premium}}% p.a. of balance, {{coverage_percentage}}% coverage
  - Lender indemnifies us against loss from lender default
  - Fraud/unfunded loan recovery rights
- Conflict of interest disclosure
- Regulatory acknowledgments (ASIC AFS License #{{license_number}}, NCCP Act, Privacy Act, AML/CTF)
- Definitions (Loan, Portfolio, Default, Hardship)

---

## United States (CCPA, TILA, Dodd-Frank) — 2 Templates

### 1. Privacy Policy - United States
**Target: 4000+ words (CCPA complexity)**

Key sections:
- Introduction & compliance statement
  - Privacy commitment
  - Applicable laws: GLBA, FCRA, CCPA, state laws, COPPA
  - Data controller: Futureproof Financial Group ({{us_address}})
- Information collected (directly, automatically, third-party)
- **California Consumer Privacy Act (CCPA) — Full Article 4 Rights:**
  - **Right to Know:** What data is collected, sources, business purpose, recipients
    - Timeline: 45 days (can extend 45 more with notice)
    - How to request: {{ccpa_request_method}}
    - Verification: we verify you're the person or authorized agent
    - Free: 2 requests per 12 months
  - **Right to Delete:** Delete personal information
    - Exceptions: law-required, fraud prevention, FCRA/GLBA obligations, contract
    - Timeline: 45 days (extendable 45 more)
  - **Right to Opt-Out of Sale/Sharing:**
    - **CRITICAL: WE DO NOT SELL YOUR PERSONAL INFORMATION**
    - We don't: sell to brokers/ad networks, share for their marketing, use for targeted ads
    - Opt-out link: {{ccpa_optout_link}}
  - **Right to Correct:** Correction of inaccurate information
    - Timeline: 45 days (or explain why not)
  - **Right to Limit Use & Disclosure:**
    - Limit to: loan servicing, regulatory compliance, fraud prevention
    - Timeline: 45 days
  - **Right to Non-Discrimination:**
    - No denial, price increase, or service reduction for exercising CCPA rights
    - No retaliation or threats
- **Virginia Consumer Data Protection Act (VCDPA):**
  - Similar rights (know, delete, correct, portability, opt-out targeted ads)
  - Virginia Attorney General enforcement
- **Other State Laws:**
  - Colorado (CPA), Connecticut (CTDPA) — similar consumer rights
  - We comply with all state privacy laws in your jurisdiction
- **Children's Privacy (COPPA):**
  - Parental consent required for users under 13
  - We don't knowingly collect data from children under 13
  - If discovered: delete immediately
  - Parental access rights
- **Data Breach Notification:**
  - California: without unreasonable delay (72 hours typical)
  - Other states: as required by law (varies, typically 30-60 days)
  - Notification method: email, mail, or phone
  - Information: what was breached, remediation, credit monitoring offer
  - Regulatory notification: AGs, credit bureaus, law enforcement
- **Credit Reporting (FCRA):**
  - May obtain credit reports during underwriting
  - May report payment history to credit bureaus
  - User rights: know what's reported, dispute inaccuracies, request removal
  - Bureau contacts: Equifax, Experian, TransUnion
- **Vendor/Service Provider Management:**
  - Share with: mortgage servicers, credit agencies, background check, payment processors, insurance
  - All sign data processing agreements (DPA)
  - Vendors agree to similar privacy protections
- **Data Retention Schedule (table):**
  - Loan Application: 7 years (TILA/FCRA)
  - Credit Report: 3 years (FCRA)
  - Payment History: Loan term + 7 years (GLBA)
  - Marketing: Until opt-out (Consent)
  - Identity Documents: 5 years (FinCEN KYC/AML)
- **Shine the Light Law (CA Civil Code 1798.100):**
  - California residents can request: "Who have you shared my info with?"
  - We disclose: categories of parties (lenders, insurers, service providers)
  - Free once per calendar year
- **Security Practices:**
  - Encryption: at rest (AES-256), in transit (TLS 1.2+)
  - Access controls: role-based, least privilege
  - Staff training: annual privacy/security
  - Monitoring: intrusion detection, vulnerability scanning
  - Incident response: 24/7 breach response team
- **Contact Information:**
  - Privacy Officer: {{privacy_officer_name}}, {{privacy_officer_email}}
  - Mailing Address: {{us_address}}
  - California Attorney General: [AG address]
  - CFPB: www.consumerfinance.gov/complaint

### 2. Terms & Conditions - United States
**Target: 4000+ words (state-specific detail)**

Key sections:
- Agreement overview: EPM governed by {{primary_state}} law
- **Truth in Lending Act (TILA) — Required Disclosures:**
  - Annual Percentage Rate (APR): {{apr}}%
  - Finance Charge: {{estimated_finance_charge}} over {{loan_term}} years
  - Amount Financed: {{loan_amount}}
  - Total of Payments: {{total_payments}}
  - Payment Schedule: {{payment_schedule}} (monthly {{monthly_payment}}, due {{payment_day}})
  - **Right to Prepay Without Penalty:** Can pay off early without penalty, interest savings apply
- **Dodd-Frank Act Protections:**
  - We cannot engage in UDAAP (unfair, deceptive, abusive practices)
  - Cannot charge disproportionate fees
  - Cannot apply inconsistent terms based on protected characteristics
  - You can dispute: CFPB complaint process
- **State-Specific Lending Regulations (varies by state):**
  - **Usury Laws (maximum interest rates):**
    - {{primary_state}}: Maximum {{usury_rate}}%
    - EPM structure may exempt certain limitations
    - Your APR {{apr}}% is compliant
  - **Balloon Payment Disclosure:**
    - Our EPM does NOT have balloon payments
    - Final payment = remaining balance when property is sold
  - **Right to Cure (Foreclosure Prevention):**
    - If payment misses: {{cure_period}} days to cure default
    - Cure = back payments + late fees
    - Notice requirement: {{notice_days}}-day notice before foreclosure
- **Fair Lending & Non-Discrimination:**
  - NO discrimination based on: race, color, religion, national origin (Fair Housing Act)
  - NO discrimination: sex, sexual orientation, gender identity (ECOA)
  - NO discrimination: age (62+), disability, marital status, public benefits, waiver refusal
  - **ECOA Compliance:** Credit decision based on creditworthiness, income, assets, property value
  - You can request denial reason: {{ecoa_request}}
  - **Fair Housing Act:** No steering, no discrimination by protected characteristics
- **Dispute Resolution & Complaints:**
  - Step 1: Contact servicer {{servicer_contact}}, 30-day response
  - Step 2: External resolution:
    - CFPB: www.consumerfinance.gov/complaint, 1-855-411-2372 (CFPB), mail: CFPB Complaint Center, DC
    - State Attorney General
    - Better Business Bureau
  - **Arbitration Clause (if applicable):**
    - Disputes resolved through binding arbitration
    - Administered by {{arbitration_admin}} (American Arbitration Association)
    - Location: {{arbitration_location}}
    - Costs: we pay arbitrator; you pay your attorney (if applicable)
- **State-Specific Property Rights Protections:**
  - **Homestead Exemption ({{primary_state}} specific):**
    - Your primary residence protected under homestead law
    - {{homestead_exemption_amount}} equity protected from creditors
    - Our mortgage lien takes priority
  - **Redemption Rights (if applicable):**
    - After foreclosure: {{redemption_period}} to redeem property
    - Redeem = pay sale price + costs to regain property
  - **Deficiency Judgment Protection ({{primary_state}} specific):**
    - If property sells for less than balance: you may owe deficiency
    - {{primary_state}} law: {{deficiency_rule}}
- **Insurance Requirements:**
  - **Homeowners Insurance (mandatory):**
    - Must maintain insurance for at least {{coverage_amount}}
    - Lender named as loss payee
    - Annual proof required
  - **Mortgage Protection Insurance (if applicable):**
    - {{mpi_type}} to protect against default
    - Cost: {{mpi_cost}}% p.a. of loan balance
- **Escrow/Impound Account ({{primary_state}} specific):**
  - Purpose: collect for taxes ({{estimated_annual_tax}}/year), insurance ({{estimated_annual_insurance}}/year)
  - Management: we pay taxes & insurance from escrow when due
  - Annual escrow analysis statement
  - Adjustment: if short, we may increase monthly payment
- **Applicable Law & Jurisdiction:**
  - Governed by {{primary_state}} law
  - Jurisdiction: courts of {{county}}, {{primary_state}}
  - Venue: Federal District Court, {{district}}
- **Definitions:**
  - Loan: EPM mortgage on {{property_address}}
  - Principal: {{loan_amount}}
  - Maturity: when loan is fully paid (property sale or passing)
  - Default: payment {{payment_days}} days overdue

---

## New Zealand (Privacy Act 2020 + Māori Data Sovereignty) — 1 Template

### Privacy Policy - New Zealand
**Target: 2500-3000 words**

Key sections:
- Introduction: Futureproof acknowledges Privacy Act 2020, Treaty of Waitangi principles
- **Privacy Act 2020: 10 Privacy Principles (detailed, section-by-section):**
  1. **Collection Limited:** Collect only necessary information, lawfully/fairly, disclose purpose
  2. **Use, Disclosure Limited:** Use for primary purpose, no disclosure without consent (exceptions: law permits)
  3. **Data Quality:** Keep accurate, up-to-date, complete; verify at collection; allow correction
  4. **Data Accuracy:** Take steps to ensure accuracy; correct or note dispute; allow disagreement statement
  5. **Storage, Security & Retention:** Protect against loss/misuse/unauthorized access; encrypt; limit staff access; destroy when no longer needed; secure physical disposal
  6. **Openness:** Transparent about practices; provide this policy; explain how to access; explain complaints
  7. **Individual Access:** Can access personal information (free, usually); respond within {{access_response_days}} working days; provide understandable form; exception: prejudice someone else's rights
  8. **Correction:** Can request correction; we correct if inaccurate; if disagree, allow disagreement statement; respond within {{correction_response_days}} days
  9. **Unique Identifiers:** Don't create/assign unless necessary; don't match across systems; exception: IRD numbers for tax
  10. **Retention:** Don't keep longer than necessary; schedule: loan documents 7 years post-repayment, communications 3 years, marketing until consent withdrawn

- **Overseas Disclosure (Critical for NZ):**
  - **Australian Partners:** Share with lenders & investment partners
    - No Privacy Act equivalent, but same regulatory environment
    - Safeguard: Contracts require similar data protection
    - Remedy: If Australian partner breaches, claim against us
  - **US Service Providers:** Cloud services (AWS, Azure)
    - Section 702 surveillance risk (US government may access)
    - Safeguard: encryption, Standard Contractual Clauses, supplementary measures
    - Recourse: Contact Privacy Commissioner if concerned
  - **UK Partners:** Compliance consultants
    - UK GDPR provides similar protections
    - UK Data Protection Act 2018 governs processing

- **Kaitiakitanga (Guardianship) & Māori Data Sovereignty:**
  - **Commitment to Māori Data:**
    - Recognize Māori data rights under Privacy Act 2020
    - Respect manaakitanga (hospitality), whanaungatanga (relationships), aroha ki a te tangata (respect)
  - **Whakapapa (Genealogical Data):**
    - Whakapapa is sacred; requires special protection
    - If provided: treat as sensitive
    - Won't disclose without explicit consent
    - You can designate as sensitive/restricted
  - **Consultation with Iwi:**
    - If practices affect Māori communities: consult with local iwi
    - Seek input on major data initiatives
    - Contact: {{iwi_consultation_contact}}
  - **Treaty of Waitangi Principles:**
    - Partnership: Partner with Māori in data governance
    - Participation: Māori have voice in decisions
    - Protection: Protect Māori interests & cultural values

- **NZ Privacy Commissioner:**
  - **Complaint Process:**
    - If breach suspected: complain to Privacy Commissioner
    - Office: https://www.privacy.org.nz/
    - Phone: {{nz_privacy_commissioner_phone}}
    - Mail: Privacy Commissioner, PO Box 10-094, Wellington 6143, NZ
  - **Investigation:**
    - Commissioner investigates
    - If breach: can order remedies (compensation, apologies)
    - Timeline: typically 12-18 months
  - **Your Rights:**
    - Free complaint process
    - No lawyer required
    - Compensation up to NZD {{compensation_limit}}

- **Information Requests (Statutory Right):**
  - **Under Privacy Act 2020, Section 12:**
    - Can request personal information (free, usually)
    - Timeline: {{request_response_days}} working days (20 standard)
    - How: {{info_request_method}} (email, form, in person)
    - Included: all personal information held
    - Exempt: legal privilege, confidentiality prejudicing someone
  - **Appeal:**
    - If refused/delayed: appeal to Privacy Commissioner
    - Commissioner will review & decide

- **Contact & Complaints:**
  - Privacy inquiries: {{nz_privacy_contact_email}}
  - Complaints: {{nz_complaints_contact}}

---

## United Kingdom (UK GDPR + DPA 2018 + ICO) — 1 Template

### Privacy Policy - United Kingdom
**Target: 4000-5000 words**

Key sections:
- **Introduction & Data Controller:**
  - Data Controller: Futureproof Financial Group Limited
  - ICO Registration: {{ico_registration_number}}
  - Address: {{uk_address}}
  - DPO: {{dpo_name}}, {{dpo_email}}

- **Legal Basis for Processing (UK GDPR Article 6):**
  - **Legitimate Interests (Article 6(1)(f)):** Loan assessment, fraud prevention, service improvement, security
    - Balanced against your privacy rights (we balance to protect you)
  - **Contract (Article 6(1)(b)):** Fulfilling mortgage agreement, loan statements
  - **Legal Obligation (Article 6(1)(c)):** AML/CTF, financial regulations, tax law
  - **Consent (Article 6(1)(a)):** Marketing (opt-in), cookies/tracking (first time only)

- **UK GDPR Articles — Your Rights (Articles 12-22):**
  - **Right of Access (Article 15) — Subject Access Request (SAR):**
    - Request: "Give me all my personal information"
    - Timeline: 30 calendar days (extend 60 for complex)
    - Fee: usually free; can charge reasonable fee if manifestly unfounded
    - How to request: {{sar_method}} (in writing to {{dpo_email}})
    - Receive: all information, in portable format (PDF, CSV)
    - Exemptions: legal privilege, confidentiality, criminal investigation
  - **Right to Rectification (Article 16):**
    - Request correction of wrong/incomplete information
    - We correct within 30 days (or explain why not)
    - We notify third parties we disclosed to (if practicable)
  - **Right to Erasure (Article 17) — "Right to be Forgotten":**
    - Request deletion if: no longer needed, consent withdrawn, object to processing (no overriding interest)
    - We don't have to delete if: law requires, contract (need for loan), legal claim (evidence)
    - Timeline: 30 days
  - **Right to Restrict Processing (Article 18):**
    - Request we limit how we use your data: storage only, while verifying accuracy, assessing legality
    - During restriction: no active processing except with consent or legal claims
  - **Right to Data Portability (Article 20):**
    - Request data in portable format (CSV, JSON, XML)
    - For data you provided or consented to/contractual processing
    - Timeline: 30 days; format: machine-readable, structured, commonly used
  - **Right to Object (Article 21):**
    - Object to processing based on legitimate interests
    - Exception: object to direct marketing (absolute right, GDPR 21(3))
    - We stop processing unless overriding legal interest
    - Example: you can object to marketing emails (we stop immediately)
  - **Rights Related to Automated Decision-Making (Article 22):**
    - Right not to be subject to automated decisions
    - Exception: decisions necessary for contract or consented to
    - Our practice: no fully automated lending decisions; humans review

- **Data Protection Act 2018 (UK-Specific):**
  - UK GDPR adapted with UK-specific rules (post-Brexit):
    - Employment data (special rules for employer/employee)
    - Law enforcement data (assisting police/regulators)
    - National security (exemptions apply)
  - Our commitments: comply with UK DPA 2018, respect all exemptions

- **Special Categories (Article 9) — Sensitive Data:**
  - May process: health data (hardship assessment), racial/ethnic origin (diversity monitoring, optional, consent), biometric data (identity verification)
  - Protection: strict access controls, extra encryption, limited retention, explicit consent (where required)

- **ICO (Information Commissioner's Office) — Enforcement:**
  - **Authority:**
    - Independent data protection regulator for UK
    - Fines: up to €20 million or 4% annual global turnover (whichever higher)
    - Most serious breaches (unlawful, inadequate security): top tier fines
  - **Our ICO Registration:**
    - Registered: {{ico_registration_number}}
    - Verify: https://ico.org.uk/
  - **Supervision:**
    - ICO monitors our practices
    - Can investigate complaints & audits
  - **Your Recourse:**
    - If breach suspected: complain to ICO
    - ICO, Wycliffe House, Water Lane, Wilmslow, Cheshire SK9 5AF, UK
    - Phone: {{ico_phone}}
    - Online: https://ico.org.uk/global/contact-us/
    - Email: {{ico_email}}
  - **Compensation:**
    - ICO can award compensation for material/non-material damages
    - You can sue us directly for damages (Article 82)

- **Subject Access Request (SAR) Process — Detailed:**
  - **How to Request:**
    - Email: {{dpo_email}} with subject "Subject Access Request"
    - Letter: Data Protection Officer, {{uk_address}}
    - Form: {{sar_form_link}} (optional)
  - **What to Include:**
    - Your name & email
    - Description of information requested (or "all information")
    - Proof of identity (ID copy, recent bill, passport)
  - **Our Response:**
    - Acknowledgment: 5 working days
    - Full response: 30 days
    - Extension: if complex, may extend 60 more days (with notice)
  - **What You'll Receive:**
    - All personal information we hold
    - Purpose we're using it for
    - Recipients we've disclosed to
    - Retention period
    - Your rights (rectification, erasure, etc.)
  - **Fees:**
    - First SAR per 12 months: free
    - Additional SARs: may charge reasonable administrative fee (£10-20)
    - Manifestly unfounded requests: may refuse/charge £50

- **Data Retention Schedule (Detailed Table):**
  | Data Type | Purpose | Retention Period | Legal Basis |
  | Loan Application | Underwriting, contract | 6 years post-completion | GDPR Art 6(1)(b) contract |
  | Credit Report | Underwriting | 3 years | GDPR Art 6(1)(f) legitimate interest |
  | Customer Communication | Dispute resolution, evidence | 3 years post-resolution | GDPR Art 6(1)(c) legal obligation |
  | Payment Records | Account management | Loan term + 6 years | GDPR Art 6(1)(c) tax law |
  | Identity Documents (KYC) | AML/CTF compliance | 5 years post-completion | GDPR Art 6(1)(c) AML/CTF Regulation |
  | Marketing Data | Direct marketing | Until consent withdrawn | GDPR Art 6(1)(a) consent |
  | Website Analytics | Improving service | 13 months | GDPR Art 6(1)(f) legitimate interest |
  | CCTV (if applicable) | Security, fraud prevention | 30 days | GDPR Art 6(1)(f) legitimate interest |

- **Legitimate Interest Assessment (LIA) Summary:**
  - **What is Legitimate Interest?**
    - Processing necessary for our lawful business interests
    - Example: fraud prevention, underwriting, customer service
    - Balanced against your privacy rights
  - **Our LIA Process:**
    - Identify processing purpose
    - Assess necessity
    - Balance our interests vs. your rights
    - Document assessment
  - **Examples of Our Legitimate Interests:**
    1. Fraud Prevention: detect/prevent fraud (mutual security interest)
    2. Underwriting: need financial data to assess credit risk (mutual interest in responsible lending)
    3. Customer Service: process contact data to respond (mutual service interest)
    4. Marketing: relevant financial offers (balanced against privacy)

- **International Data Transfers — Standard Contractual Clauses:**
  - **Where We Transfer:**
    - **Australia:** Lenders & investment partners
      - No UK adequacy decision (as of 2026)
      - Use Standard Contractual Clauses (SCCs) (Article 46(2)(c))
      - Supplementary: encryption, access controls
    - **United States:** Cloud services (AWS, Azure)
      - Lacks adequate privacy protections (CJEU Schrems II)
      - Use Standard Contractual Clauses (SCCs)
      - Supplementary: encryption, Sub-processor agreements, US law review
      - You can object: we'll discuss alternatives
    - **EU:** European partners (post-Brexit, EU is third country)
      - EU GDPR deemed adequacy equivalent to UK GDPR
      - Transfers permitted (Article 45)
  - **Your Rights:**
    - Schrems II: if transfer involves surveillance risk, can object
    - We assess each transfer for surveillance/access risk
    - Minimize unnecessary transfers
    - Contact: {{dpo_email}} if concerned

- **Cookies & Tracking (UK GDPR + PECR):**
  - **Cookies on Website:**
    - Essential (login, security): always enabled, no consent
    - Analytics (Google): opt-in, we ask
    - Marketing (retargeting): opt-in, we ask
  - **Your Choices:**
    - First visit: cookie banner asks
    - Change: {{cookie_preferences_link}}
    - Disable: browser settings

- **Data Protection Officer & Contact:**
  - **Our DPO:**
    - Name: {{dpo_name}}
    - Email: {{dpo_email}}
    - Phone: {{dpo_phone}}
    - Role: GDPR compliance, SARs, complaints
  - **For Privacy Inquiries:**
    - Contact: {{privacy_contact_email}}
    - Response: 5 working days
  - **For Complaints (us first):**
    - Email: {{complaints_email}}
    - Process: acknowledged 5 days, responded 30 days
  - **Complaint to ICO:**
    - ICO contact: {{ico_contact_details}}

---

## Implementation Instructions

1. **Open file:** `/Users/zen/projects/futureproof/futureproof/db/seeds/legal_document_templates.rb`

2. **For each template above:**
   - Find the corresponding section in the seed file (templates are in order)
   - Replace the template_content with the enhanced version
   - Keep all {{variables}} in place
   - Maintain markdown formatting
   - Ensure no syntax errors

3. **Test:**
   ```bash
   cd /Users/zen/projects/futureproof/futureproof
   source ~/.rvm/scripts/rvm
   bin/rails runner "require './db/seeds/legal_document_templates.rb'"
   ```

4. **Verify in Rails console:**
   ```ruby
   LegalDocumentTemplate.count  # Should be 7
   LegalDocumentTemplate.first.available_variables  # Should list {{variables}}
   ```

5. **Commit:**
   ```bash
   git add db/seeds/legal_document_templates.rb
   git commit -m "refactor: Enhanced legal document templates with jurisdiction-specific regulatory compliance

   - Australia (ASIC/NCCP/Credit Reporting): Privacy Policy, Terms & Conditions, Lender Agreement
   - United States (CCPA/TILA/Dodd-Frank): Privacy Policy, Terms & Conditions  
   - New Zealand (Privacy Act 2020 + Māori Data Sovereignty): Privacy Policy
   - United Kingdom (UK GDPR/DPA 2018/ICO): Privacy Policy
   
   All templates include detailed regulatory compliance, customer rights, and jurisdiction-specific protections.
   Ready for production deployment."
   ```

---

## Success Criteria ✅

- [ ] All 3 AU templates enhanced (ASIC/NCCP compliance)
- [ ] All 2 US templates enhanced (CCPA/TILA compliance)
- [ ] NZ template enhanced (Privacy Act 2020 + Māori sovereignty)
- [ ] UK template enhanced (UK GDPR + ICO)
- [ ] All {{variables}} preserved
- [ ] Markdown clean and readable
- [ ] Seed file runs without errors
- [ ] Templates load in admin dashboard
- [ ] Single commit with clear message

---

## Time Estimate

- Writing all 7 enhanced templates: 2-3 hours
- Testing & verification: 30 minutes
- Total: 2.5-3.5 hours

---

## Next Session

This is the **final step** before production deployment. Once templates are enhanced:

1. Run migrations & seeds
2. Load admin dashboard
3. Create test documents from templates
4. Verify all 4 jurisdictions show compliance
5. Deploy to staging/production

**Platform will be 100% production-ready after this.**
