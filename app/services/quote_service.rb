require "bigdecimal"
require "bigdecimal/util"

# QuoteService - Customer Quote Calculator
#
# Supports two models:
#   - :pavel (DEFAULT — v14d Optimised, Monte Carlo validated)
#   - :tom   (legacy lookup table from the original React webapp demo;
#             kept for comparison only, not validated)
#
# Every quote carries :product_version and :issued_at so a persisted quote
# is reproducible against the exact model that priced it.
#
# Usage:
#   QuoteService.quote(home_value: 1_500_000, term: 10)                    # Uses default model
#   QuoteService.quote(home_value: 1_500_000, term: 10, model: :tom)       # Legacy model
#
class QuoteService
  # Default model - the validated production model
  DEFAULT_MODEL = :pavel

  # Supported annuity terms (years)
  SUPPORTED_TERMS = [ 10, 15, 20, 25, 30 ].freeze

  # Global property value envelope. Region-specific bounds (config/regions.yml)
  # are enforced by CalculationEngine and the Application model; this is the
  # widest envelope any region allows. Out-of-bounds inputs are rejected,
  # never clamped.
  MIN_PROPERTY_VALUE = 300_000
  MAX_PROPERTY_VALUE = 10_000_000
  BASE_PROPERTY_VALUE = 1_500_000

  class << self
    def quote(home_value:, term: 10, model: DEFAULT_MODEL)
      validate_inputs!(home_value, term, model)

      case model.to_sym
      when :pavel
        PavelModel.calculate(home_value: home_value, term: term)
      when :tom
        TomModel.calculate(home_value: home_value, term: term)
      else
        raise ArgumentError, "Unknown model: #{model}. Supported: :pavel, :tom"
      end
    end

    def available_models
      [ :pavel, :tom ]
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

      if home_value < MIN_PROPERTY_VALUE || home_value > MAX_PROPERTY_VALUE
        raise ArgumentError, "home_value must be between #{MIN_PROPERTY_VALUE} and #{MAX_PROPERTY_VALUE}"
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
  # PAVEL'S MODEL — v14d Optimised (current production)
  # =============================================================================
  # All parameters sourced from EpmModelConfig (single source of truth)
  # Source: FutureProofCalculator_Pavel_v14d (Optimised Paramters).xlsm
  # Validated: 50,000-path Monte Carlo simulation (xlsm-verified)
  #
  module PavelModel
    class << self
      def calculate(home_value:, term:)
        rate = EpmModelConfig.annuity_rate(term: term).to_d
        lvr = EpmModelConfig.params[:max_ltv]
        hv = home_value.to_d

        # Money math in BigDecimal; round once at the edge.
        annual_income = (hv * rate).round(0).to_i
        monthly_income = (hv * rate / 12).round(0).to_i
        total_income = (hv * rate * term).round(0).to_i

        {
          model: :pavel,
          model_name: "Pavel's Model v14d Optimised",
          product_version: EpmModelConfig.model_version,
          issued_at: Time.current,
          home_value: home_value,
          term_years: term,
          term_validated: EpmModelConfig.validated_term?(term),
          lvr: lvr,
          max_loan: (hv * lvr.to_d).round(0).to_i,
          monthly_income: monthly_income,
          annual_income: annual_income,
          total_income: total_income,
          annuity_rate: rate.to_f
        }
      end

      def info
        config = EpmModelConfig.model_info
        metrics = EpmModelConfig.risk_metrics

        {
          name: config[:name],
          description: "Monte Carlo validated model (v14d Optimised). P&I + index-linked ETF with asymmetric hedging collar (+40%/-20%).",
          source: config[:source],
          version: config[:version],
          assumptions: {
            base_property_value: QuoteService::BASE_PROPERTY_VALUE,
            lvr: EpmModelConfig.params[:max_ltv],
            loan_type: "Principal+Interest",
            equity_return: "#{(EpmModelConfig.params[:equity_mean] * 100).round(1)}% mean, #{(EpmModelConfig.params[:equity_vol] * 100).round(1)}% vol (GBM + stochastic drift + mean reversion)",
            cash_rate: "#{(EpmModelConfig.params[:cash_rate_initial] * 100).round(2)}% initial, mean-reverting",
            monte_carlo_paths: 50_000
          },
          risk_metrics: {
            prob_deficit_year15: "#{metrics[:pod_yr15].round(0)}%",
            prob_deficit_year30: "#{metrics[:pod_yr30]}%",
            mean_surplus_year30: "$#{metrics[:mean_surplus_yr30].to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
          },
          annuity_rates: config[:annuity_rates],
          validated_terms: config[:validated_terms],
          model_params: EpmModelConfig.params
        }
      end
    end
  end

  # =============================================================================
  # TOM'S MODEL (Legacy - from React webapp demo)
  # =============================================================================
  # Frozen lookup table for a $1.5M base property. NOT Monte Carlo validated.
  # Kept for comparison via the API only; never the default.
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
        lookup = TOTAL_INCOME_LOOKUP[term].to_d
        multiplier = home_value.to_d / QuoteService::BASE_PROPERTY_VALUE

        total_income = (lookup * multiplier).round(0).to_i
        annual_income = (total_income.to_d / term).round(0).to_i
        monthly_income = (annual_income.to_d / 12).round(0).to_i

        {
          model: :tom,
          model_name: "Tom's Model (legacy)",
          product_version: "legacy-tom",
          issued_at: Time.current,
          home_value: home_value,
          term_years: term,
          term_validated: false,
          lvr: DEFAULT_LVR,
          max_loan: (home_value.to_d * DEFAULT_LVR.to_d).round(0).to_i,
          monthly_income: monthly_income,
          annual_income: annual_income,
          total_income: total_income,
          annuity_rate: (annual_income.to_d / home_value.to_d).round(4).to_f
        }
      end

      def info
        {
          name: "Tom's Model (legacy)",
          description: "Legacy model from the React webapp demo. Uses a frozen total income lookup table. Not Monte Carlo validated — comparison only.",
          source: "React webapp calculator",
          version: "legacy-tom",
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
end
