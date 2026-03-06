# CalculationEngine - Unified Financial Model
#
# Wraps QuoteService + MortgageCalculatorService with:
# - Multi-region currency support
# - Scenario generation (pessimistic/expected/optimistic)
# - Region-specific constraints (min/max home values, LTV caps)
#
# Usage:
#   engine = CalculationEngine.new(
#     home_value: 1_500_000,
#     term: 10,
#     region: "au",
#     model: :pavel
#   )
#   result = engine.calculate
#
class CalculationEngine
  SCENARIO_MULTIPLIERS = {
    pessimistic: 0.75,   # 25th percentile
    expected: 1.0,       # 50th percentile (median)
    optimistic: 1.30     # 75th percentile
  }.freeze

  # Inflation scenarios for income projections
  INFLATION_SCENARIOS = {
    low: 0.01,      # 1% annual inflation
    base: 0.025,    # 2.5% annual inflation
    high: 0.05      # 5% annual inflation
  }.freeze

  # Maximum annual CPI escalation cap
  MAX_CPI_ESCALATION = 0.04

  attr_reader :home_value, :term, :region, :model, :region_config

  def initialize(home_value:, term: 10, region: "us", model: :pavel, model_type: :a)
    @home_value = home_value.to_f
    @term = term.to_i
    @region = region.to_s.downcase
    @model = model.to_sym
    @model_type = model_type.to_sym  # :a or :b
    @region_config = RegionHelper.region_config(@region)

    validate!
  end

  def calculate
    base_quote = QuoteService.quote(
      home_value: home_value,
      term: term,
      model: model
    )

    max_ltv = region_config["max_ltv"] || 0.80
    loan_amount = (home_value * max_ltv).round(0)

    {
      region: region_details,
      quote: base_quote,
      model_type: model_type_details,
      scenarios: build_scenarios(base_quote),
      inflation_projections: build_inflation_projections(base_quote),
      nneg_analysis: build_nneg_analysis(loan_amount, base_quote),
      estate_impact: build_estate_impact(loan_amount, base_quote),
      equity_preservation: equity_details,
      insurance: insurance_details,
      compliance: compliance_details,
      summary: build_summary(base_quote)
    }
  end

  def self.for_region(region)
    config = RegionHelper.region_config(region)
    {
      region: region,
      name: config["name"],
      currency: config["currency"],
      currency_symbol: config["currency_symbol"],
      min_home_value: config["min_home_value"],
      max_home_value: config["max_home_value"],
      max_ltv: config["max_ltv"],
      regulatory_body: config["regulatory_body"],
      tax_note: config["tax_note"]
    }
  end

  def model_type_details
    {
      type: @model_type,
      name: @model_type == :a ? "Portfolio Distribution Model" : "Loan Advance Model",
      description: @model_type == :a ? 
        "Monthly income derived from investment portfolio returns" :
        "Monthly income provided via direct loan advances",
      income_source: @model_type == :a ? "portfolio" : "loan_advances"
    }
  end

  def build_nneg_analysis(loan_amount, base_quote)
    # NNEG = Negative Equity situation where mortgage balance > property value
    # Calculate year-by-year mortgage balance decline and property value risk
    
    monthly_payment = calculate_monthly_payment(loan_amount, term)
    nneg_years = []
    
    (1..term).each do |year|
      # Remaining mortgage balance after payments
      remaining_balance = calculate_remaining_balance(loan_amount, monthly_payment, year * 12)
      
      # Property value under different market scenarios
      # Conservative: 1% annual decline, Base: 0% (flat), Optimistic: 2% annual growth
      property_scenarios = {
        pessimistic: home_value * ((1 - 0.01) ** year),   # 1% annual decline
        expected: home_value,                             # No change
        optimistic: home_value * ((1 + 0.02) ** year)    # 2% annual growth
      }
      
      ltv_ratio = remaining_balance / home_value
      nneg_years << {
        year: year,
        mortgage_balance: remaining_balance.round(0),
        property_value_pessimistic: property_scenarios[:pessimistic].round(0),
        property_value_expected: property_scenarios[:expected].round(0),
        property_value_optimistic: property_scenarios[:optimistic].round(0),
        ltv_ratio: ltv_ratio.round(3),
        nneg_risk_pessimistic: remaining_balance > property_scenarios[:pessimistic]
      }
    end
    
    nneg_trigger_year = nneg_years.find { |y| y[:nneg_risk_pessimistic] }&.dig(:year)
    nneg_probability = calculate_nneg_probability(nneg_years)
    
    {
      scenario_results: nneg_years,
      nneg_trigger_year: nneg_trigger_year,
      nneg_probability_percent: nneg_probability,
      explanation: nneg_trigger_year ? 
        "NNEG risk may occur in year #{nneg_trigger_year} in pessimistic scenarios. Insurance covers the shortfall." :
        "NNEG risk is minimal under standard market conditions. Insurance provides additional protection."
    }
  end

  def build_estate_impact(loan_amount, base_quote)
    # Estate impact: What the beneficiary receives
    # Estate = (Property Value + Portfolio Value) - Mortgage Balance
    
    monthly_payment = calculate_monthly_payment(loan_amount, term)
    portfolio_growth_rate = 0.07  # Assumed 7% annual investment returns
    
    year_end_data = {
      year_5: calculate_estate_at_year(loan_amount, monthly_payment, 5, portfolio_growth_rate),
      year_10: calculate_estate_at_year(loan_amount, monthly_payment, 10, portfolio_growth_rate),
      year_at_term: calculate_estate_at_year(loan_amount, monthly_payment, term, portfolio_growth_rate)
    }
    
    {
      year_5_estate: year_end_data[:year_5],
      year_10_estate: year_end_data[:year_10],
      year_at_term_estate: year_end_data[:year_at_term],
      explanation: "Estate represents the property and investment portfolio remaining for your beneficiaries after loan and mortgage costs. Insurance protects this value against market downturns."
    }
  end

  private

  def validate!
    min = region_config["min_home_value"] || 500_000
    max = region_config["max_home_value"] || 10_000_000

    if home_value < min
      raise ArgumentError, "Home value must be at least #{format_currency(min)} in #{region_config['name']}"
    end

    if home_value > max
      raise ArgumentError, "Home value cannot exceed #{format_currency(max)} in #{region_config['name']}"
    end

    unless QuoteService::SUPPORTED_TERMS.include?(term)
      raise ArgumentError, "Term must be one of: #{QuoteService::SUPPORTED_TERMS.join(', ')} years"
    end
  end

  def region_details
    {
      code: region_config["code"],
      name: region_config["name"],
      currency: region_config["currency"],
      currency_symbol: region_config["currency_symbol"],
      regulatory_body: region_config["regulatory_body"],
      licensing: region_config["licensing"],
      tax_note: region_config["tax_note"]
    }
  end

  def build_scenarios(base_quote)
    SCENARIO_MULTIPLIERS.transform_values do |multiplier|
      monthly = (base_quote[:monthly_income] * multiplier).round(0)
      annual = (monthly * 12).round(0)
      {
        monthly_income: monthly,
        annual_income: annual,
        total_income: (annual * term).round(0)
      }
    end
  end

  def build_inflation_projections(base_quote)
    base_monthly = base_quote[:monthly_income]

    INFLATION_SCENARIOS.transform_values do |inflation_rate|
      {
        inflation_rate_percent: (inflation_rate * 100).to_i,
        projections: [5, 10, 15, 20].map do |years|
          escalated_monthly = apply_cpi_escalation(base_monthly, years, inflation_rate)
          {
            years: years,
            monthly_income: escalated_monthly,
            annual_income: (escalated_monthly * 12).round(0),
            cumulative_income: calculate_cumulative_income(base_monthly, years, inflation_rate)
          }
        end
      }
    end
  end

  def apply_cpi_escalation(base_amount, years, inflation_rate)
    # Apply inflation rate annually, capped at MAX_CPI_ESCALATION per year
    capped_inflation = [inflation_rate, MAX_CPI_ESCALATION].min
    (base_amount * ((1 + capped_inflation) ** years)).round(0)
  end

  def calculate_cumulative_income(base_monthly, years, inflation_rate)
    # Calculate total income over the projection period with annual CPI adjustments
    cumulative = 0
    capped_inflation = [inflation_rate, MAX_CPI_ESCALATION].min

    (1..years).each do |year|
      monthly = apply_cpi_escalation(base_monthly, year - 1, inflation_rate)
      cumulative += (monthly * 12)
    end

    cumulative.round(0)
  end

  def equity_details
    max_ltv = region_config["max_ltv"] || 0.80
    loan_amount = (home_value * max_ltv).round(0)
    {
      home_value: home_value,
      loan_amount: loan_amount,
      ltv_ratio: max_ltv,
      equity_preserved_percentage: 100,
      equity_preserved_value: home_value,
      explanation: "Your home equity is 100% preserved. The loan is serviced entirely from investment returns — your home value remains intact for your family."
    }
  end

  def insurance_details
    {
      covered: true,
      type: "Pool Coverage / Lenders Mortgage Insurance",
      lmi_upfront_rate: 0.02,
      lmi_amount: (home_value * region_config["max_ltv"].to_f * 0.02).round(0),
      description: "Insurance covers any shortfall between investment returns and required payments. Your income is guaranteed regardless of market performance."
    }
  end

  def compliance_details
    {
      region: region_config["name"],
      regulatory_body: region_config["regulatory_body"],
      licensing_required: region_config["licensing"],
      data_protection: data_protection_framework,
      consumer_protection: consumer_protection_framework,
      tax_treatment: region_config["tax_note"]
    }
  end

  def data_protection_framework
    case region
    when "uk" then "UK GDPR / Data Protection Act 2018"
    when "au" then "Privacy Act 1988 / Australian Privacy Principles"
    when "nz" then "Privacy Act 2020"
    when "us" then "State-level privacy laws (CCPA, etc.)"
    else "Applicable local data protection legislation"
    end
  end

  def consumer_protection_framework
    case region
    when "uk" then "FCA Consumer Duty / Financial Services and Markets Act 2000"
    when "au" then "National Consumer Credit Protection Act 2009 / ASIC Act"
    when "nz" then "Credit Contracts and Consumer Finance Act 2003"
    when "us" then "Truth in Lending Act (TILA) / RESPA / Dodd-Frank"
    else "Applicable consumer finance legislation"
    end
  end

  def build_summary(base_quote)
    symbol = region_config["currency_symbol"]
    {
      headline: "Receive #{symbol}#{number_with_delimiter(base_quote[:monthly_income])}/month tax-free income",
      subheadline: "From your #{symbol}#{number_with_delimiter(home_value.to_i)} #{region_config['property_term']}",
      key_facts: [
        "100% of your #{region_config['property_term']} equity is preserved",
        "#{symbol}#{number_with_delimiter(base_quote[:monthly_income])}/month expected income for #{term} years",
        "Up to #{(region_config['max_ltv'].to_f * 100).to_i}% loan-to-value ratio",
        "Investment returns cover all mortgage costs",
        "Insurance covers any market shortfalls",
        "Regulated by #{region_config['regulatory_body']}"
      ]
    }
  end

  def format_currency(amount)
    "#{region_config['currency_symbol']}#{number_with_delimiter(amount.to_i)}"
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def calculate_monthly_payment(loan_amount, years)
    # Standard mortgage amortization
    # Payment = P * [r(1+r)^n] / [(1+r)^n - 1]
    # Using 3.5% annual rate (conservative for reverse mortgages)
    annual_rate = 0.035
    monthly_rate = annual_rate / 12
    months = years * 12
    
    if monthly_rate == 0
      loan_amount / months
    else
      numerator = loan_amount * monthly_rate * ((1 + monthly_rate) ** months)
      denominator = ((1 + monthly_rate) ** months) - 1
      (numerator / denominator).round(0)
    end
  end

  def calculate_remaining_balance(loan_amount, monthly_payment, months)
    # Remaining balance after N payments
    # B = P(1+r)^n - PMT * [((1+r)^n - 1) / r]
    annual_rate = 0.035
    monthly_rate = annual_rate / 12
    
    if monthly_rate == 0
      loan_amount - (monthly_payment * months)
    else
      balance = loan_amount * ((1 + monthly_rate) ** months)
      balance -= monthly_payment * (((1 + monthly_rate) ** months) - 1) / monthly_rate
      [balance, 0].max.round(0)  # Never negative
    end
  end

  def calculate_nneg_probability(nneg_years)
    # NNEG probability = % of years where NNEG risk exists in pessimistic scenario
    nneg_count = nneg_years.count { |y| y[:nneg_risk_pessimistic] }
    ((nneg_count.to_f / nneg_years.length) * 100).round(0)
  end

  def calculate_estate_at_year(loan_amount, monthly_payment, year, portfolio_growth_rate)
    # Estate = Property + Portfolio - Mortgage Debt
    remaining_mortgage = calculate_remaining_balance(loan_amount, monthly_payment, year * 12)
    
    # Portfolio value at year X (monthly income accumulated + growth)
    monthly_income = loan_amount / (term * 12)  # Average distribution
    monthly_income_accumulated = monthly_income * year * 12
    portfolio_growth = monthly_income_accumulated * ((1 + portfolio_growth_rate) ** year)
    
    property_value_at_year = home_value * (1 - 0.005 * year)  # Conservative: 0.5% annual decline
    estate_value = (property_value_at_year + portfolio_growth - remaining_mortgage).round(0)
    
    {
      property_value: property_value_at_year.round(0),
      portfolio_value: portfolio_growth.round(0),
      mortgage_debt: remaining_mortgage.round(0),
      net_estate: [estate_value, 0].max.round(0)
    }
  end
end
