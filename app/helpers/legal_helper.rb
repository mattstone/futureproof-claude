module LegalHelper
  REGION_LEGAL_DETAILS = {
    "us" => {
      governing_law: "the laws of the State of New York, United States of America",
      courts: "the federal and state courts located in New York County, New York",
      currency_full: "United States Dollars (USD)",
      regulator: "Consumer Financial Protection Bureau (CFPB)",
      licensing_act: "Nationwide Multistate Licensing System (NMLS)",
      consumer_credit_act: "Truth in Lending Act (TILA), Real Estate Settlement Procedures Act (RESPA), and the Dodd-Frank Wall Street Reform and Consumer Protection Act",
      privacy_act: "California Consumer Privacy Act (CCPA), Gramm-Leach-Bliley Act (GLBA), and applicable state privacy laws",
      aml_act: "Bank Secrecy Act (BSA) and USA PATRIOT Act",
      dispute_resolution: "binding arbitration administered by the American Arbitration Association (AAA) under its Commercial Arbitration Rules",
      cooling_off: "3 business days",
      interest_disclosure: "Annual Percentage Rate (APR) as required by TILA",
      company_registration: "Delaware corporation",
      data_protection_officer: "Privacy Officer",
      complaint_body: "Consumer Financial Protection Bureau (CFPB) at consumerfinance.gov"
    },
    "au" => {
      governing_law: "the laws of the State of New South Wales, Australia",
      courts: "the courts of New South Wales and the Federal Court of Australia",
      currency_full: "Australian Dollars (AUD)",
      regulator: "Australian Securities and Investments Commission (ASIC)",
      licensing_act: "Australian Financial Services Licence (AFSL) under the Corporations Act 2001 (Cth)",
      consumer_credit_act: "National Consumer Credit Protection Act 2009 (Cth) and the National Credit Code",
      privacy_act: "Privacy Act 1988 (Cth) and the Australian Privacy Principles (APPs)",
      aml_act: "Anti-Money Laundering and Counter-Terrorism Financing Act 2006 (Cth)",
      dispute_resolution: "the Australian Financial Complaints Authority (AFCA), Member Number [XXXXXX]",
      cooling_off: "10 business days",
      interest_disclosure: "Comparison Rate as required by the National Credit Code",
      company_registration: "Australian Company Number (ACN)",
      data_protection_officer: "Privacy Officer",
      complaint_body: "Australian Financial Complaints Authority (AFCA) at afca.org.au"
    },
    "nz" => {
      governing_law: "the laws of New Zealand",
      courts: "the courts of New Zealand",
      currency_full: "New Zealand Dollars (NZD)",
      regulator: "Financial Markets Authority (FMA)",
      licensing_act: "Financial Advice Provider Licence under the Financial Markets Conduct Act 2013",
      consumer_credit_act: "Credit Contracts and Consumer Finance Act 2003 (CCCFA)",
      privacy_act: "Privacy Act 2020 and the Information Privacy Principles",
      aml_act: "Anti-Money Laundering and Countering Financing of Terrorism Act 2009",
      dispute_resolution: "the Insurance & Financial Services Ombudsman (IFSO) Scheme or Financial Dispute Resolution Service (FDRS)",
      cooling_off: "5 working days",
      interest_disclosure: "Annual interest rate and total cost of credit as required by the CCCFA",
      company_registration: "New Zealand Companies Office registration number",
      data_protection_officer: "Privacy Officer",
      complaint_body: "Financial Dispute Resolution Service (FDRS) at fdrs.org.nz"
    },
    "uk" => {
      governing_law: "the laws of England and Wales",
      courts: "the courts of England and Wales",
      currency_full: "British Pounds Sterling (GBP)",
      regulator: "Financial Conduct Authority (FCA)",
      licensing_act: "FCA Authorisation under the Financial Services and Markets Act 2000",
      consumer_credit_act: "Consumer Credit Act 1974 (as amended), FCA Consumer Duty, and the Mortgages and Home Finance: Conduct of Business (MCOB) rules",
      privacy_act: "UK General Data Protection Regulation (UK GDPR) and the Data Protection Act 2018",
      aml_act: "Money Laundering, Terrorist Financing and Transfer of Funds (Information on the Payer) Regulations 2017",
      dispute_resolution: "the Financial Ombudsman Service (FOS)",
      cooling_off: "14 calendar days",
      interest_disclosure: "Annual Percentage Rate of Charge (APRC) as required by MCOB",
      company_registration: "Companies House registration number",
      data_protection_officer: "Data Protection Officer (DPO)",
      complaint_body: "Financial Ombudsman Service (FOS) at financial-ombudsman.org.uk"
    }
  }.freeze

  def legal_details(region = nil)
    region ||= @legal_region || "us"
    REGION_LEGAL_DETAILS[region.to_s.downcase] || REGION_LEGAL_DETAILS["us"]
  end

  def legal_date
    Date.current.strftime("%d %B %Y")
  end

  def legal_version
    "1.0"
  end
end
