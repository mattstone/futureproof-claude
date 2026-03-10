# Service for EPM-specific jurisdiction rules and validations
# Enforces regulatory compliance, tax treatment, and income guarantees per jurisdiction
#
# EPM (Equity Partnership Mortgage) model:
# - Customer OWNS property
# - Takes mortgage ON property (uses it as collateral)
# - Mortgage money is INVESTED
# - Customer receives MONTHLY GUARANTEED INCOME (not repayments)
# - No monthly payments — only repaid at sale/death
# - Protected by NNEG (No Negative Equity Guarantee)

class EpmJurisdictionService
  include JurisdictionValidation

  # Jurisdiction-specific EPM rules
  JURISDICTION_RULES = {
    'AU' => {
      name: 'Australia',
      currency: 'AUD',
      currency_symbol: 'A$',
      regulatory_body: 'ASIC',
      licensing: 'AFSL (Australian Financial Services Licence)',
      
      # EPM-specific: Income treatment (tax-free as return of capital)
      income_treatment: 'Tax-free return of capital (ATO guideline)',
      income_tax_rate: 0,  # EPM income is generally not taxable
      
      # NNEG minimum equity protection
      nneg_protection: 'Guaranteed — mortgage cannot exceed property value',
      nneg_guarantee_percentage: 100,
      
      # Income guarantee
      guaranteed_income_minimum: 1.5,  # 1.5% p.a. minimum guaranteed
      
      # Property constraints for EPM
      min_property_value: 500_000,    # A$500k minimum property value
      max_property_value: 10_000_000, # A$10m maximum
      max_ltv: 0.80,                  # Max 80% LTV
      
      # EPM-specific regulations
      interest_only_prohibited: false,  # Can have interest-only mortgages
      equity_release_allowed: true,
      regulations: [
        'National Consumer Credit Protection Act (NCCPA)',
        'Corporations Act 2001 (Cth)',
        'ASIC Regulatory Guide 176'
      ],
      
      # Lender requirements for EPM
      required_lender_licenses: ['AFSL'],
      required_kyc: true,
      required_aml_check: true,
      
      # Income distribution frequency
      income_distribution_frequency: 'monthly',
      
      # NNEG clawback on sale
      nneg_clawback_on_sale: true,  # Customer repays any shortfall on sale
      
      # Min age for EPM (must be old enough to benefit from income)
      min_borrower_age: 55,
      max_borrower_age: nil,
      
      # Death/insolvency handling
      estate_distribution: 'Mortgage repaid from estate, remaining to heirs',
      insolvency_treatment: 'Mortgage treated as secured debt'
    },
    
    'US' => {
      name: 'United States',
      currency: 'USD',
      currency_symbol: '$',
      regulatory_body: 'CFPB',
      licensing: 'NMLS (Nationwide Multistate Licensing)',
      
      # EPM-specific: Income treatment (may be tax-advantaged under IRS)
      income_treatment: 'Consult tax advisor — may qualify for special treatment under IRC §1033',
      income_tax_rate: 0.15,  # Estimate, varies by individual
      
      # NNEG protection (required for EPMs in US)
      nneg_protection: 'Guaranteed by lender',
      nneg_guarantee_percentage: 100,
      
      # Income guarantee
      guaranteed_income_minimum: 1.5,  # 1.5% p.a. minimum
      
      # Property constraints
      min_property_value: 500_000,     # $500k minimum
      max_property_value: 10_000_000,  # $10m maximum
      max_ltv: 0.80,
      
      # EPM regulations
      interest_only_prohibited: false,
      equity_release_allowed: true,
      regulations: [
        'Truth in Lending Act (TILA)',
        'Equal Credit Opportunity Act (ECOA)',
        'Fair Housing Act',
        'SEC Rule 506 (accredited investor requirement may apply)'
      ],
      
      # Lender requirements
      required_lender_licenses: ['NMLS'],
      required_kyc: true,
      required_aml_check: true,
      
      # Income distribution
      income_distribution_frequency: 'monthly',
      
      # NNEG clawback
      nneg_clawback_on_sale: true,
      
      # Age restrictions
      min_borrower_age: 62,  # Commonly 62+ for equity-release products
      max_borrower_age: nil,
      
      # Estate/insolvency
      estate_distribution: 'Mortgage repaid from estate, remaining to heirs',
      insolvency_treatment: 'Non-recourse — lender cannot pursue beyond property'
    },
    
    'NZ' => {
      name: 'New Zealand',
      currency: 'NZD',
      currency_symbol: 'NZ$',
      regulatory_body: 'FMA',
      licensing: 'FAP (Financial Advice Provider Licence)',
      
      # EPM-specific income treatment
      income_treatment: 'Consult IRD — treatment under IRD guidelines',
      income_tax_rate: 0.20,  # Standard rate, varies
      
      # NNEG protection
      nneg_protection: 'Guaranteed',
      nneg_guarantee_percentage: 100,
      
      # Income guarantee
      guaranteed_income_minimum: 1.5,
      
      # Property constraints
      min_property_value: 500_000,
      max_property_value: 10_000_000,
      max_ltv: 0.80,
      
      # EPM regulations
      interest_only_prohibited: false,
      equity_release_allowed: true,
      regulations: [
        'Crimes Act 1961',
        'Financial Markets Conduct Act 2013',
        'Anti-Money Laundering and Countering Financing of Terrorism Act 2009'
      ],
      
      # Lender requirements
      required_lender_licenses: ['FAP'],
      required_kyc: true,
      required_aml_check: true,
      
      # Income distribution
      income_distribution_frequency: 'monthly',
      
      # NNEG clawback
      nneg_clawback_on_sale: true,
      
      # Age
      min_borrower_age: 60,
      max_borrower_age: nil,
      
      # Estate/insolvency
      estate_distribution: 'Mortgage repaid from estate, remaining to heirs',
      insolvency_treatment: 'Creditors rank below property owner'
    },
    
    'UK' => {
      name: 'United Kingdom',
      currency: 'GBP',
      currency_symbol: '£',
      regulatory_body: 'FCA',
      licensing: 'FCA Authorisation',
      
      # EPM-specific income treatment
      income_treatment: 'Consult HMRC — may qualify for relief under ITA 2007',
      income_tax_rate: 0.20,  # Standard rate
      
      # NNEG protection
      nneg_protection: 'Guaranteed by lender',
      nneg_guarantee_percentage: 100,
      
      # Income guarantee
      guaranteed_income_minimum: 1.5,
      
      # Property constraints
      min_property_value: 300_000,  # £300k minimum (lower for UK)
      max_property_value: 10_000_000,
      max_ltv: 0.80,
      
      # EPM regulations
      interest_only_prohibited: false,
      equity_release_allowed: true,
      regulations: [
        'Mortgage Credit Directive (MCD)',
        'Consumer Rights Act 2015',
        'Unfair Contract Terms Act 1977',
        'FCA Handbook: COBS, FEES'
      ],
      
      # Lender requirements
      required_lender_licenses: ['FCA'],
      required_kyc: true,
      required_aml_check: true,
      
      # Income distribution
      income_distribution_frequency: 'monthly',
      
      # NNEG clawback
      nneg_clawback_on_sale: true,
      
      # Age
      min_borrower_age: 55,
      max_borrower_age: nil,
      
      # Estate/insolvency
      estate_distribution: 'Mortgage repaid from estate, remaining to heirs',
      insolvency_treatment: 'Secured creditor — ranks above unsecured creditors'
    }
  }.freeze

  def initialize(jurisdiction_code)
    @jurisdiction_code = JurisdictionValidation.normalize_jurisdiction(jurisdiction_code)
    @rules = JURISDICTION_RULES[@jurisdiction_code]
    
    raise InvalidJurisdictionError, "Unknown jurisdiction: #{jurisdiction_code}" unless @rules
  end

  # Get all rules for jurisdiction
  def rules
    @rules
  end

  # Validate application against jurisdiction rules
  def validate_application(application)
    errors = []
    
    # Jurisdiction consistency
    unless application.region == @jurisdiction_code
      errors << "Application region (#{application.region}) doesn't match jurisdiction (#{@jurisdiction_code})"
    end
    
    # Borrower age
    if application.borrower_age && application.borrower_age < @rules[:min_borrower_age]
      errors << "Borrower age (#{application.borrower_age}) below minimum (#{@rules[:min_borrower_age]}) for #{@jurisdiction_code}"
    end
    
    if @rules[:max_borrower_age] && application.borrower_age && application.borrower_age > @rules[:max_borrower_age]
      errors << "Borrower age (#{application.borrower_age}) exceeds maximum (#{@rules[:max_borrower_age]}) for #{@jurisdiction_code}"
    end
    
    # Property value
    if application.home_value < @rules[:min_property_value]
      errors << "Property value (#{@rules[:currency_symbol]}#{application.home_value}) below minimum (#{@rules[:currency_symbol]}#{@rules[:min_property_value]})"
    end
    
    if application.home_value > @rules[:max_property_value]
      errors << "Property value exceeds maximum for #{@jurisdiction_code}"
    end
    
    # LTV
    ltv = application.equity_percentage || 0
    if ltv > (@rules[:max_ltv] * 100)
      errors << "LTV (#{ltv}%) exceeds maximum (#{@rules[:max_ltv] * 100}%)"
    end
    
    # Compliance requirements
    unless application.kyc_submission&.verified?
      errors << "KYC verification required for #{@jurisdiction_code}" if @rules[:required_kyc]
    end
    
    unless application.aml_check&.passed?
      errors << "AML check required for #{@jurisdiction_code}" if @rules[:required_aml_check]
    end
    
    errors
  end

  # Get tax treatment for jurisdiction
  def tax_treatment
    {
      income_treatment: @rules[:income_treatment],
      income_tax_rate: @rules[:income_tax_rate],
      description: "EPM income in #{@jurisdiction_code} is #{@rules[:income_treatment]}"
    }
  end

  # Get NNEG protection details
  def nneg_details
    {
      protected: @rules[:nneg_protection],
      guarantee_percentage: @rules[:nneg_guarantee_percentage],
      clawback_on_sale: @rules[:nneg_clawback_on_sale],
      description: "Customer guaranteed minimum #{@rules[:nneg_guarantee_percentage]}% equity protection"
    }
  end

  # Get compliance requirements
  def compliance_requirements
    {
      regulatory_body: @rules[:regulatory_body],
      licensing: @rules[:licensing],
      required_licenses: @rules[:required_lender_licenses],
      kyc_required: @rules[:required_kyc],
      aml_required: @rules[:required_aml_check],
      regulations: @rules[:regulations]
    }
  end

  # Get income guarantee details (EPM-specific)
  def income_guarantee
    {
      minimum_guaranteed_percentage: @rules[:guaranteed_income_minimum],
      description: "Customer guaranteed minimum #{@rules[:guaranteed_income_minimum]}% p.a. income",
      distribution_frequency: @rules[:income_distribution_frequency],
      note: 'Income from investments, not loan repayments'
    }
  end
end

class InvalidJurisdictionError < StandardError; end
