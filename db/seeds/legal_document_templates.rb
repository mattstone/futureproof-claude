# Legal Document Templates - All Jurisdictions
# Run with: rails runner "require './db/seeds/legal_document_templates.rb'"

puts "Creating legal document templates for all jurisdictions..."

# Privacy Policy - Australia
privacy_policy_au = <<~CONTENT
## 1. Introduction

Futureproof Financial Group Limited (ABN: {{abn}}) ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you visit our website or use our services, including our Equity Preservation Mortgage® products.

We comply with the Privacy Act 1988 (Cth) and the Privacy (Australian Government Personnel) Act 1988.

## 2. Information We Collect

We may collect the following types of personal information:
- Contact information (name, email address, phone number, mailing address)
- Property information (address, estimated value, title)
- Financial information (income, assets, liabilities)
- Identity verification documents (driver's license, passport)
- Credit information (with your consent)
- Communication records and preferences

## 3. How We Use Your Information

We use your information for:
- Processing and evaluating mortgage applications
- Providing customer service and support
- Conducting risk assessments and fraud prevention
- Complying with legal and regulatory requirements (ASIC, AML/CTF Act)
- Improving our website and services
- Marketing and promotional activities (with your consent)

## 4. Information Sharing

We may share your information with:
- **Service Providers:** Third parties assisting us in providing services
- **Wholesale Funders:** Approved funding partners
- **Regulators:** ASIC, ABA, and other relevant authorities
- **Legal Authorities:** When required by law

## 5. Data Security

We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.

## 6. Your Rights

You have the right to:
- Access and review your personal information
- Request corrections to inaccurate information
- Opt-out of marketing communications
- Lodge a complaint with the Office of the Australian Information Commissioner (OAIC)

## 7. Contact Us

**Privacy Officer:**
Futureproof Financial Group Limited
Email: privacy@futureprooffinancial.com.au
Address: {{contact_address}}
CONTENT

# Terms & Conditions - Australia
terms_au = <<~CONTENT
## 1. Agreement Overview

These Terms and Conditions ("Terms") govern your use of services provided by Futureproof Financial Group Limited ("Company," "we," "our," or "us").

By accessing or using our services, you agree to be bound by these Terms. If you do not agree, please do not use our services.

## 2. Equity Preservation Mortgage (EPM®) Explanation

Our Equity Preservation Mortgage is a financial product where:
- You retain ownership of your property
- You take out a mortgage against your property
- The mortgage funds are invested
- You receive monthly guaranteed income from investment returns
- You make no monthly loan repayments
- The loan is repaid when your property is sold or on your passing
- Your equity is protected under the No Negative Equity Guarantee (NNEG)

## 3. Applicable Law

These Terms are governed by and construed in accordance with the laws of Queensland, Australia, and the Commonwealth of Australia.

## 4. Regulatory Compliance

This product is regulated by the Australian Securities and Investments Commission (ASIC). We hold appropriate Australian Financial Services Licence (AFSL).

## 5. Disclaimers

- Investment returns are not guaranteed; past performance is not indicative of future results
- Property valuations may change
- This is not financial advice; seek independent advice before proceeding
- The product involves risk; review our Product Disclosure Statement (PDS)

## 6. Limitation of Liability

To the extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages.

## 7. Contact

For inquiries: {{contact_email}}
CONTENT

# Lender Agreement - Australia
lender_agreement_au = <<~CONTENT
## 1. Agreement Between Parties

This Lender Agreement ("Agreement") is entered into between:
- **Futureproof Financial Group Limited** (ABN: {{abn}}) ("Company")
- **{{lender_name}}** ("Lender")

## 2. Obligations of the Lender

The Lender agrees to:
- Provide mortgage funds as outlined in approved applications
- Maintain portfolio management standards per our guidelines
- Submit monthly performance reports
- Comply with ASIC guidelines and regulatory requirements
- Respect the No Negative Equity Guarantee (NNEG)

## 3. Return Calculations

The Lender shall receive:
- Monthly margin of {{margin_percentage}}% on mortgage balance
- Quarterly distribution statements
- Annual consolidated reporting

## 4. Term

This Agreement commences on {{effective_date}} and continues until terminated by either party with 90 days' written notice.

## 5. Termination

Upon termination:
- Outstanding mortgages remain in force
- Final distributions calculated and paid within 30 days
- All documentation returned or destroyed as requested

## 6. Confidentiality

Both parties agree to maintain confidentiality of proprietary information for 5 years post-termination.

## 7. Governing Law

This Agreement is governed by Queensland law and Commonwealth financial services laws.
CONTENT

# Privacy Policy - US
privacy_policy_us = <<~CONTENT
## 1. Introduction & Compliance

Futureproof Financial Group ("we," "us," or "our") is committed to protecting your privacy. This Privacy Policy explains our information collection and use practices.

We comply with applicable US federal and state privacy laws, including:
- Fair Information Practice Principles (FIPP)
- State-specific privacy laws (CCPA, VCCPA, etc.)
- Gramm-Leach-Bliley Act (GLBA)
- Fair Credit Reporting Act (FCRA)

## 2. Information Collection

**Directly Provided:**
- Contact and identity information
- Property details and valuations
- Financial information
- Application documents

**Automatically Collected:**
- Browser and device information
- IP addresses
- Website usage analytics
- Cookies and tracking technologies

## 3. Use of Information

We use your information to:
- Process EPM applications and underwriting
- Manage customer accounts and communications
- Perform credit checks (with authorization)
- Comply with federal and state regulations
- Detect and prevent fraud
- Maintain and improve our services

## 4. Information Sharing

We may disclose information to:
- **Service Providers** (underwriters, appraisers, title companies)
- **Financial Institutions** (lenders, investment partners)
- **Government Agencies** (when required by law)
- **Legal Representatives** (in connection with legal proceedings)

We do not sell personal information to third parties.

## 5. California Privacy Rights (CCPA/CPRA)

If you are a California resident, you have the right to:
- Know what personal information is collected
- Delete personal information (with exceptions)
- Opt-out of data sales (we don't sell data)
- Non-discrimination for exercising your rights

To exercise these rights, contact: {{privacy_contact_email}}

## 6. Data Security

We implement reasonable administrative, technical, and physical safeguards to protect your personal information from unauthorized access, disclosure, modification, or destruction.

## 7. Contact Information

**Privacy Officer:**
{{company_name}}
{{street_address}}
{{city}}, {{state}} {{zip}}
Email: {{privacy_contact_email}}
CONTENT

# Terms & Conditions - US
terms_us = <<~CONTENT
## 1. Terms and Conditions Agreement

These Terms and Conditions ("Terms") constitute a binding agreement between Futureproof Financial Group ("Company") and you ("User").

**PLEASE READ THESE TERMS CAREFULLY BEFORE USING OUR SERVICES.**

## 2. Equity Preservation Mortgage (EPM) Product Description

The EPM is a specialized mortgage product with these characteristics:
- Borrower retains property ownership
- Mortgage is secured against the property
- Mortgage proceeds are invested
- Borrower receives monthly guaranteed income (typically 1.5% p.a. of property value)
- No monthly loan repayments required
- Loan repaid upon property sale or owner passing
- Protected by No Negative Equity Guarantee (NNEG)

## 3. Product Disclosures

**Important:** This is not a traditional mortgage. Key differences:
- No monthly principal or interest payments
- Income payments (not loan payments)
- Income stream vs. debt reduction
- Restricted home sale requirements per agreement
- See Product Disclosure Statement (PDS) for full details

## 4. State Law Compliance

This product and these Terms comply with applicable state laws where the property is located, including:
- State lending regulations
- Disclosure requirements
- Foreclosure protection laws
- Homeowner rights protections

## 5. Assumptions and Disclaimers

**NO WARRANTY:** Investment returns are NOT guaranteed. Market conditions affect returns.

**RISK DISCLOSURE:** This product carries investment and market risks. Property values may decline. Investment performance varies.

**NOT FINANCIAL ADVICE:** This is a product offering, not financial advice. Consult independent professionals (attorney, financial advisor, tax advisor).

## 6. Limitation of Liability

To the maximum extent permitted by law:
- We are not liable for indirect, incidental, or consequential damages
- Our total liability is limited to amounts paid under the agreement
- These limitations do not apply to fraud or gross negligence

## 7. Governing Law

These Terms are governed by the laws of {{state_of_property}}, without regard to conflict of law principles. Any legal action must be brought in the federal or state courts located in {{jurisdiction_county}}.

## 8. Contact Us

{{company_name}}
{{address}}
{{phone}}
{{email}}
CONTENT

# Privacy Policy - New Zealand
privacy_policy_nz = <<~CONTENT
## 1. Kia Te Haumaru (Privacy Statement)

Futureproof Financial Group Limited ("we," "us," "our") is committed to protecting your privacy. This Privacy Policy explains how we comply with the Privacy Act 2020 (Aotearoa New Zealand).

## 2. Information Collection

We collect personal information including:
- Contact information (name, address, email, phone)
- Property details (address, valuation)
- Financial information (income, assets)
- Identity documents (NZ driver's license, passport)
- Credit information (with your consent)

## 3. Information Use

We use your information to:
- Process EPM applications
- Manage customer relationships
- Conduct credit assessments
- Comply with NZ financial services laws
- Provide excellent customer service

## 4. Privacy Rights Under Privacy Act 2020

You have rights to:
- Access your personal information
- Request corrections
- Understand how your information is used
- Lodge a complaint with the Privacy Commissioner

## 5. Overseas Disclosure

We may disclose information to:
- Australian investment partners
- US-based service providers
- UK-based compliance consultants

These entities may not have the same privacy protections as NZ law.

## 6. Contact

**Privacy Officer:**
Futureproof Financial Group NZ Limited
{{nz_address}}
Email: privacy@futureproof.co.nz

**Privacy Commissioner:**
Office of the Privacy Commissioner
{{auckland_address}}
CONTENT

# Privacy Policy - UK
privacy_policy_uk = <<~CONTENT
## 1. Data Protection Notice

Futureproof Financial Group ("we," "us," "our") is committed to protecting your personal data. This Privacy Notice explains how we comply with UK data protection law, including the UK GDPR and Data Protection Act 2018.

**Data Controller:** Futureproof Financial Group Limited
**ICO Registration:** {{ico_registration_number}}

## 2. Personal Data Collection

We collect:
- Identification information (name, address, ID documents)
- Contact details (email, phone, postal address)
- Property information (address, estimated value, title documents)
- Financial information (income, assets, liabilities)
- Credit information (with explicit consent)

## 3. Lawful Basis for Processing

We process your data under:
- **Legitimate Interests:** Assessing applications, managing accounts
- **Legal Obligation:** FCA regulations, AML/CTF compliance
- **Contract:** To provide EPM product
- **Consent:** Marketing communications

## 4. Data Retention

We retain your personal data:
- **During Application:** Until resolved or withdrawn
- **After Application:** 6 years for regulatory compliance
- **Marketing:** Until you opt-out

## 5. Your Data Rights

Under UK GDPR/DPA 2018, you have rights to:
- Right of access (subject access request)
- Right to rectification
- Right to erasure ("right to be forgotten")
- Right to restrict processing
- Right to data portability
- Right to object
- Rights related to automated decision-making

**To exercise rights:** Submit request to {{data_protection_contact}}

## 6. International Transfers

We may transfer your data to:
- Australian service providers
- US-based technology partners
- These transfers use Standard Contractual Clauses (SCCs)

## 7. Contact Details

**Data Protection Officer:**
{{dpo_name}}
Email: {{dpo_email}}

**Information Commissioner's Office (ICO):**
{{ico_address}}
www.ico.org.uk
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
