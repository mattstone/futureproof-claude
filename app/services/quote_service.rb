# QuoteService - Customer Quote Calculator
#
# Supports two models:
#   - :tom (original model from React webapp)
#   - :pavel (new model from Pavel v5 Excel spreadsheet)
#
# Usage:
#   QuoteService.quote(home_value: 1_500_000, term: 10)                    # Uses default model
#   QuoteService.quote(home_value: 1_500_000, term: 10, model: :tom)       # Tom's model
#   QuoteService.quote(home_value: 1_500_000, term: 10, model: :pavel)     # Pavel's model
#
class QuoteService
  # Default model - change this to switch the entire application
  DEFAULT_MODEL = :tom

  # Supported annuity terms (years)
  SUPPORTED_TERMS = [10, 15, 20, 25, 30].freeze

  # Property value constraints
  MIN_PROPERTY_VALUE = 800_000
  MAX_PROPERTY_VALUE = 10_000_000
  BASE_PROPERTY_VALUE = 1_500_000

  class << self
    def quote(home_value:, term: 10, model: DEFAULT_MODEL)
      validate_inputs!(home_value, term, model)

      case model.to_sym
      when :tom
        TomModel.calculate(home_value: home_value, term: term)
      when :pavel
        PavelModel.calculate(home_value: home_value, term: term)
      else
        raise ArgumentError, "Unknown model: #{model}. Supported: :tom, :pavel"
      end
    end

    def available_models
      [:tom, :pavel]
    end

    def model_info(model)
      case model.to_sym
      when :tom
        TomModel.info
      when :pavel
        PavelModel.info
      end
    end

    private

    def validate_inputs!(home_value, term, model)
      unless home_value.is_a?(Numeric) && home_value > 0
        raise ArgumentError, "home_value must be a positive number"
      end

      unless SUPPORTED_TERMS.include?(term)
        raise ArgumentError, "term must be one of: #{SUPPORTED_TERMS.join(', ')}"
      end

      unless available_models.include?(model.to_sym)
        raise ArgumentError, "model must be one of: #{available_models.join(', ')}"
      end
    end
  end

  # =============================================================================
  # TOM'S MODEL (Original - from React webapp)
  # =============================================================================
  # Based on total income lookup table for $1.5M base property
  # Higher monthly payments, more aggressive assumptions
  #
  module TomModel
    # Total income over the term for a $1.5M property
    # Source: React webapp calculator lookup table
    TOTAL_INCOME_LOOKUP = {
      10 => 300_000,
      15 => 410_468,
      20 => 443_306,
      25 => 498_478,
      30 => 553_088
    }.freeze

    DEFAULT_LVR = 0.80

    class << self
      def calculate(home_value:, term:)
        lookup = TOTAL_INCOME_LOOKUP[term]
        multiplier = home_value.to_f / QuoteService::BASE_PROPERTY_VALUE

        total_income = (lookup * multiplier).round(0)
        annual_income = (total_income.to_f / term).round(0)
        monthly_income = (annual_income.to_f / 12).round(0)

        {
          model: :tom,
          model_name: "Tom's Model",
          home_value: home_value,
          term_years: term,
          lvr: DEFAULT_LVR,
          max_loan: (home_value * DEFAULT_LVR).round(0),
          monthly_income: monthly_income,
          annual_income: annual_income,
          total_income: total_income,
          annuity_rate: (annual_income.to_f / home_value).round(4)
        }
      end

      def info
        {
          name: "Tom's Model",
          description: "Original model from React webapp. Uses total income lookup table.",
          source: "React webapp calculator",
          assumptions: {
            base_property_value: QuoteService::BASE_PROPERTY_VALUE,
            lvr: DEFAULT_LVR,
            loan_type: "Interest-only"
          },
          annuity_rates: TOTAL_INCOME_LOOKUP.transform_values do |total|
            annual = total.to_f / TOTAL_INCOME_LOOKUP.key(total)
            (annual / QuoteService::BASE_PROPERTY_VALUE * 100).round(2)
          end.transform_keys { |k| "#{k}yr" }
        }
      end
    end
  end

  # =============================================================================
  # PAVEL'S MODEL (New - from Pavel v5 Excel spreadsheet)
  # =============================================================================
  # Based on annuity as percentage of home value
  # More conservative assumptions, validated by Monte Carlo
  #
  # Excel source: data/Copy of FutureProofCalculator_Pavel_v5.xlsm
  #
  module PavelModel
    # Annuity rate as percentage of home value (annual)
    # These rates result in ~11% probability of deficit at Year 30
    # with 80% LVR, 10% equity return, 10% volatility
    ANNUITY_RATES = {
      10 => 0.015,    # 1.5% - base case from Excel
      15 => 0.0137,   # Interpolated
      20 => 0.0125,   # Interpolated
      25 => 0.0115,   # Interpolated
      30 => 0.0105    # Interpolated
    }.freeze

    DEFAULT_LVR = 0.80

    # Pavel v5 model parameters (for reference/documentation)
    MODEL_PARAMS = {
      # Interest rate model (Vasicek/Ornstein-Uhlenbeck)
      cash_rate_initial: 0.044,
      cash_rate_mean_rev_level: 0.044,
      cash_rate_mean_rev_speed: 0.8,
      cash_rate_vol: 0.015,

      # Cost structure
      wholesale_margin: 0.02,
      retail_margin: 0.0075,
      hedging_cost: 0.0036,
      fp_margin: 0.0025,
      total_spread: 0.0336,

      # Investment return model (GBM)
      equity_return_mean: 0.10,
      equity_return_vol: 0.10,
      equity_cap: 1.4,
      equity_floor: 0.8,

      # Interest holiday thresholds
      holiday_threshold_entry: 0.9,
      holiday_threshold_exit: 1.458,
      holiday_threshold_repay: 1.5,

      # Insurance
      lmi_upfront: 0.02
    }.freeze

    class << self
      def calculate(home_value:, term:)
        rate = ANNUITY_RATES[term]

        annual_income = (home_value * rate).round(0)
        monthly_income = (annual_income.to_f / 12).round(0)
        total_income = (annual_income * term).round(0)

        {
          model: :pavel,
          model_name: "Pavel's Model",
          home_value: home_value,
          term_years: term,
          lvr: DEFAULT_LVR,
          max_loan: (home_value * DEFAULT_LVR).round(0),
          monthly_income: monthly_income,
          annual_income: annual_income,
          total_income: total_income,
          annuity_rate: rate
        }
      end

      def info
        {
          name: "Pavel's Model",
          description: "Monte Carlo validated model from Pavel v5 Excel spreadsheet. More conservative assumptions.",
          source: "data/Copy of FutureProofCalculator_Pavel_v5.xlsm",
          assumptions: {
            base_property_value: QuoteService::BASE_PROPERTY_VALUE,
            lvr: DEFAULT_LVR,
            loan_type: "Principal+Interest",
            equity_return: "10% mean, 10% vol (GBM)",
            cash_rate: "4.4% initial, mean-reverting",
            monte_carlo_paths: 20_000
          },
          risk_metrics: {
            prob_deficit_year1: "58%",
            prob_deficit_year30: "11%",
            mean_surplus_year30: "$4.6M"
          },
          annuity_rates: ANNUITY_RATES.transform_values { |v| "#{(v * 100).round(2)}%" }
                                      .transform_keys { |k| "#{k}yr" },
          model_params: MODEL_PARAMS
        }
      end
    end
  end
end
