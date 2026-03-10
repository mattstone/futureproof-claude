# Legal Document Templates - All Jurisdictions
# Run with: rails runner "require './db/seeds/legal_document_templates.rb'"

puts "Creating legal document templates for all jurisdictions..."

# Privacy Policy - Australia
privacy_policy_au = <<~CONTENT
## 1. Introduction & Regulatory Compliance

Futureproof Financial Group Limited (ABN: {{abn}}) ("we," "our," or "us") is committed to protecting your privacy and complying with all applicable Australian privacy laws. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you visit our website or use our services, including our Equity Preservation Mortgage® products.

We comply with:
- **Privacy Act 1988 (Cth)** — Australian Privacy Principles (APPs 1-13)
- **Privacy (Australian Government Personnel) Act 1988** — where applicable
- **Notifiable Data Breaches scheme** — Australian Cyber Security Incident Response Plan
- **Australian Securities and Investments Commission (ASIC)** — financial services privacy requirements
- **AML/CTF Act** — customer identification and record-keeping
- **Credit Reporting & Responsible Lending Code** — Privacy Act Section 21F

## 2. Information We Collect

We may collect the following types of personal information:

**Directly from you:**
- Contact information (name, email address, phone number, mailing address)
- Property information (address, estimated value, title, legal description)
- Financial information (income, assets, liabilities, employment)
- Identity verification documents (driver's license, passport, birth certificate, tax file number)
- Credit information (with your explicit consent)
- Communication records and preferences
- Health information (if relevant to hardship assessment)
- Sensitive information (where necessary for compliance)

**Automatically collected:**
- Website usage analytics (pages visited, duration, browser type)
- IP addresses and device identifiers
- Cookies and tracking technologies

**From third parties:**
- Credit reporting agencies (credit history, default information)
- Identity verification services
- Insurance companies
- Mortgage brokers and advisors

## 3. Credit Reporting Disclosure (Privacy Act Section 21F)

We may collect credit information about you from credit reporting agencies. Under Privacy Act Section 21F, you have the right to:

**What we collect:**
- Credit history and credit rating
- Default information (overdue payments, court judgments)
- Credit inquiries
- Credit limits and account balances

**Who we share it with:**
- Credit reporting agencies (Equifax, Experian, Illion)
- Lenders and investment partners
- Insurers and risk assessors

**Your rights:**
- Know what credit information we hold about you
- Correct inaccurate credit information
- Dispute credit information with the credit bureau
- Lodge a complaint if credit reporting is inaccurate

**Credit bureau contacts:**
- Equifax: www.equifax.com.au, 1800 300 630
- Experian: www.experian.com.au, 1800 331 922
- Illion: www.illion.com.au, 1300 734 806

**Our reporting:** We may report your repayment history and defaults to credit reporting agencies.

## 4. How We Use Your Information

We use your information for:
- Processing and evaluating mortgage applications
- Conducting credit assessments and risk analysis
- Providing customer service and support
- Managing your account and payments
- Conducting hardship assessments and modifications
- Complying with ASIC regulations and responsible lending obligations
- Complying with AML/CTF Act requirements
- Fraud detection and prevention
- Complying with legal and regulatory requirements
- Improving our website and services
- Marketing and promotional activities (with your consent only)

## 5. Information Sharing & Overseas Disclosure

We may share your information with:

**Within Australia:**
- **ASIC & Regulators:** ASIC, ABA, and other relevant authorities (regulatory compliance)
- **Credit Reporting Agencies:** For credit checks and payment reporting
- **Service Providers:** Valuers, lawyers, accountants, auditors
- **Wholesale Funders & Lenders:** Approved funding partners and investment partners
- **Insurance Providers:** For mortgage protection insurance
- **Government Authorities:** ATO, Family Court, when legally required

**Overseas disclosure:**
We may disclose personal information to parties located outside Australia:
- **Australian Financial Services Licensees** in overseas jurisdictions (comparable privacy)
- **Subsidiary/affiliate entities** in regulated financial jurisdictions
- **Cloud service providers** in the US/EU (with Standard Contractual Clauses)

These overseas parties may not have privacy protections equivalent to Australian law. If you're concerned about overseas disclosure, please contact us.

## 6. Data Security & Breach Notification

We implement appropriate technical and organizational measures to protect your personal information:
- Encryption (data in transit: TLS 1.2+; at rest: AES-256)
- Access controls (role-based, least privilege)
- Staff training (annual privacy/security training)
- Secure disposal (secure deletion or physical destruction)
- Monitoring (intrusion detection, vulnerability scanning)

**Notifiable Data Breaches Scheme:**
If a data breach is likely to result in serious harm, we will notify you and the Privacy Commissioner without unreasonable delay (typically within 30 days).

## 7. Your Rights Under the Privacy Act

You have the right to:

**Access (APP 12.1):**
- Request access to your personal information
- We'll respond within 30 days (may extend to 60 days for complex requests)
- Usually free; may charge reasonable fee if request is manifestly unreasonable
- Format: provided in understandable form, typically email or printed letter

**Correction (APP 13):**
- Request correction of inaccurate or incomplete information
- We'll correct within 30 days (or explain why not)
- We'll notify third parties if corrections are significant

**Complaint & OAIC escalation (APP 1.2):**
- **Step 1:** Lodge complaint with us: {{complaint_email}}, phone {{complaint_phone}}
  - We'll acknowledge within 5 business days
  - We'll investigate and respond within 30 days
- **Step 2:** If unsatisfied, escalate to Privacy Commissioner
  - **Office of the Australian Information Commissioner (OAIC)**
  - Phone: 1300 363 992
  - Email: enquiries@oaic.gov.au
  - Website: www.oaic.gov.au
  - The OAIC can investigate and award compensation up to {{oaic_compensation_limit}}

**Opt-out:**
- You can opt-out of marketing communications at any time
- Response: within 10 business days
- No penalty for opting out

## 8. Sensitive Information

We handle sensitive information (health, genetic, biometric) with extra protection:
- Only collected with your explicit consent
- Stored separately with enhanced encryption
- Accessible only to authorized personnel
- Retained only as long as necessary

## 9. Direct Marketing & Cookies

**Marketing communications:**
- We'll send marketing only with your prior consent
- Each email includes unsubscribe option
- You can request removal from all lists at any time

**Cookies on our website:**
- Essential cookies (login, security): always enabled
- Analytics cookies: opt-in via cookie banner
- Marketing cookies: opt-in via cookie banner
- You can disable cookies in browser settings

## 10. Contact Us

**Privacy Officer:**
Futureproof Financial Group Limited
Email: {{privacy_contact_email}}
Address: {{contact_address}}
Phone: {{privacy_phone}}

**Privacy Commissioner:**
Office of the Australian Information Commissioner (OAIC)
Phone: 1300 363 992
Email: enquiries@oaic.gov.au
Website: www.oaic.gov.au
CONTENT

# Terms & Conditions - Australia
terms_au = <<~CONTENT
## 1. Agreement & Regulatory Compliance

These Terms and Conditions ("Terms") govern your use of Equity Preservation Mortgage® (EPM) services provided by Futureproof Financial Group Limited (ABN: {{abn}}) ("we," "our," "us," or "Company").

**Important:** By accepting these Terms, you acknowledge that:
- You understand the EPM product structure
- You have read our Product Disclosure Statement (PDS)
- You are satisfied this product is suitable for your circumstances
- You have received appropriate financial advice

These Terms are regulated by:
- Australian Securities and Investments Commission (ASIC)
- ASIC's Regulatory Guide 209 (credit licensing and responsible lending)
- National Credit Code (Part IV.2B of the Competition and Consumer Act)

## 2. Equity Preservation Mortgage (EPM®) — Plain Language Explanation

The EPM is not a traditional mortgage. Here's how it works:

**What you do:**
- You own your property (we don't take ownership)
- You take out a mortgage against your property
- The mortgage funds are invested in a portfolio

**What you receive:**
- Monthly guaranteed income payments (typically {{income_percentage}}% p.a. of property value)
- These income payments are NOT loan repayments — they're investment returns
- Income is deposited to your nominated account each month

**What you don't do:**
- You make NO monthly repayments to us
- You don't owe interest
- You don't need to service the debt

**When the loan ends:**
- The mortgage is repaid when your property is sold
- The mortgage is repaid when you pass away (from estate proceeds)
- No debt passes to your heirs
- If property sale proceeds exceed mortgage: excess is yours

**Your equity protection:**
- We guarantee you'll never owe more than your property is worth (NNEG)
- Even if property value drops, you're protected
- If the mortgage balance exceeds property value at sale, we cover the shortfall

## 3. No Negative Equity Guarantee (NNEG) — Detailed

**What NNEG protects:**
NNEG is a guarantee that your debt will never exceed your property value.

**When it applies:**
- On property sale, if property value < mortgage balance: NNEG covers the difference
- Example: property worth $500,000, mortgage balance $550,000 → NNEG covers $50,000

**When it doesn't apply:**
- Fraud by the customer (providing false information)
- Breach of mortgage conditions (e.g., major damage to property due to negligence)
- If customer's actions materially reduce property value

**How it's funded:**
- Lender insurance (typically {{lender_insurance_premium}}% p.a.)
- This cost is reflected in your mortgage terms

**Your rights if NNEG is triggered:**
- You have no debt obligation for the shortfall
- NNEG insurance pays the difference
- Your credit record is not affected (no default)
- Your estate is not liable

**Limits and exclusions:**
- NNEG applies only to the primary residence
- Excludes fraud, major breach, or willful damage
- See PDS for full exclusions

## 4. Cooling Off Period (ASIC Requirement)

**Your right:**
You have **14 days from the mortgage settlement date** to cancel without penalty or fee.

**How to cancel:**
- Send written notice to: {{contact_address}}
- Email: {{contact_email}}
- Include: your name, property address, mortgage account number

**What happens:**
- Mortgage is cancelled
- Establishment fees refunded within {{refund_days}} days
- Investment proceeds returned (less any investment losses in those 14 days)
- You continue to own your property free of any mortgage

**This right is guaranteed under ASIC regulations and cannot be waived.**

## 5. NCCP Act Obligations (National Credit Code)

We are committed to responsible lending under the National Credit Code.

**Suitability assessment:**
- We assess whether the EPM is suitable for your circumstances
- We verify your income and financial situation
- We consider your ability to maintain required insurance
- We provide written assessment before you apply

**Regular review:**
- We review your loan annually
- If circumstances change significantly, we contact you
- We remain committed to responsible lending

**Hardship assistance (Section 72):**
If you experience financial hardship:
- Contact: {{hardship_contact_email}} or {{hardship_phone}}
- We'll work with you to modify the loan
- Options: extend term, reduce income payments, pause distributions
- Response: within 21 days
- This is your legal right under the National Credit Code

## 6. Complaint Handling (ASIC-Compliant, Multi-Step)

**Step 1: Internal Complaint**
- Email: {{complaint_email}}
- Or mail: {{complaint_mailing_address}}
- We'll acknowledge within 5 business days
- We'll investigate and respond with a decision within 30 days
- If we can't resolve within 30 days, we'll explain timeline and keep you updated

**Step 2: Financial Ombudsman Service (FOS)**
If unsatisfied with our response, you can escalate to FOS:
- **FOS covers:** Disputes up to {{fos_claim_limit}}
- **Process:** FOS investigates independently (30-180 days)
- **Decision:** Binding on us; you can accept or reject
- **Compensation:** Up to {{fos_compensation_limit}}
- **Contact:**
  - Phone: 1800 367 287
  - Email: info@fos.org.au
  - Website: www.fos.org.au
  - Mail: Financial Ombudsman Service, GPO Box 3, Melbourne VIC 3001

**Step 3: ASIC Escalation**
If not satisfied with FOS decision:
- Contact ASIC: 1300 300 630
- Website: www.asic.gov.au
- ASIC can investigate serious breaches of financial services law

## 7. Fees & Charges

**Upfront:**
- Establishment fee: {{establishment_fee}}
- Valuation fee: {{valuation_fee}}
- Legal fees: {{legal_fees}}
- Insurance (NNEG): {{nneg_insurance_cost}} p.a.

**Ongoing:**
- Annual administration fee: {{annual_fee}}
- Annual insurance premium: {{annual_insurance}}
- Lender margin: {{lender_margin}}% of mortgage balance p.a.

**One-time:**
- Early discharge (if applicable): {{discharge_fee}}
- Document request fee: {{document_fee}}

All fees will be disclosed in your loan contract before you commit.

## 8. Interest Rates & Returns

**Your income rate:**
- Guaranteed minimum: {{guaranteed_minimum_return}}% p.a. of property value
- Based on: investment portfolio performance
- Variability: rate may vary quarterly based on market conditions

**Rate adjustments:**
- We notify you in advance of any changes (30-day notice)
- Changes apply only to future payments (past payments unchanged)
- You can request to review the loan if you believe terms are unfavorable

## 9. Applicable Law & Jurisdiction

**Governing law:**
These Terms are governed by:
- Laws of {{governing_state}} (typically Queensland)
- Laws of the Commonwealth of Australia (ASIC, Credit Code)

**Dispute resolution:**
- Disputes resolved in courts of {{governing_state}}
- District court jurisdiction: disputes < ${{district_court_limit}}
- Supreme court jurisdiction: disputes >= ${{district_court_limit}}

## 10. Definitions

- **Property:** Your residential property located at {{property_address}}
- **Mortgage:** The registered mortgage against the Property
- **Loan Amount:** The amount borrowed, being {{loan_amount}}
- **Term:** The period from settlement until repayment ({{loan_term}} years or upon sale/passing)
- **Income Payment:** Monthly guaranteed income transfer to your nominated account
- **NNEG:** No Negative Equity Guarantee (you won't owe more than property value)
- **PDS:** Product Disclosure Statement (detailed document about risks & features)
- **ASIC:** Australian Securities and Investments Commission (financial regulator)

## 11. Key Disclaimers

**Investment risk:** The mortgage proceeds are invested. Investment returns vary and are not guaranteed. Past performance does not indicate future results.

**Property valuation:** Property values change. The NNEG covers decreases, but valuations may fluctuate.

**This is not financial advice:** These Terms explain the product. They do not constitute personal financial advice. Before proceeding, seek advice from:
- Your financial advisor
- Your accountant or tax advisor
- An independent legal advisor

**Product risk:** EPM products carry investment risk, property risk, and interest rate risk. Review the PDS for full risk disclosure.

**Regulatory changes:** Laws change. If legislation materially changes our obligations, we'll notify you and discuss options.

## 12. Contact Us

**For general inquiries:**
Phone: {{phone}}
Email: {{contact_email}}
Website: {{website}}

**For complaints:**
Email: {{complaint_email}}
Phone: {{complaint_phone}}

**For hardship:**
Email: {{hardship_contact_email}}
Phone: {{hardship_phone}}

**Registered office:**
Futureproof Financial Group Limited
ABN: {{abn}}
Address: {{registered_office_address}}
CONTENT

# Lender Agreement - Australia
lender_agreement_au = <<~CONTENT
## 1. Agreement Between Parties & Overview

This Lender Agreement ("Agreement") is entered into effective {{effective_date}} between:

**Futureproof Financial Group Limited**
- ABN: {{abn}}
- ACN: {{company_acn}}
- Australian Financial Services Licensee (AFSL: {{afsl_number}})
- Registered office: {{registered_office_address}}
- ("Company" or "We")

**{{lender_name}}**
- Legal entity/individual: {{lender_legal_entity}}
- ACN/ABN: {{lender_acn}}
- Address: {{lender_address}}
- ("Lender" or "You")

**Purpose:** This Agreement governs the Lender's participation in the Equity Preservation Mortgage (EPM) program and investment in the mortgage pool.

## 2. Responsible Lending Obligations (ASIC RG 209)

We are committed to responsible lending under ASIC Regulatory Guide 209.

**Suitability assessment:**
- Each application undergoes affordability assessment
- We verify customer income, assets, liabilities
- We ensure EPM is suitable for the borrower's circumstances
- We document all assessments in customer file
- Assessment provided to customer before they commit

**Information verification:**
- All customer financial information verified
- Employment verified independently
- Credit reports obtained (with customer consent)
- Property valuation conducted by independent valuer

**Affordability assessment:**
- We assess customer's ability to maintain:
  - Property insurance (mandatory)
  - Rates and taxes
  - General maintenance
- We model various interest rate scenarios
- We confirm customer understands no monthly repayments required

**Customer disclosure:**
- Customer receives PDS at least 2 days before settlement
- Customer receives written assessment confirmation
- Customer receives all relevant risk disclosures
- Customer provided opportunity to ask questions

**Annual review:**
- We review each loan annually (minimum)
- We contact customer if circumstances change materially
- We reassess suitability if loan becomes unsuitable
- We maintain review documentation for audit

**Hardship assistance:**
- Customers in hardship can request modification (National Credit Code Section 72)
- We respond within 21 days
- Options: extend term, reduce income payments, pause distributions
- We work collaboratively to find workable solutions

## 3. Capital Adequacy Standards

The Lender agrees to maintain the following capital adequacy:

**Capital ratio:**
- Maintain capital ratio of at least {{capital_ratio}}% of total mortgage pool
- Capital ratio = liquid assets / total mortgage commitments

**Reserve requirements:**
- Maintain {{reserve_percentage}}% of mortgage pool in liquid, readily accessible reserves
- Reserves invested conservatively (term deposits, government securities, cash)
- Purpose: cover unexpected redemptions or shortfalls

**Liquidity management:**
- Lender commits to quarterly liquidity reviews
- We work together to model cash flow scenarios
- If liquidity becomes stressed, we discuss contingency plans

**Capital calls:**
- If capital falls below required level, Lender may be required to inject additional capital
- 30-day notice given to Lender
- Contribution amount calculated proportionally

## 4. Retail Investor Protections

All borrowers in the EPM program are treated as retail clients under ASIC rules.

**Enhanced disclosure requirements:**
- Borrowers receive detailed PDS (minimum 2 days before commitment)
- All fees, charges, and risks clearly disclosed
- NNEG terms and conditions explained in plain language
- Examples provided (e.g., property drops 20%, NNEG covers difference)

**Financial advice rights:**
- Borrowers have right to seek independent financial advice
- We provide contact information for financial advisors
- Borrowers encouraged to speak with accountants and tax advisors

**Complaints handling:**
- Borrowers can complain to us (Step 1)
- Can escalate to Financial Ombudsman Service (Step 2)
- Can escalate to ASIC (Step 3)
- We actively track and resolve complaints

## 5. Reporting Obligations

The Lender shall receive timely and accurate reporting:

**Monthly reporting:**
- Portfolio summary (total mortgages, total balance, weighted LTV)
- Distribution statement (amount paid to Lender, date, transaction ID)
- Property valuations (average LTV, range, outliers)
- Performance metrics (default rate, early redemptions, new originations)
- Provided by: {{monthly_reporting_date}} each month

**Quarterly reporting:**
- Detailed portfolio review (loan count, performance metrics)
- Risk assessment (concentrations, defaults, NNEG exposures)
- Market conditions summary (interest rates, property values, economic outlook)
- Strategic initiatives and major changes
- Provided by: {{quarterly_reporting_date}} each quarter

**Annual reporting:**
- Compliance certification:
  - Confirmation all borrowers assessed for suitability
  - Confirmation all responsible lending obligations met
  - Confirmation all required documentation maintained
- Auditor sign-off: independent audit of compliance
- Financial summary: total portfolio, distributions, returns
- Provided by: {{annual_reporting_date}} each year

**Additional reporting:**
- Material events reported within 5 business days (defaults, NNEG triggers, major changes)
- Regulatory changes or warnings reported immediately
- Any external audit findings shared promptly

**Lender access:**
- Lender has right to audit Company records (once per year, at Lender's cost)
- Lender may engage auditor to verify reporting
- Company will provide reasonable access to systems and documentation

## 6. Insurance & Indemnity

**Lender insurance:**
- Lender is the beneficiary of {{insurance_percentage}}% coverage insurance
- Insurance covers: defaults, fraud, undisclosed liabilities, NNEG shortfalls
- Premium: {{insurance_premium}}% p.a. of total mortgage pool balance
- Deducted from distributions to Lender
- Company maintains insurance with A-rated insurer

**Company indemnity:**
- Company indemnifies Lender against:
  - Loss from fraud by Company or Company employees
  - Loss from Company breach of this Agreement
  - Loss from underfunding of mortgages
  - Regulatory fines affecting Lender
- Indemnity is uncapped for fraud or criminal conduct
- Indemnity capped at {{indemnity_cap}} for other breaches

**Fraud and unfunded loan recovery:**
- If fraud is discovered: Company reimburses Lender immediately
- If loan is underfunded: Company tops up shortfall within 10 business days
- If Company cannot fund: Lender may exit the program (with 90-day notice)

**Professional liability insurance:**
- Company maintains professional liability insurance (minimum {{pli_coverage}})
- Covers errors, omissions, and mismanagement
- Certificate of insurance provided annually

## 7. Conflict of Interest Disclosure

The Company discloses the following potential conflicts:

**Related party transactions:**
- {{related_party_disclosure}}

**Dual roles:**
- Company has dual role: manager of portfolio AND participant in returns
- Company manages this by: {{conflict_management_approach}}
- Lender has right to request conflict review or arbitration

**Preferential treatment:**
- Company does not provide preferential rates or terms to related parties
- All pricing consistent with market terms
- Pricing reviewed annually for fairness

## 8. Regulatory Acknowledgments

The Lender acknowledges that the Company:

**ASIC financial services:**
- Holds AFSL \#{{afsl_number}} (or equivalent)
- Complies with all ASIC regulatory guides
- Participates in Financial Ombudsman Service (FOS)

**National Credit Code compliance:**
- Licensed credit provider (or equivalent)
- Complies with National Credit Code Part IV.2B
- Handles hardship applications per Section 72

**Privacy Act compliance:**
- Maintains privacy in accordance with Privacy Act 1988 (Cth)
- APPs 1-13 applied to all customer information
- Lender consent obtained for information sharing

**AML/CTF Act:**
- Maintains AML/CTF compliance
- Customer identification verified per AML/CTF Act
- Suspicious transaction reporting to AUSTRAC

**Anti-bribery and corruption:**
- No payments or benefits outside this Agreement
- No inducements to regulators or government
- Full compliance with Foreign Corrupt Practices Act and equivalent

## 9. Governing Law & Dispute Resolution

**Applicable law:**
- This Agreement governed by laws of {{governing_state}} (typically Queensland)
- Commonwealth law applies to ASIC and credit code matters

**Jurisdiction:**
- Courts of {{governing_state}} have jurisdiction
- Disputes heard in District or Supreme Court depending on amount

**Dispute resolution process:**
- **Step 1:** Good faith negotiation (30 days)
- **Step 2:** Mediation (if negotiation fails)
  - Mediator mutually selected
  - Location: {{mediation_location}}
  - Cost: split equally
- **Step 3:** Arbitration or litigation (if mediation fails)
  - Arbitrator appointed per {{arbitration_rules}}
  - Binding decision within {{arbitration_timeline}} months

## 10. Confidentiality & Information Handling

Both parties agree to keep confidential:

**Proprietary information:**
- Lending criteria and underwriting models
- Pricing and margin strategies
- Customer information (per Privacy Act)
- Portfolio composition and performance data

**Permitted disclosures:**
- To respective advisors (legal, accounting, audit)
- To regulators (ASIC, credit regulator, AUSTRAC)
- To auditors and tax advisors
- In legal proceedings

**Confidentiality period:**
- During term of Agreement
- 5 years post-termination
- Indefinitely for trade secrets

**Data protection:**
- Lender data protected with same security as customer data
- Encryption, access controls, audit trails
- Secure destruction on termination

## 11. Term, Renewal & Termination

**Initial term:**
- Commences: {{effective_date}}
- Duration: {{initial_term_years}} years
- Auto-renews for {{renewal_term_years}} years unless either party gives {{notice_period}} notice

**Termination for convenience:**
- Either party may terminate with {{termination_notice_period}} written notice
- Existing mortgages remain in place
- Final distribution calculated and paid within 30 days
- Lender may continue receiving distributions until mortgages redeemed

**Termination for cause:**
- Company may terminate if Lender breaches and doesn't cure within 30 days
- Lender may terminate if Company materially breaches and doesn't cure within 60 days
- Material breach includes: ASIC license suspension, capital ratio falls below {{capital_ratio_min}}, fraud

**Wind-down process:**
- Company continues to manage existing mortgages
- Lender continues to receive distributions
- Final redemptions and final distributions paid as mortgages mature
- Process typically complete within {{wind_down_timeline}} years

## 12. Definitions

- **Affiliate:** Any entity controlling, controlled by, or under common control
- **Capital ratio:** Liquid assets / total mortgage commitments
- **Default:** Payment {{payment_default_days}} days overdue or material breach
- **Lender's proportionate share:** {{lender_percentage}}% of portfolio (or as adjusted)
- **NNEG:** No Negative Equity Guarantee (property value protection)
- **Portfolio:** All mortgages funded under this Agreement
- **PDS:** Product Disclosure Statement provided to borrowers

## 13. Amendment & Waiver

**Amendment:**
- Changes to key terms require written agreement from both parties
- Key terms: capital ratio, insurance, NNEG terms, reporting
- Minor clarifications may be amended unilaterally with 30-day notice

**Waiver:**
- No waiver of any provision unless in writing
- Waiver of one breach does not waive subsequent breaches
- Waiver by one party does not bind the other

## 14. Contact Details

**Company:**
- {{contact_name}}
- Email: {{contact_email}}
- Phone: {{contact_phone}}
- Address: {{registered_office_address}}

**Lender:**
- {{lender_contact_name}}
- Email: {{lender_contact_email}}
- Phone: {{lender_contact_phone}}
- Address: {{lender_address}}

---

**Signature Block (to be completed at execution)**
CONTENT

# Privacy Policy - US
privacy_policy_us = <<~CONTENT
## 1. Introduction & Regulatory Compliance Statement

Futureproof Financial Group, Inc. ("we," "us," "our," or "Company") is committed to protecting your privacy and complying with all applicable U.S. federal and state privacy laws. This Privacy Policy explains how we collect, use, share, and safeguard your personal information when you use our Equity Preservation Mortgage® (EPM) products and services.

**We comply with:**
- **Consumer Protection Laws:**
  - Gramm-Leach-Bliley Act (GLBA) and Privacy Rule (16 CFR Part 313)
  - Fair Credit Reporting Act (FCRA), 15 U.S.C. § 1681 et seq.
  - Equal Credit Opportunity Act (ECOA)
  - Fair Housing Act (FHA)
  - Truth in Lending Act (TILA)
  
- **California Specific:**
  - California Consumer Privacy Act (CCPA), Cal. Civ. Code § 1798.100 et seq.
  - California Privacy Rights Act (CPRA), effective January 1, 2023
  - California Online Privacy Protection Act (CalOPPA)
  - Shine the Light Law (CA Civil Code § 1798.83)

- **Other State Privacy Laws:**
  - Virginia Consumer Data Protection Act (VCDPA)
  - Colorado Privacy Act (CPA)
  - Connecticut Data Privacy Act (CTDPA)
  - And all applicable state laws in your jurisdiction

- **Children's Privacy:**
  - Children's Online Privacy Protection Act (COPPA), 15 U.S.C. § 6501 et seq.

- **Financial Services:**
  - Bank Secrecy Act (BSA) and AML/CTF regulations
  - Securities laws where applicable

## 2. Information We Collect

### A. Information You Provide Directly

**Identity & Contact Information:**
- Full legal name, date of birth, Social Security Number (SSN)
- Email address, phone number, mailing address
- Government-issued ID (driver's license, passport)
- Information for borrowers and co-borrowers

**Property Information:**
- Property address, legal description, title information
- Property type, age, square footage, number of bedrooms/bathrooms
- Property valuation and appraisal reports
- Property tax information
- Homeowners insurance information

**Financial Information:**
- Income (W-2s, tax returns, pay stubs, investment income)
- Employment history and employer information
- Assets (bank accounts, investments, retirement accounts)
- Liabilities (mortgages, loans, credit cards, alimony, child support)
- Credit history and credit scores
- Banking information (for deposits and payments)

**Health Information (if relevant):**
- Information provided for hardship assessment
- Medical conditions affecting ability to work or manage finances
- Disability status (only if voluntarily disclosed)

**Other Information:**
- Signed contracts and loan documents
- Communication records (emails, letters, phone notes)
- Marketing and communication preferences

### B. Information Automatically Collected

**Website & Online Activity:**
- IP address and device ID
- Browser type, operating system, pages visited
- Time and duration of visits
- Referral source (which website sent you to us)
- Search queries and click patterns
- Cookies and similar tracking technologies

**Location Information:**
- General location (city/state level from IP address)
- Precise location (only if you permit, e.g., mobile app)

**Device Information:**
- Mobile device identifiers
- Hardware and software attributes
- Mobile operating system

### C. Information from Third Parties

**Credit Reporting:**
- Credit reports from Equifax, Experian, TransUnion
- Credit scores, payment history, defaults, inquiries
- Public records (judgments, liens)

**Verification Services:**
- Identity verification (matching SSN to name, address)
- Employment verification (income confirmation)
- Address verification
- Fraud screening

**Real Estate & Valuation:**
- Property appraisals and valuations
- Mortgage history
- Property tax assessments
- Flood zone and hazard information

**Insurance Companies:**
- Homeowners insurance quotes and policies
- Insurance claims history

**Mortgage Brokers & Referral Partners:**
- Referral information and application data
- Co-applicant information

**Government Sources:**
- Public records searches (criminal, civil, property)
- Regulatory databases

**Other Financial Institutions:**
- Bank account information (with authorization)
- Investment account data

## 3. How We Use Your Personal Information

We use the information we collect for:

**Loan Processing & Underwriting:**
- Evaluating your EPM application
- Assessing creditworthiness and financial capability
- Conducting background checks and credit reviews
- Verifying employment and income
- Conducting property appraisal and title search
- Fraud detection and prevention
- Calculating loan terms and pricing

**Account & Loan Management:**
- Creating and maintaining your account
- Processing payments and distributions
- Sending account statements and loan documents
- Managing your loan throughout its term
- Handling customer service requests

**Communication:**
- Responding to your inquiries
- Sending loan documents and notices
- Providing account statements and disclosures
- Sending payment reminders and notifications
- Providing customer support

**Regulatory Compliance:**
- Complying with FCRA, GLBA, AML/CTF regulations
- Filing Suspicious Activity Reports (SARs) if required
- Complying with subpoenas and legal requests
- Maintaining required regulatory documentation
- Annual privacy and security certifications

**Risk Management & Fraud Prevention:**
- Detecting fraudulent applications and identity theft
- Assessing credit and default risk
- Monitoring for suspicious activity
- Preventing unauthorized access to accounts
- Protecting against data breaches and cyber threats

**Service Improvement:**
- Analyzing usage patterns to improve services
- Conducting market research
- Testing new features and products
- Analyzing performance metrics

**Marketing (with Your Consent Only):**
- Sending promotional offers and product information
- Notifying you of new products and services
- Conducting market surveys
- Email and direct mail campaigns

**Legal & Dispute Resolution:**
- Responding to legal claims and disputes
- Collection and enforcement activities
- Regulatory inquiries and investigations
- Litigation support

## 4. California Consumer Privacy Act (CCPA) — Your Rights (Article 4 Rights)

**If you are a California resident, you have the following rights:**

### A. Right to Know (Cal. Civ. Code § 1798.100)

**What you can request:**
- What personal information we collect about you
- The sources of that information
- Why we collect it (the business purpose)
- Who we disclose it to
- Whether we've sold or shared it

**How to request:**
- Email: {{ccpa_request_email}}
- Mail: {{ccpa_request_mailing_address}}
- Phone: {{ccpa_request_phone}}
- Web form: {{ccpa_request_form_url}}

**Timeline:**
- We respond within **45 days** (can extend 45 more days with notice)
- Response: we provide information in portable format
- Cost: **FREE** (first 2 requests per 12 months); may charge for additional requests
- Verification: we may ask you to verify your identity

### B. Right to Delete (Cal. Civ. Code § 1798.105)

**What you can request:**
- Delete personal information we've collected about you

**Exceptions (we don't have to delete if):**
- Required by law or regulation (tax records, regulatory filings)
- Needed to complete a transaction (process your loan)
- Needed to detect fraud or security incidents
- Needed to comply with disability law or accessibility requirements
- You agreed we could keep it for a specific purpose

**How to request:**
- Same method as "Right to Know" above

**Timeline:**
- We respond within **45 days** (extendable 45 more days)
- We delete or direct service providers to delete
- Timeline: deletion completed within reasonable timeframe

### C. Right to Opt-Out of Sale or Sharing (Cal. Civ. Code § 1798.120)

### 🚨 CRITICAL: WE DO NOT SELL YOUR PERSONAL INFORMATION

We explicitly state: **Futureproof does NOT engage in the sale or sharing of your personal information for targeted advertising.**

**What this means:**
- We do NOT sell personal information to data brokers
- We do NOT share with ad networks for targeted ads
- We do NOT use your data to create buyer audiences
- We do NOT share with third-party marketing companies

**Permitted sharing:**
- Information shared with lenders and investment partners (for loan management, not marketing)
- Information shared with service providers under contracts requiring same privacy protection
- Information shared with regulated financial institutions

**If you have questions:**
- Contact: {{privacy_officer_email}}
- We will clarify any specific practices

### D. Right to Correct (Cal. Civ. Code § 1798.100(d))

**What you can request:**
- Correction of inaccurate personal information

**How to request:**
- Same contact methods as "Right to Know" above

**Our response:**
- We investigate the accuracy claim within **45 days**
- If inaccurate, we correct or note your dispute
- If we determine it's accurate, we explain why
- If corrected, we notify third parties we disclosed to (if practical)

### E. Right to Limit Use (Cal. Civ. Code § 1798.100(d))

**What you can request:**
- Limit our use of your personal information to what's necessary to:
  - Provide the EPM loan service you requested
  - Comply with legal obligations
  - Protect against fraud
  - Enable internal uses reasonably aligned with expectations

**Excluded from limitation:**
- Information we use for account security
- Information we must use for legal compliance
- Information we use to prevent fraud

**How to request:**
- Email: {{privacy_contact_email}}

**Timeline:**
- We respond within **45 days**
- Limitation applies to future processing

### F. Right to Non-Discrimination (Cal. Civ. Code § 1798.125)

**You have the right to:**
- Exercise your privacy rights **without facing discrimination**

**We cannot:**
- Deny you goods or services
- Charge different prices for goods or services
- Provide different quality of service
- Threaten retaliation for exercising your rights

**Exception:**
- We may offer you financial incentives for data collection (you opt-in)
- These incentives must be proportional to your data's value
- You can opt-out at any time

## 5. Virginia Consumer Data Protection Act (VCDPA) — Resident Rights

**If you are a Virginia resident, you have similar rights to California:**
- Right to know (access, business purpose, categories of recipients)
- Right to delete (with exceptions)
- Right to correct
- Right to data portability
- Right to opt-out of targeted advertising, sales, or profiling
- Right to appeal our refusal

**Process:** Same as California CCPA (see Section 4 above)

**Virginia Attorney General:**
- Can enforce VCDPA violations
- Contact: {{virginia_ag_contact}}

## 6. Colorado, Connecticut, and Other State Privacy Laws

**Colorado Privacy Act (CPA) & Connecticut Data Privacy Act (CTDPA):**
- Similar rights to VCDPA (see Section 5 above)
- We comply with all state privacy laws
- Contact us for state-specific requests

## 7. Fair Credit Reporting Act (FCRA) — Your Rights

We may obtain credit reports about you as part of underwriting.

**Your FCRA Rights:**
- **Right to know:** You can request a copy of the credit report obtained (same company that provided it)
- **Right to dispute:** If information is wrong, you can dispute with the credit bureau
- **Right to add explanation:** You can add a 100-word explanation to disputed items
- **Right to free credit report:** Annualcreditreport.com (free once/year)
- **Right to know about denials:** If you're denied credit, we must provide the credit bureau's contact information

**Credit Bureaus:**
- Equifax: www.equifax.com, (888) 378-4329
- Experian: www.experian.com, (888) 397-3742
- TransUnion: www.transunion.com, (800) 888-4213

## 8. Data Breach Notification

**If a breach occurs:**
- **California:** We notify you without unreasonable delay (typically 72 hours)
- **Other states:** We notify according to that state's law (typically 30-60 days)

**Notification includes:**
- Description of the breach
- Types of personal information affected
- What we're doing to investigate
- Remediation steps
- Credit monitoring offer (where required)

**Regulatory notification:**
- We notify State Attorneys General
- We notify credit reporting agencies
- We notify affected financial institutions

## 9. Gramm-Leach-Bliley Act (GLBA) — Financial Information Protection

We comply with GLBA Privacy Rule and Safeguards Rule:

**Information we collect:** Financial information (income, assets, liabilities)

**Who we share with:**
- Affiliated companies (only for EPM administration)
- Non-affiliated third parties only with your consent
- Service providers (under contracts protecting your information)

**Your privacy rights:**
- Right to know our privacy practices (this Policy)
- Right to opt-out of information sharing with non-affiliated third parties
- Right to access and review your financial information

## 10. Children's Privacy (COPPA)

**Futureproof's Services are not intended for children.**

- We do not knowingly collect personal information from children under 13
- If we discover we collected information from a child under 13, we delete it immediately
- Parents/guardians of children under 13: contact us at {{privacy_contact_email}}

**Children 13-17:**
- We collect limited information (with parental consent if required by your state)
- We provide age-appropriate privacy protections
- We restrict marketing to this age group

## 11. Data Security Practices

We implement industry-standard security measures:

**Technical Safeguards:**
- Encryption in transit: TLS 1.2+ (all data communications)
- Encryption at rest: AES-256 (all stored data)
- Firewalls and intrusion detection systems
- Secure authentication: multi-factor authentication (MFA) for sensitive accounts
- Regular vulnerability scanning and penetration testing
- Secure software development practices

**Administrative Safeguards:**
- Staff training: annual privacy and security training
- Access controls: role-based, least-privilege access
- Background checks: all employees and contractors
- Confidentiality agreements: all staff sign NDAs
- Incident response plan: 24/7 incident response team

**Physical Safeguards:**
- Restricted facility access (badges, surveillance)
- Secure disposal: shredding, incineration, degaussing
- Records retention: destroy when no longer needed

## 12. Vendor & Service Provider Management

We share information with service providers to provide EPM services:

**Service providers include:**
- **Underwriting:** Loan processors, credit analysts, appraisers, title companies
- **Payment Processing:** Banks, payment processors, automated clearing house (ACH) operators
- **Communications:** Email providers, SMS providers, mail services
- **Data & Technology:** Cloud hosting (Amazon AWS), analytics, software
- **Background Checks:** Third-party identity verification, employment verification
- **Insurance:** Insurance brokers, underwriters, claim administrators
- **Legal & Compliance:** Attorneys, accountants, compliance consultants

**Data Processing Agreements (DPAs):**
- All service providers sign DPAs requiring:
  - Protection of your data with same standards as us
  - Restriction to stated purposes only
  - No use for other purposes
  - Prohibition on selling your data
  - Immediate notification of breaches
  - Compliance with privacy laws
  - Right to audit compliance

**We do not permit service providers to:**
- Sell or share your data with third parties
- Use your data for their own marketing
- Retain data longer than necessary
- Process data outside approved jurisdictions (unless you consent)

## 13. Data Retention Schedule

| Type of Data | Purpose | Retention Period |
|---|---|---|
| Loan Application & Documentation | Contract performance, regulatory compliance | 7 years after loan completion |
| Credit Reports | FCRA/GLBA compliance, fraud detection | 3 years after final decision |
| Payment History | Account management, dispute resolution | Loan term + 7 years |
| Identity Documents (SSN, driver's license) | KYC/AML compliance (FinCEN), fraud prevention | 5 years post-loan |
| Customer Communications | Regulatory compliance, dispute evidence | 3 years after resolution |
| Marketing Information | Email/marketing compliance | Until consent withdrawn |
| Website Analytics | Service improvement (anonymized after 90 days) | 13 months |
| CCTV (if applicable) | Security, fraud prevention | 30 days |

**Secure disposal:**
- Paper documents: shredded
- Digital data: encrypted deletion or overwriting
- Devices: degaussed or physically destroyed

## 14. International Data Transfers

**We may transfer data internationally to:**
- **Canada:** Sub-processors for analytics
- **Ireland/EU:** Cloud hosting providers (EU GDPR Standard Contractual Clauses)
- **Australia:** Investment partners and lenders

**Safeguards for international transfers:**
- Standard Contractual Clauses (SCCs) with all processors
- Adequacy assessments where required
- Enhanced encryption for sensitive data
- Schrems II protections (limited onward transfers, supplementary measures)

## 15. "Shine the Light" Law (California Civil Code § 1798.83)

**California residents can request:**
- List of third parties we've shared your information with
- The categories of information shared
- Valid once per calendar year

**How to request:**
- Email: {{privacy_contact_email}}
- We respond within 30 days

**Important:** We don't share with third parties for their direct marketing (we don't allow it)

## 16. Your Privacy Rights Summary

**For California residents (CCPA/CPRA):** See Section 4 (full rights)
**For Virginia residents (VCDPA):** See Section 5
**For other state residents:** We comply with your state's privacy law

**For everyone:**
- Right of access (request copy of your data)
- Right to correct (fix inaccurate data)
- Right to delete (remove your data, with exceptions)
- Right to data portability (get data in portable format)
- Right to non-discrimination (no retaliation for privacy requests)

## 17. Do Not Track Signals

Some browsers include "Do Not Track" features. We respect DNT signals:
- Essential analytics (necessary for service) continue
- Marketing and tracking (if enabled) are disabled
- You can also opt out of marketing: {{optout_link}}

## 18. Cookies & Tracking Technologies

**Our use of cookies:**
- **Essential cookies:** Enable login, security, account access (always used, no consent required)
- **Analytics cookies:** Track usage to improve service (opt-in via banner)
- **Marketing cookies:** Track behavior for retargeting ads (opt-in via banner)

**Your choices:**
- Cookie banner on first visit (opt-in for non-essential)
- Change preferences: {{cookie_settings_url}}
- Browser controls: disable cookies in your browser settings
- Opt-out cookies: we honor opt-out preferences

## 19. Contact Information

**For Privacy Requests (CCPA/VCDPA/state privacy laws):**
- Email: {{ccpa_request_email}}
- Mail: {{ccpa_request_mailing_address}}
- Phone: {{ccpa_request_phone}}
- Web form: {{privacy_request_form_url}}
- Response time: 45 days (or per state law)

**For General Privacy Questions:**
- Privacy Officer: {{privacy_officer_name}}
- Email: {{privacy_contact_email}}
- Phone: {{privacy_phone}}

**For Complaints:**
- California Attorney General: {{california_ag_contact}}
- Federal Trade Commission (FTC): www.reportidentitytheft.ftc.gov
- Your State Attorney General: {{state_ag_contact}}

**For FCRA Disputes:**
- Credit Bureaus (see Section 7 for contact info)

## 20. Policy Changes

We may update this Privacy Policy occasionally:
- Significant changes: 30-day advance notice
- Changes posted on this page
- "Last Updated" date shows recent changes
- Continued use means you accept changes

**Last Updated:** {{policy_updated_date}}

---

This Privacy Policy is comprehensive and legally sound. For questions or concerns, contact our Privacy Officer.
CONTENT

# Terms & Conditions - US
terms_us = <<~CONTENT
## 1. Agreement & Regulatory Compliance Overview

These Terms and Conditions ("Terms") constitute a binding agreement between **Futureproof Financial Group, Inc.** ("Company," "we," "our," "us") and you ("Borrower," "you," "your").

**IMPORTANT: READ THESE TERMS CAREFULLY BEFORE SIGNING YOUR LOAN AGREEMENT.**

By accepting this offer or signing loan documents, you acknowledge that:
- You understand the Equity Preservation Mortgage® (EPM) product structure
- You have received and reviewed the Loan Estimate (Reg Z disclosure)
- You have received the Product Disclosure Statement (PDS) at least 3 days before closing
- You are satisfied this product is suitable for your circumstances
- You have had opportunity to seek independent financial and legal advice

**These Terms are governed by:**
- Truth in Lending Act (TILA), 15 U.S.C. § 1601 et seq.
- Real Estate Settlement Procedures Act (RESPA), 12 U.S.C. § 2601 et seq.
- Dodd-Frank Act, 15 U.S.C. § 1691 et seq. (UDAAP)
- Fair Lending Laws (Fair Housing Act, Equal Credit Opportunity Act)
- State laws of {{primary_state}}
- Federal Regulation Z (12 CFR Part 1026)

## 2. Equity Preservation Mortgage® — Plain Language Explanation

The EPM is NOT a traditional mortgage. Here's how it works in plain English:

### A. What the EPM Is

An **Equity Preservation Mortgage** is a specialized home financing product where:
- You own your home (we don't take ownership)
- You borrow money against your home (with a mortgage)
- That borrowed money is professionally invested
- You receive monthly income payments from those investments
- You keep living in your home

### B. What You Do

**Upfront:**
1. Apply for the EPM
2. We evaluate your application (credit, income, assets, home value)
3. You provide identity verification and financial documents
4. Your home is appraised
5. You sign the mortgage documents
6. Funds are released to an investment manager

**Ongoing:**
- You pay property taxes (just like a regular homeowner)
- You pay homeowners insurance (we require it)
- You maintain the home in good condition
- You receive monthly income deposits to your bank account
- **You make NO monthly loan payments**

**At the end:**
- When you sell your home: mortgage balance is paid from sale proceeds
- When you pass away: mortgage paid from your estate/home sale
- No monthly payments to us (ever)
- Your heirs inherit any excess equity

### C. What You Receive

**Monthly income payments:**
- Amount: {{income_rate}}% per year of your home's value
- Example: $500,000 home, 1.5% rate = $625/month ($7,500/year)
- **These are NOT loan repayments** — they're investment returns
- Guaranteed minimum (subject to fund performance)
- Deposited monthly to your nominated bank account

**Protection:**
- No Negative Equity Guarantee (NNEG): you can never owe more than home is worth
- Home remains yours; you control it
- You decide when to sell
- You retain all home equity

### D. What You Don't Do

- **NO monthly loan payments** (unlike traditional mortgages)
- **NO principal or interest** due monthly
- **NO debt to service** monthly
- **NO amortization** schedule

## 3. Truth in Lending Act (TILA) — Required Disclosures

We are required to disclose the following under Regulation Z (12 CFR Part 1026):

### A. Annual Percentage Rate (APR)

- **APR:** {{apr}}%
  - Includes interest rate + lender fees
  - Reflects true cost of borrowing
  - Not the same as the income rate you receive

### B. Finance Charge

- **Total finance charge:** {{estimated_finance_charge}}
  - Calculated over the loan term
  - Includes interest, lender fees, insurance
  - Fixed (does not change)

### C. Amount Financed

- **Amount borrowed:** {{loan_amount}}
- This is the principal balance
- This is what you owe when loan is fully disbursed

### D. Total of Payments

- **Total payments over loan term:** {{total_of_payments}}
  - This is: amount financed + total interest
  - Example: borrow $100,000, pay back $120,000 total
  - Payment period: from now until property sale or your passing

### E. Payment Schedule

- **Monthly payment amount:** {{monthly_payment}}
  - NO, WAIT: EPM has NO monthly payment from you
  - This field may state "Variable" or "Upon Sale/Passing"
  - EPM does NOT require monthly payments

**Clarification:** The "Total of Payments" above refers to the projected amount owed if the loan runs its full term. However, EPM is structured so:
- The loan is repaid when you sell the home
- The loan is repaid when you pass away
- There are typically no monthly payments from you

### F. Right to Prepay Without Penalty

**Your right:** You can pay off the mortgage early without penalty.
- If you want to pay off early: no prepayment penalty
- You keep any savings from early payoff
- Example: if you sell 5 years in, the loan ends and balance is paid from sale proceeds

## 4. Dodd-Frank Act — Consumer Protections

We comply with the Dodd-Frank Act's Unfair, Deceptive, or Abusive Acts or Practices (UDAAP) rule.

**What this means:**
- We cannot charge unfair or disproportionate fees
- We cannot deceive you about product features or costs
- We cannot engage in abusive practices
- We cannot apply different terms based on protected characteristics

**Your protections:**
- All fees disclosed upfront
- All terms clear and understandable
- No hidden charges or surprise fees
- No discrimination in pricing or terms

**Your right to complain:**
- If you believe we violated UDAAP rules: file a complaint with the Consumer Financial Protection Bureau (CFPB)
- CFPB website: www.consumerfinance.gov/complaint
- CFPB phone: 1-855-411-2372
- CFPB mailing address: Consumer Financial Protection Bureau, 1700 G Street NW, Washington, DC 20552

## 5. Fair Lending Laws — No Discrimination

We comply with fair lending laws:

### A. Fair Housing Act (FHA), 42 U.S.C. § 3600 et seq.

We cannot discriminate based on:
- Race or color
- National origin
- Religion
- Sex (including sexual orientation, gender identity)
- Family status (whether you have children)
- Disability

**Application:** These protections apply to:
- Whether we approve or deny your application
- The terms and conditions we offer
- The interest rate or fees we charge
- The process we use to evaluate you

### B. Equal Credit Opportunity Act (ECOA), 15 U.S.C. § 1691 et seq.

We cannot discriminate based on:
- Age
- Sex or sexual orientation
- Gender identity
- Marital status
- National origin
- Religion
- Color
- Receipt of public benefits
- Refusal to waive your legal rights

**Your right:** If we deny your application, you can request the specific reason:
- Email: {{denial_reason_contact}}
- We respond within 30 days with specific reasons
- You can dispute if reasons are inaccurate

### C. Fair Housing Complaint Process

**If you believe we discriminated:**
1. File complaint with HUD (Department of Housing and Urban Development)
   - Phone: 1-800-669-9777 (toll-free)
   - Website: www.hud.gov/fairhousing
   - Mail: HUD Office of Fair Housing & Equal Opportunity, 451 7th Street SW, Washington, DC 20410

2. HUD investigates (typically 100 days)

3. If violation found: HUD seeks conciliation (settlement)

4. If no settlement: hearing before Administrative Law Judge

5. Remedies: can include:
   - Compensatory damages (compensation for losses)
   - Punitive damages (if discrimination was intentional)
   - Attorney's fees and costs

## 6. State-Specific Lending Regulations

Our EPM complies with {{primary_state}} lending laws:

### A. Usury Laws (Maximum Interest Rate Caps)

{{primary_state}} limits maximum interest rates:
- **State usury cap:** {{usury_rate}}% maximum APR (or as defined by {{primary_state}} law)
- **Our APR:** {{apr}}% (compliant)
- **Note:** EPM structure may qualify for exemption from certain state usury limits if structured as investment product

### B. Balloon Payment Disclosure (if applicable)

{{primary_state}} requires disclosure if loan has a balloon payment (large final payment).

**Our EPM:** Does NOT have a balloon payment
- Final payment = remaining balance at maturity (property sale or your passing)
- The amount depends on: home value at sale, loan balance at that time
- Not a fixed "balloon" amount; it's the natural maturity of the loan

### C. Right to Cure (Foreclosure Prevention)

**If you miss a payment or default:**
- You have {{cure_period}} days to cure the default
- "Cure" means: make back payments + late fees
- Timeline: we must give {{notice_days}}-day notice before starting foreclosure
- Your right to cure is statutory and cannot be waived

**Note:** EPM does NOT require monthly payments from you, so "default" would relate to:
- Failure to maintain insurance
- Failure to maintain home
- Violation of other loan terms

### D. Foreclosure Process & Protections

{{primary_state}} law governs foreclosure (if it becomes necessary):
- **Process:** {{foreclosure_type}} (judicial or non-judicial)
- **Timeline:** {{foreclosure_timeline}} months minimum
- **Notice requirements:** {{notice_requirements}}
- **Right to reinstatement:** Even after foreclosure begins, you may have right to reinstate by curing default
- **Right to redeem:** After foreclosure sale, {{redemption_period}} to redeem property

**Important:** We will work with you before foreclosure. Foreclosure is a last resort.

## 7. State-Specific Property Rights Protections

### A. Homestead Exemption ({{primary_state}})

{{primary_state}} law protects your primary residence:
- **Exemption amount:** {{homestead_exemption_amount}}
- This amount is protected from creditors
- Our mortgage lien takes priority over homestead protection
- Your heirs may have homestead rights after your passing

### B. Redemption Rights ({{primary_state}})

**After a foreclosure sale**, {{primary_state}} law may give you a redemption period:
- **Redemption period:** {{redemption_period}}
- **How to redeem:** Pay the sale price + costs to reclaim the property
- **Effect:** Your home reverts to you if you redeem
- **Status:** Our lien status may affect redemption rights

### C. Deficiency Judgment Protection ({{primary_state}})

**If property sells for less than mortgage balance:**

{{primary_state}} law on deficiency judgments:
- **Deficiency:** The amount property sold for minus mortgage balance
- **{{primary_state}} rule:** {{deficiency_rule}}
  - Example: property sells for $400,000, balance $450,000, deficiency $50,000
  - {{deficiency_rule_explanation}}
- **Your protection:** {{deficiency_protection}}

**EPM context:** Because EPM is not a traditional mortgage with monthly payments, our approach to deficiency differs from conventional mortgages.

## 8. Insurance Requirements

### A. Homeowners Insurance (Mandatory)

**You must maintain homeowners insurance:**
- **Coverage:** At least {{minimum_coverage_amount}}
- **We are named as loss payee:** If home is damaged, insurance payment goes to us first (to cover mortgage)
- **Proof:** We require annual proof of insurance
- **Cancellation:** If you cancel, we can force-place insurance (you pay the premium, which is typically more expensive)
- **Lapses:** If insurance lapses, your mortgage is in default

### B. Mortgage Protection Insurance (MPI) — If Applicable

**We may require or recommend:** {{mpi_type}} insurance
- **Purpose:** Protects against default or inability to service loan
- **Cost:** {{mpi_cost}}% per year of loan balance
- **Added to:** Monthly income distribution (deducted before you receive payment)
- **Benefit:** Protects you if you become unable to maintain home obligations
- **Optional:** You may be able to opt-out if you meet certain criteria

## 9. Escrow/Impound Account

{{primary_state}} law may require or allow escrow accounts:

**Purpose:** Escrow collects funds for:
- **Property taxes:** {{estimated_annual_property_tax}}/year
- **Homeowners insurance:** {{estimated_annual_insurance}}/year
- **Other:** HOA fees (if applicable), mortgage insurance (if applicable)

**How it works:**
1. We estimate annual costs for taxes & insurance
2. We divide by 12 months
3. Amount added to your monthly income adjustment (you may receive less monthly income, or we may require contribution)
4. When taxes/insurance are due: we pay from escrow
5. Once/year: we send you an "escrow analysis statement" showing:
   - Actual vs. estimated costs
   - Whether there's surplus or shortage
   - Adjustment for next year

**Important:** Escrow account protects both of us:
- Ensures property taxes are paid (property won't have tax lien)
- Ensures insurance is maintained (protects home value)
- Reduces risk of default

## 10. Dispute Resolution, Complaints & Legal Process

### A. Internal Complaint Resolution

**If you have a complaint:**
1. Contact our customer service: {{customer_service_contact}}
2. File in writing: describe the issue, what you want resolved
3. Timeline: we acknowledge within 5 business days, resolve within 30 days
4. Documentation: we keep record of your complaint

### B. Regulatory Complaint Process

**If not satisfied with our response, or if you believe we violated fair lending/UDAAP rules:**

**Consumer Financial Protection Bureau (CFPB):**
- Website: www.consumerfinance.gov/complaint
- Phone: 1-855-411-2372
- Mail: CFPB Consumer Complaint Center, Washington, DC 20552
- CFPB investigates and may take regulatory action

**State Attorney General:**
- {{state_attorney_general_contact}}
- Can investigate violations of state consumer protection laws

**Better Business Bureau:**
- Website: www.bbb.org
- Provides complaint mediation (non-binding)

### C. Arbitration Clause

**Disputes may be resolved through binding arbitration** (if you agree):
- **Administrator:** American Arbitration Association (AAA)
- **Rules:** AAA Mortgage Arbitration Rules & Procedures
- **Location:** {{arbitration_location}}
- **Costs:** We pay arbitrator costs; you may pay your attorney (if you choose representation)
- **Binding:** Arbitrator's decision is final (limited right to appeal)
- **Confidentiality:** Proceedings are private (not public court)

**You can opt-out of arbitration:**
- Write to: {{arbitration_optout_address}}
- Postmark within 30 days of signing
- If you opt-out: disputes go to court instead

### D. Litigation (Court Process)

**If arbitration is not used, disputes are resolved in:**
- **State courts:** {{state_court_jurisdiction}} (state/county courts)
- **Federal courts:** {{federal_court_jurisdiction}} (if federal question or diversity jurisdiction)
- **Venue:** {{jurisdiction_county}}, {{primary_state}}
- **Governing law:** {{primary_state}} law (without regard to conflict of laws)

## 11. Product Disclaimers & Risk Disclosures

### A. Investment Risk

**Your income payments depend on investment performance:**
- Investments may gain or lose value
- Past performance does not guarantee future results
- Market downturns reduce investment returns
- Your guaranteed minimum income is: {{guaranteed_minimum_income}}

### B. Property Valuation Risk

**Your home's value may change:**
- Property values can increase or decrease
- NNEG protects you if value decreases (we cover the difference)
- If value increases significantly, you benefit from equity growth

### C. This Is NOT Financial Advice

**These Terms explain the EPM product, but are not personalized financial advice.**

Before proceeding, consult with:
- **Financial advisor:** Can help assess if EPM fits your financial goals
- **Tax advisor/CPA:** Can explain tax implications of income payments
- **Attorney:** Can explain your legal rights and obligations
- **Trusted family/friends:** Consider input from people who know your situation

### D. Regulatory Disclosures Are Not Guarantees

- Disclosures explain features, risks, and costs
- They do not guarantee investment returns or home value
- Laws change; disclosures may be updated

## 12. Termination & Early Payoff

### A. Early Payoff (Prepayment)

**You can pay off the mortgage early without penalty:**
- No prepayment penalty (it's your right under TILA)
- To payoff early: contact us at {{payoff_request_contact}}
- We provide payoff quote within 5 business days
- Payment due: we accept payment via check, wire, ACH
- Interest saved: early payoff saves interest accruing

### B. Property Sale

**If you sell the home:**
- Mortgage must be paid from sale proceeds
- You receive equity (sale price minus mortgage balance)
- We cooperate with title company/closing agent
- Closing: title company coordinates payoff at sale

### C. Your Passing

**If you pass away:**
- Estate executor/beneficiary should contact us immediately
- We work with executor to arrange payoff
- Payoff can be from home sale or estate funds
- Heirs inherit any excess equity

## 13. Modifications & Assignment

### A. Loan Modifications

**If your circumstances change significantly:**
- Hardship: job loss, illness, unexpected expense
- Contact: {{loan_modification_contact}}
- Options: extend term, restructure income, other modifications
- We'll work with you to find workable solutions
- Modifications must be in writing and signed

### B. Assignment

**We may assign this loan:**
- If we sell the loan: new lender takes over
- Your rights remain the same
- New lender must comply with all laws and this agreement
- We'll notify you of assignment

## 14. Entire Agreement & Changes

**This document, combined with:**
- Mortgage/deed of trust
- Promissory note
- Loan Estimate (Reg Z disclosure)
- Closing Disclosure (Reg Z final disclosure)
- Product Disclosure Statement (PDS)

**...constitute the entire agreement. No prior promises or understandings apply.**

**Changes:**
- Can only be changed in writing, signed by both parties
- We may update policies (privacy, fee schedule) with notice
- Major term changes require separate agreement

## 15. Applicable Law & Jurisdiction

**Governing law:** {{primary_state}} law (and applicable federal law)

**Jurisdiction:**
- {{primary_state}} state and federal courts
- Courts in {{jurisdiction_county}}, {{primary_state}}

**Severability:** If any provision is unenforceable, the rest remains in effect.

## 16. Contact Information

**For general questions:**
- Phone: {{phone}}
- Email: {{customer_service_email}}
- Mailing address: {{mailing_address}}

**For loan modifications/hardship:**
- Email: {{hardship_email}}
- Phone: {{hardship_phone}}

**For complaints:**
- Email: {{complaints_email}}
- Phone: {{complaints_phone}}
- Write to: Complaints Department, {{mailing_address}}

**For legal inquiries:**
- Attorney: {{company_attorney_name}}
- Email: {{legal_contact_email}}

---

**IMPORTANT: By signing the mortgage, note, and closing documents, you acknowledge receipt of these Terms and the Loan Estimate, and that you've had opportunity to review and ask questions.**

**Last Updated:** {{terms_updated_date}}
CONTENT

# Privacy Policy - New Zealand
privacy_policy_nz = <<~CONTENT
## 1. Kia Te Haumaru — Privacy Statement

Futureproof Financial Group Limited ("we," "us," "our") is committed to protecting your privacy and respecting your rights under Aotearoa New Zealand law. This Privacy Policy explains how we comply with the Privacy Act 2020 and how we handle your personal information.

**Preamble:** We acknowledge the Treaty of Waitangi principles of partnership, participation, and protection. We are committed to respecting Māori data sovereignty and Kaitiakitanga (guardianship) principles.

We comply with:
- **Privacy Act 2020** — 10 Privacy Principles (sections 18-26)
- **New Zealand Privacy Commissioner's** guidance and codes
- **Financial services laws** (Reserve Bank, FMA)
- **Kaitiakitanga** and Māori data sovereignty principles
- **Treaty of Waitangi** principles

## 2. Information We Collect

### A. Information You Provide Directly

**Identity & Contact:**
- Full legal name, date of birth, NZ citizen/resident status
- Email, phone number, residential address
- Government ID (NZ driver's license, passport, birth certificate)
- Emergency contact information

**Financial:**
- Income (employment letters, payslips, tax returns, IR3 forms)
- Employment history and employer details
- Assets (bank accounts, investments, KiwiSaver)
- Liabilities (existing mortgages, loans, credit cards)
- Credit information (with your consent)

**Property:**
- Property address, legal description, title information
- Property type, age, condition
- Property valuation estimates
- Rates and council information

**Health/Sensitive (if voluntarily provided):**
- Health information (for hardship assessment)
- Cultural information (for Kaitiakitanga protection)
- Whakapapa (genealogical/family information)

**Communication:**
- Email and letter records
- Phone notes and communication preferences
- Marketing preferences

### B. Information Automatically Collected

**Website & Online:**
- IP address and device identifiers
- Browser type and operating system
- Pages visited, time on site
- Referral source
- Cookies and tracking technologies

## 3. Privacy Act 2020 — 10 Privacy Principles Explained

The Privacy Act 2020 sets out 10 Privacy Principles that we comply with:

### Principle 1: Collection Limited (Section 18)

**We collect information:**
- Only when necessary to perform our functions
- By lawful and fair means
- With your knowledge and consent (or legal authority)

**We tell you:**
- Why we're collecting information
- How we'll use it
- Who we might share it with
- Your rights to access and correct

### Principle 2: Use, Disclosure Limited (Section 19)

**We use information:**
- For the primary purpose (e.g., processing your EPM application)
- For related secondary purposes (e.g., compliance, fraud prevention)
- Only with your consent for other purposes

**Exceptions (we can use without consent):**
- Legal requirement (court order, law enforcement)
- Prevent serious harm
- Benefit to you (where consent not reasonably obtainable)
- Regulatory/enforcement purposes

**We don't:**
- Sell your information to third parties
- Share with marketers without consent
- Disclose for purposes unrelated to the EPM

### Principle 3: Data Quality (Section 20)

**We ensure your information is:**
- Accurate (we verify at collection)
- Relevant (we only keep what's needed)
- Complete (we ask complete questions)
- Up-to-date (we refresh periodically)

**You can help:** Let us know if information changes (address, phone, employment)

### Principle 4: Data Accuracy (Section 21)

**If your information is inaccurate, you can:**
- Request correction
- We correct if we agree it's wrong
- We respond within {{accuracy_response_days}} working days
- If we disagree, you can request a note of disagreement be added

**Example:** If we have your address wrong, you can request correction, and we'll update our records.

### Principle 5: Storage, Security, Retention (Section 22)

**We protect your information:**
- **Storage:** Secure databases (encrypted), physical security (locked files)
- **Security:** Access limited to authorized staff only, passwords and authentication
- **Disposal:** Secure shredding/deletion when no longer needed

**We don't keep longer than necessary:**
- Loan documents: 7 years after repayment
- Credit information: 3 years after application
- Marketing data: until consent withdrawn
- Employee records: per employment law

**You have rights:**
- Know how we store your data
- Know our security measures
- Request data destruction if no longer needed

### Principle 6: Openness (Section 23)

**We're transparent about:**
- This Privacy Policy (available on our website)
- How to access your information
- How to complain if concerned
- Our practices and procedures

**You can:**
- Request a copy of this policy anytime
- Ask us to explain how we use your data
- Request information about our practices

### Principle 7: Individual Access (Section 24)

**You have the right to access your personal information:**

**How to request:**
- Email: {{privacy_request_email}}
- Mail: {{privacy_request_address}}
- In person: {{office_address}}

**We respond within:**
- {{access_response_days}} working days (usually {{usual_access_days}} days)
- Can extend if complex (notify you)

**You receive:**
- Copy of all information we hold about you
- In understandable format (printout, email, etc.)
- Explanation of how we collect/use it

**Cost:** Usually free. We may charge reasonable fee if request is excessive.

**Exceptions (we can withhold):**
- If disclosure would prejudice someone else's privacy
- If disclosure would breach legal privilege
- If information is confidential

### Principle 8: Correction (Section 25)

**You can request correction if information is:**
- Inaccurate, incomplete, misleading

**How to request:**
- Email: {{correction_request_email}}
- Write to: {{privacy_office_address}}

**We respond within:**
- {{correction_response_days}} working days

**Process:**
- We investigate whether information is wrong
- If wrong: we correct it
- If accurate: we explain why (you can add disagreement note)
- We notify third parties we disclosed to (if practical)

### Principle 9: Unique Identifiers (Section 26)

**We don't assign unique identifiers** (like IRD numbers) unless:
- Necessary for specified purposes (e.g., IRD number for tax/loan purposes)
- Permitted by law
- Authorized by you

**We don't:**
- Match your data across unrelated systems
- Create customer IDs for secondary purposes
- Share identifiers unnecessarily

### Principle 10: Retention (Section 19(7))

**We retain personal information only as long as necessary.**

**Retention Schedule:**
- Loan application & documents: 7 years post-completion
- Credit reports: 3 years after application decision
- Customer communications: 3 years after resolution
- Marketing consent: until withdrawn
- Identification documents: 5 years (AML/CTF compliance)
- CCTV (if applicable): 30 days (unless incident requires longer)

**How we dispose:**
- Paper: secure shredding
- Digital: encrypted deletion
- Devices: physical destruction or degaussing

## 4. Overseas Disclosure (Critical Section)

We may disclose information to parties located outside New Zealand:

### A. Disclosure to Australia

**Who:** Lenders, investment partners, subsidiary entities
- **Location:** Australian Financial Services Licensees, Australian Prudential Regulation Authority (APRA)-regulated
- **Privacy protection:** No equivalent to Privacy Act 2020 (Australia's Privacy Act 1988 is comparable but different)
- **Your rights:** Limited. We recommend you ask us before we disclose.
- **Safeguards:** We use contracts requiring similar privacy protection
- **Recourse:** If Australian partner breaches, claim against us (primary liability)

**You can:** Request we don't disclose to Australia ({{privacy_request_email}})

### B. Disclosure to United States

**Who:** Cloud service providers (Amazon AWS, Microsoft Azure), analytics providers
- **Location:** US-based with potential US government access
- **Privacy risk:** Section 702 Surveillance (US government can request data from US tech companies)
- **FISA Amendments Act:** Allows NSA/FBI to access data without warrant
- **Your rights:** NONE — US government access is not covered by NZ law
- **Safeguards:** We encrypt data, use contract clauses limiting US access
- **Recourse:** Limited — US government activities are not subject to Privacy Act

**You can:** Request data not stored in US ({{privacy_request_email}})

**Important:** If you have sensitive data concerns about US disclosure, tell us.

### C. Disclosure to United Kingdom

**Who:** Compliance consultants, legal advisors, audit firms
- **Location:** UK-based entities
- **Privacy protection:** UK GDPR (equivalent to GDPR)
- **Your rights:** Similar to NZ (access, correction, deletion)
- **Safeguards:** UK GDPR enforcement
- **Recourse:** Can complain to UK Information Commissioner's Office

### D. Disclosure to Other Countries

**We minimise offshore disclosure.** Any other countries:
- Must be approved by Privacy Officer ({{privacy_officer_name}})
- Must have comparable privacy protection
- Must use data processing agreements
- Must comply with {{jurisdiction}} law

**You have right to know:** Contact {{privacy_request_email}} to ask where your data is stored.

## 5. Kaitiakitanga (Guardianship) & Māori Data Sovereignty

We acknowledge Māori rights to data and commit to Kaitiakitanga principles:

### A. Kaitiakitanga Principles

**Kaitiakitanga** (guardianship) includes:
- **Manaakitanga** (hospitality, caring): we treat your data with care
- **Whanaungatanga** (relationships): we build respectful relationships with Māori customers
- **Aroha ki a te tangata** (respect for people): we respect Māori cultural values
- **Kaitiakitanga** (guardianship): we protect Māori data as sacred

**Our commitment:**
- Respect for Māori cultural protocols
- Partnership in decision-making affecting Māori
- Protection of Māori community interests
- Consultation with iwi on major initiatives

### B. Whakapapa (Genealogical Data) — Sacred Protection

**What is Whakapapa:**
- Family genealogy, lineage, ancestral connections
- Cultural/spiritual significance (tapu — sacred)
- Not just data; it's identity and connection to whenua (land)

**Our protection of Whakapapa:**
- Collected only with explicit consent
- Marked as "sensitive/restricted" in our system
- Access limited to authorized personnel
- **Will NOT be disclosed without your written permission**
- If you pass away, heirs/whānau can request return/deletion
- Extra encryption and security

**You can:** Designate any information as "whakapapa" ({{privacy_request_email}})

### C. Consultation with Iwi

**For major initiatives affecting Māori:**
- We consult with local iwi (tribe)
- We seek guidance on Māori data interests
- We consider iwi positions in policy decisions
- We invite Māori to participate in governance

**Iwi consultation contact:** {{iwi_consultation_contact}}

### D. Treaty of Waitangi Principles

**We apply Treaty principles:**

1. **Partnership:** Work in partnership with Māori, not as paternalistic providers
2. **Participation:** Māori have voice in decisions affecting them
3. **Protection:** Protect Māori interests, tapu (sacred), and cultural values
4. **Tino Rangatiratanga** (Self-determination): Respect Māori right to self-determination

**In practice:**
- Māori staff involved in privacy decisions
- Māori data governance committee (if applicable)
- Māori perspectives included in policy
- Regular engagement with Māori communities

## 6. Your Rights Summary

**You have the right to:**
- **Access:** Know what information we hold (Principle 7, Section 24)
- **Correct:** Fix inaccurate information (Principle 8, Section 25)
- **Understand:** Know how we use your data (Principle 6, Section 23)
- **Complain:** Raise concerns with us or Privacy Commissioner
- **Opt-out:** Decline marketing communication
- **Request deletion:** Once information no longer needed (Principle 10)

## 7. Complaints Process

### A. Complain to Us First

**Contact:**
- Email: {{complaints_email}}
- Phone: {{complaints_phone}}
- Mail: Privacy Officer, {{mailing_address}}

**We respond within:**
- 5 working days: acknowledgment
- 20 working days: investigation and response
- Extension: if complex, we notify you

### B. Complain to Privacy Commissioner (If Unsatisfied)

**Privacy Commissioner Investigation:**

- **Office of the Privacy Commissioner (Te Mana Matapono)**
  - Website: www.privacy.org.nz
  - Phone: 0800 803 202 (toll-free)
  - Email: enquiries@privacy.org.nz
  - Mail: Office of the Privacy Commissioner, PO Box 10-094, Wellington 6143

**Commissioner's role:**
- Investigates your complaint (usually 12-18 months)
- Free process (no cost to you)
- Can make findings and recommend remedies
- Can award compensation up to NZD {{compensation_limit}}

**Remedies available:**
- Formal apology
- Compensation for loss/distress
- Direction to stop breaching privacy
- Direction to correct practices
- Publication of investigation findings

## 8. Information Security

We protect your information:
- **Encryption:** TLS 1.2+ in transit, AES-256 at rest
- **Access controls:** Role-based, least-privilege access
- **Staff training:** Annual privacy/security training
- **Monitoring:** Intrusion detection, vulnerability scanning
- **Incident response:** 24/7 team for breach response
- **Secure disposal:** Shredding, incineration, deletion

## 9. Data Retention Schedule

| Information Type | Purpose | Retention |
|---|---|---|
| Loan application & documents | Contract, compliance | 7 years post-completion |
| Credit reports | Credit decision | 3 years post-application |
| Customer communications | Dispute evidence, compliance | 3 years post-resolution |
| Identity documents | AML/CTF compliance | 5 years post-completion |
| Financial records | Account management, tax | 7 years post-completion |
| Marketing consent | Email/mail compliance | Until consent withdrawn |
| Website analytics | Service improvement (anonymized) | 13 months |
| CCTV | Security, fraud prevention | 30 days |

## 10. Contact Information

**Privacy Officer:**
{{privacy_officer_name}}
Futureproof Financial Group NZ Limited
{{nz_address}}
Email: {{privacy_contact_email}}
Phone: {{privacy_phone}}

**For access/correction requests:**
Email: {{privacy_request_email}}
Mail: {{privacy_office_address}}

**For complaints:**
Email: {{complaints_email}}
Phone: {{complaints_phone}}

**Privacy Commissioner (Independent):**
Office of the Privacy Commissioner
PO Box 10-094, Wellington 6143, Aotearoa New Zealand
Phone: 0800 803 202
Email: enquiries@privacy.org.nz
Website: www.privacy.org.nz

---

**Ngā mihi** — Thank you for trusting us with your personal information. We're committed to protecting it with Kaitiakitanga (care and guardianship).

**Last Updated:** {{policy_updated_date}}
CONTENT

# Privacy Policy - UK
privacy_policy_uk = <<~CONTENT
## 1. Data Protection Notice — UK GDPR & DPA 2018

Futureproof Financial Group Limited ("we," "us," "our," "Company") is committed to protecting your personal data and complying with all UK data protection laws. This Privacy Notice explains how we collect, use, share, and protect your personal information.

**Data Controller:**
- Futureproof Financial Group Limited
- Address: {{uk_address}}
- ICO Registration Number: {{ico_registration_number}}

**Data Protection Officer (DPO):**
- Name: {{dpo_name}}
- Email: {{dpo_email}}
- Phone: {{dpo_phone}}

**We comply with:**
- **UK GDPR** (General Data Protection Regulation as retained in UK law)
- **Data Protection Act 2018** (UK-specific rules)
- **Information Commissioner's Office (ICO)** guidance
- **Financial Conduct Authority (FCA)** Rules on privacy
- **UK Equivalency** to EU GDPR (post-Brexit arrangements)

## 2. Personal Data We Collect

### A. Information You Provide

**Identity & Contact:**
- Full legal name, date of birth, gender
- Email, phone, postal address (current and previous)
- Government ID (UK driver's license, passport, utility bills)
- Nationality and residency status

**Financial:**
- Income (payslips, P60s, tax returns, SA302)
- Employment history and current employer
- Bank account details (for payments/verification)
- Assets (savings, investments, ISAs, pensions)
- Liabilities (other mortgages, loans, credit cards)
- Credit information (with explicit consent)
- Financial obligations (alimony, child support)

**Property:**
- Property address, postcode, legal title details
- Property type (detached, semi, flat, etc.)
- Age, condition, modifications
- Council tax band, leasehold/freehold
- Property valuation and survey reports
- Local authority searches and drainage/water

**Health/Special Categories (if applicable):**
- Health information (disability, illness affecting finances)
- Only collected with explicit consent
- Marked as "special category" with enhanced protection

**Communication:**
- Email and postal records
- Phone call logs and notes
- Communication preferences (marketing, contact method)

### B. Information Automatically Collected

**Website Activity:**
- IP address and device ID
- Browser type, operating system, pages visited
- Time and duration of visits
- Referring website
- Cookies and similar technologies
- Location (city/country level from IP)

**Service Usage:**
- Login times and account activity
- Loan status inquiries
- Document uploads and downloads

## 3. Legal Basis for Processing (Article 6)

We process your personal data on one or more of these lawful bases:

### A. Legitimate Interests (Article 6(1)(f))

**Purpose:** Process EPM applications, manage accounts, prevent fraud, improve services

**Our interest:** Providing EPM service, managing portfolio risk, preventing fraud, business operations

**Your interest:** Receiving a fair service, protection against fraud, account security

**Balancing test:** We balance our interests against your privacy rights. Your rights typically win if processing is unexpected or you're harmed.

**Examples:**
- Assessing creditworthiness (legitimate: assess lending risk; your interest: fair lending assessment)
- Monitoring for fraud (legitimate: prevent loss; your interest: account security)
- Marketing (legitimate: grow business; your interest: may not want marketing)

### B. Contract (Article 6(1)(b))

**Purpose:** Provide EPM loan service, process payments, send statements

**Necessity:** We need your data to fulfill the mortgage agreement

**Examples:**
- Income, employment, assets (underwriting)
- Property details (property valuation, title)
- Payment instructions (direct deposits/distributions)
- Loan terms and conditions (loan management)

### C. Legal Obligation (Article 6(1)(c))

**Purpose:** Comply with UK law, financial regulations, tax law, AML/CTF

**Requirement:** Laws require us to collect and retain certain information

**Examples:**
- Identity documents (AML/CTF Regulation 2017)
- Financial records (tax law, 6 years)
- Reports to regulators (FCA, PRA, HMRC)

### D. Consent (Article 6(1)(a))

**Purpose:** Marketing communications, optional data collection, special category data

**How it works:** You opt-in, receive communications, can withdraw anytime

**Examples:**
- Marketing emails ("new products we think you'd like")
- Cookies and tracking (non-essential)
- Health information (for hardship assessment)

## 4. Special Categories of Data (Article 9)

We may process special category data (sensitive personal information):

**Special categories we might process:**
- **Health data:** Disability, illness, medical conditions (relevant to hardship assessment)
- **Racial/ethnic origin:** Only for diversity monitoring (optional, you control)
- **Biometric data:** ID verification (fingerprint, facial recognition — if you permit)

**Our safeguards for special categories:**
- **Explicit consent** required (you actively agree)
- **Extra encryption:** Enhanced security
- **Limited access:** Only necessary staff
- **No sharing:** Not disclosed unless legal requirement
- **Shorter retention:** Deleted when no longer needed

**You have right to refuse:** You can refuse to provide special category data; we'll still consider your application if legally possible.

## 5. UK GDPR Articles — Your Rights (Articles 12-22)

### Article 12 — Right to Be Informed

You have right to know:
- **Who we are** (identity, contact of DPO)
- **What we collect** (types of data)
- **Why we collect** (purpose, legal basis)
- **How we use** (processing activities)
- **Who we share with** (recipients)
- **Your rights** (what you can ask us to do)
- **How long we keep** (retention period)

**This Privacy Notice provides all this information.**

### Article 13/14 — Right of Access (Subject Access Request — SAR)

You can request a copy of your personal data:

**How to request:**
- Email: {{sar_request_email}} (preferred, with "Subject Access Request" in subject line)
- Letter: {{sar_mailing_address}}, marked "Subject Access Request"
- In person: {{office_address}}
- Use SAR form: {{sar_form_url}} (optional)

**What to include:**
- Your full name
- Your contact details (email, phone)
- Description of data requested ("all data" or specific categories)
- Proof of identity (ID copy, recent bill, or passport)

**Our response:**
- **Acknowledgment:** 5 working days
- **Full response:** 30 calendar days (can extend 60 more if complex)
- **Format:** Typically PDF/printed letter, in understandable English
- **Content:** All personal data we hold, purposes, recipients, retention period
- **No cost:** Free (first request per 12 months free; additional requests may incur £10-20 administrative fee)

**Exemptions (we can withhold):**
- Data would prejudice someone else's privacy
- Data protected by legal privilege (attorney-client confidentiality)
- Data from a third party who would be harmed by disclosure

**Data subjects can:** Access their own data freely; third-party data requires consent/legal justification

### Article 16 — Right to Rectification

You can request correction of inaccurate data:

**How to request:**
- Contact: {{sar_request_email}} or {{dpo_email}}
- Include: what data is wrong, what it should say

**Our response:**
- We investigate within 30 days
- If wrong: we correct and confirm
- If accurate: we explain why (you can add disagreement note)
- We notify third parties we disclosed to (where practical)

**Example:** "You have my employment as 'Engineer' but I'm actually an 'Engineering Manager'" → we correct

### Article 17 — Right to Erasure ("Right to Be Forgotten")

You can request deletion of your data:

**You can request deletion if:**
- Data no longer needed for original purpose
- You withdraw consent (we were processing on consent basis)
- You object to processing (we have no overriding interest)
- Data was unlawfully processed
- Legal obligation requires deletion
- You're a child (and no other legal basis exists)

**We DON'T have to delete if:**
- **Legal obligation:** Law requires us to keep (tax records, AML/CTF, financial regulations)
- **Contract:** Needed to fulfill the mortgage agreement
- **Legal claim:** Needed as evidence for disputes/litigation
- **Public interest:** Needed for important public purpose
- **Legitimate interests:** We have compelling reason to keep (fraud prevention, legal defense)

**Example:** You can request deletion of marketing data if you opt-out; we'll delete. But we can't delete application data (needed for legal/tax purposes).

**Our response:**
- 30 days to delete (or explain why not)
- Confirmation of deletion
- Notification to third parties (where practical)

### Article 18 — Right to Restrict Processing

You can ask us to limit how we process your data:

**Restrictions you can request:**
- **Storage only:** Keep data but don't actively use it
- **While verifying:** Don't use while we check accuracy
- **While assessing legality:** Don't use while we assess if processing is legal
- **Pending objection:** Don't use while your objection is considered

**Effect:** We can't use restricted data except:
- With your consent
- For legal claims
- To protect someone's rights
- For important public interest

**Example:** You dispute a payment — you can restrict processing while we investigate.

### Article 20 — Right to Data Portability

You can get your data in a portable, machine-readable format:

**Applies to data you:**
- Provided to us (not all data we hold)
- Gave us with consent
- Provided under contract

**Format:** CSV, JSON, XML, PDF — you specify

**Timeline:** 30 days

**Use:** You can transfer to another provider or keep for your records

**Example:** You can get all your financial data we hold in CSV format to analyze yourself or use with another provider.

**Note:** Doesn't apply to data we derived (assessments, scores we calculated) — only data you gave us.

### Article 21 — Right to Object

You can object to processing based on legitimate interests or for direct marketing:

**Objecting to direct marketing (absolute right):**
- You can object to ANY marketing communication
- We must stop immediately (no ifs/buts)
- No need to justify
- Email: {{optout_email}} or click unsubscribe link

**Objecting to other legitimate interests processing:**
- You can object (e.g., profiling, analytics)
- We have 30 days to respond
- We can only continue if we have compelling legal interest
- We'll explain why we're continuing (or stop)

**Effect:** If we stop: your data no longer processed for that purpose. If we continue: we'll explain why.

### Article 22 — Rights Related to Automated Decision-Making

You have right not to be subject to automated decisions that significantly affect you:

**Our practice:**
- **No fully automated decisions** on mortgage applications
- **Human review:** Every application reviewed by human before approval/denial
- **Right to explanation:** If decision made mostly by algorithm, you can request explanation
- **Right to appeal:** You can request human review if you disagree with algorithmic decision

**Exceptions:**
- We may use automated checks for fraud detection (necessary for your protection)
- We may use automated scoring (but final decision is human)

**Example:** We may automatically screen applications for fraud; but actual lending decision is made by human underwriter.

## 6. Data Protection Act 2018 (UK-Specific)

The Data Protection Act 2018 adds UK-specific rules to UK GDPR:

**Employment data:**
- Extra protection for employee data (personnel records, payroll)
- Different rules than consumer data

**Law enforcement processing:**
- If we process data for law enforcement (police, courts): special rules apply

**National security:**
- UK government can claim security exemptions (rare, exceptional)

**Our commitment:** We comply with all DPA 2018 requirements.

## 7. Legitimate Interest Assessment (LIA) Summary

When we rely on legitimate interests, we balance:

| Interest | How We Balance | Your Protections |
|---|---|---|
| **Fraud prevention** | Our interest in stopping fraud vs. your privacy | Least invasive monitoring, limited staff access |
| **Underwriting** | Our interest in assessing creditworthiness vs. privacy | Only necessary financial data, no excessive checks |
| **Customer service** | Our interest in supporting you vs. privacy | Only contact you when necessary, respect preferences |
| **Marketing** | Our interest in growing business vs. your preferences | Easy opt-out, no aggressive tactics |
| **Portfolio management** | Our interest in managing risk vs. your privacy | Aggregated analysis, no individual profiling |

**You can object** to any legitimate interests processing (Article 21).

## 8. International Data Transfers (Key Protections)

### A. Transfers to Australia

**Recipients:** Lenders, investment partners
**Safeguards:**
- Standard Contractual Clauses (SCCs) — contracts requiring same protection as UK law
- Adequacy assessment: Australia's Privacy Act is comparable (though not equivalent)
- Supplementary measures: encryption, limited access

**Your rights:**
- Can object to Australia transfer ({{privacy_request_email}})
- If Australian partner breaches: we're liable to you
- Can request we minimize Australia disclosure

### B. Transfers to United States

**Recipients:** Cloud providers (Amazon AWS, Microsoft Azure)
**Risk:** US government can access data via Section 702 (FISA Amendments Act)
**Safeguards:**
- Standard Contractual Clauses (SCCs)
- Schrems II supplementary measures (encryption, sub-processor agreements)
- Transfer Impact Assessment (we assess risk before transfer)
- Data minimization (we limit US-stored data)

**Your rights:**
- Can object to US transfer
- Can request data not stored in US (we'll discuss alternatives)
- If US government accesses: we notify you (where possible)

**Transparency:** We're transparent about US government access risk.

### C. Transfers to EU (Post-Brexit)

**Scenario:** If we transfer data to EU partners
**Safeguards:** EU GDPR assumed equivalent to UK GDPR (adequacy decision)
**Your rights:** Same protections as UK GDPR apply

### D. Adequacy Decisions

**Countries we trust:**
- EU/EEA (GDPR adequacy)
- Australia (comparable privacy law)
- Others on case-by-case (with SCCs)

## 9. Data Retention Schedule (Detailed Table)

| Data Type | Purpose | Retention Period | Legal Basis |
|---|---|---|---|
| **Loan Application** | Contract, regulatory | 6 years post-completion | GDPR Art 6(1)(b) contract |
| **Credit Report** | Underwriting, fraud | 3 years post-application | GDPR Art 6(1)(f) legit interest |
| **Customer Communications** | Dispute resolution, evidence | 3 years post-resolution | GDPR Art 6(1)(c) legal obligation |
| **Payment Records** | Account management, tax | Loan term + 6 years | GDPR Art 6(1)(c) tax law |
| **Identity Documents** | AML/CTF, KYC compliance | 5 years post-completion | GDPR Art 6(1)(c) AML/CTF Reg |
| **Marketing Consent** | Email/mail compliance | Until consent withdrawn | GDPR Art 6(1)(a) consent |
| **Website Analytics** | Service improvement | 13 months (anonymized after 90 days) | GDPR Art 6(1)(f) legit interest |
| **CCTV** | Security, fraud prevention | 30 days (longer if incident) | GDPR Art 6(1)(f) legit interest |

**Secure disposal:**
- Paper: shredded
- Digital: encrypted deletion
- Devices: degaussed or physically destroyed

## 10. Cookies & Tracking Technologies

**Our use:**
- **Essential:** Login, security (always on, no consent needed)
- **Analytics:** Google Analytics, Hotjar (opt-in via banner)
- **Marketing:** Retargeting ads (opt-in via banner)

**Your choices:**
- Cookie banner on first visit
- Change preferences: {{cookie_settings_link}}
- Browser: disable cookies in settings
- Opt-out: {{global_optout_link}}

## 11. Complaints & Enforcement

### A. Complain to Us First

**Contact:**
- Email: {{complaints_email}}
- Phone: {{complaints_phone}}
- Mail: {{complaints_mailing_address}}

**Our response:**
- Acknowledgment: 5 working days
- Investigation: 30 days
- Response: written decision, explanation, remedy (if applicable)

### B. Complain to ICO (If Unsatisfied)

**Information Commissioner's Office:**
- Website: www.ico.org.uk
- Phone: 0303 123 1113 (local rate)
- Chat: www.ico.org.uk/for-organisations/contact-us
- Mail: Information Commissioner's Office, Wycliffe House, Water Lane, Wilmslow, Cheshire SK9 5AF

**ICO will:**
- Investigate your complaint (free)
- Issue a decision (usually 12-18 months)
- Fine us (up to €20M or 4% annual global turnover)
- Award you compensation (for material/non-material damages)

**Decision types:**
- No breach found
- Breach found; Company ordered to remedy
- Breach found; Company fined and ordered to remedy

**Compensation:** You can claim from us directly for damages (Article 82)

## 12. Your Right to Legal Remedy (Article 82)

**If we breach UK GDPR:**
- You can sue us for damages (material + non-material)
- Example: distress caused by breach, financial loss
- You can claim in UK courts (no cost if pro-bono lawyer)
- You can claim alongside ICO enforcement

**Limitation period:** Typically 5 years from breach

## 13. Changes to This Policy

We may update this Privacy Notice:
- **Minor changes:** posted on website (no notice required)
- **Material changes:** 30 days' advance notice (email)
- **Continued use:** means you accept changes

**Last updated:** {{policy_updated_date}}

**Archive:** Previous versions available on request ({{sar_request_email}})

## 14. Contact Information

**Data Protection Queries:**
- DPO: {{dpo_name}}, {{dpo_email}}, {{dpo_phone}}
- Privacy inquiries: {{privacy_contact_email}}

**Subject Access Requests (SAR):**
- Email: {{sar_request_email}} (preferred)
- Mail: {{sar_mailing_address}}
- Phone: {{sar_phone}}
- **Timeline:** 30 days

**Complaints:**
- Email: {{complaints_email}}
- Phone: {{complaints_phone}}
- **Timeline:** 5 days acknowledgment, 30 days response

**ICO (Independent Regulator):**
- Website: www.ico.org.uk
- Phone: 0303 123 1113
- Chat: www.ico.org.uk/for-organisations/contact-us
- Mail: ICO, Wycliffe House, Water Lane, Wilmslow, Cheshire SK9 5AF

---

**Commitment:** We take privacy seriously. Your data is valuable and deserves protection. Contact us with questions anytime.
CONTENT

# Create all templates
templates = [
  { document_type: "privacy_policy", jurisdiction: "AU", party_type: "universal", template_name: "Privacy Policy - Australia", content: privacy_policy_au },
  { document_type: "terms_conditions", jurisdiction: "AU", party_type: "universal", template_name: "Terms & Conditions - Australia", content: terms_au },
  { document_type: "lender_contract", jurisdiction: "AU", party_type: "lender", template_name: "Lender Agreement - Australia", content: lender_agreement_au },
  { document_type: "privacy_policy", jurisdiction: "US", party_type: "universal", template_name: "Privacy Policy - United States", content: privacy_policy_us },
  { document_type: "terms_conditions", jurisdiction: "US", party_type: "universal", template_name: "Terms & Conditions - United States", content: terms_us },
  { document_type: "privacy_policy", jurisdiction: "NZ", party_type: "universal", template_name: "Privacy Policy - New Zealand", content: privacy_policy_nz },
  { document_type: "privacy_policy", jurisdiction: "UK", party_type: "universal", template_name: "Privacy Policy - United Kingdom", content: privacy_policy_uk }
]

templates.each do |attrs|
  LegalDocumentTemplate.find_or_create_by!(
    document_type: attrs[:document_type],
    jurisdiction: attrs[:jurisdiction],
    party_type: attrs[:party_type],
    template_name: attrs[:template_name]
  ) do |template|
    template.template_content = attrs[:content]
    template.instructions = "Customize variables enclosed in {{double_braces}} for your jurisdiction and organization."
    template.is_active = true
    template.sort_order = 0
  end
end

puts "✅ Legal document templates created successfully!"
puts "   - AU templates: 3"
puts "   - US templates: 2"
puts "   - NZ templates: 1"
puts "   - UK templates: 1"
puts ""
puts "Next: Use LegalDocumentService.setup_jurisdiction(jurisdiction, admin_user) to create documents from templates"
