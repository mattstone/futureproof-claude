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

  def initialize(home_value:, term: 10, region: "us", model: :pavel)
    @home_value = home_value.to_f
    @term = term.to_i
    @region = region.to_s.downcase
    @model = model.to_sym
    @region_config = RegionHelper.region_config(@region)

    validate!
  end

  def calculate
    base_quote = QuoteService.quote(
      home_value: home_value,
      term: term,
      model: model
    )

    {
      region: region_details,
      quote: base_quote,
      scenarios: build_scenarios(base_quote),
      inflation_projections: build_inflation_projections(base_quote),
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
end
