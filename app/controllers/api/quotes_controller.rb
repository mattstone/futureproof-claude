# API::QuotesController
#
# Unified API for quote calculations supporting multiple calculation models:
#   - original: The current hardcoded lookup tables (demo_webapp_controller.js)
#   - tom: Tom's model from QuoteService (total income lookup)
#   - pavel: Pavel's model from QuoteService (annuity rate based)
#   - python: Full Python Monte Carlo simulation
#
# Usage:
#   GET /api/quotes?home_value=1500000&term=10&model=pavel
#   GET /api/quotes?home_value=2000000&term=15&model=python&paths=1000
#
class Api::QuotesController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :verify_request_origin, unless: -> { Rails.env.test? }
  before_action :rate_limit_check, unless: -> { Rails.env.test? }

  # GET /api/quotes
  def show
    home_value = params[:home_value]&.to_f || 1_500_000
    term = params[:term]&.to_i || 10
    model = params[:model]&.to_sym || QuoteService::DEFAULT_MODEL
    mortgage_type = params[:mortgage_type] || 'interest_only'

    begin
      result = case model
               when :original
                 calculate_original(home_value, term, mortgage_type)
               when :tom
                 calculate_tom(home_value, term)
               when :pavel
                 calculate_pavel(home_value, term)
               when :python
                 calculate_python(home_value, term, mortgage_type)
               else
                 raise ArgumentError, "Unknown model: #{model}. Supported: original, tom, pavel, python"
               end

      render json: {
        success: true,
        model: model.to_s,
        inputs: {
          home_value: home_value,
          term_years: term,
          mortgage_type: mortgage_type
        },
        result: result
      }
    rescue => e
      Rails.logger.error "Quote calculation failed: #{e.message}"
      render json: {
        success: false,
        error: e.message
      }, status: :unprocessable_entity
    end
  end

  # GET /api/quotes/compare
  # Compare all models side-by-side
  def compare
    home_value = params[:home_value]&.to_f || 1_500_000
    term = params[:term]&.to_i || 10
    mortgage_type = params[:mortgage_type] || 'interest_only'

    results = {}

    # Calculate with each model
    [:original, :tom, :pavel].each do |model|
      begin
        results[model] = case model
                         when :original
                           calculate_original(home_value, term, mortgage_type)
                         when :tom
                           calculate_tom(home_value, term)
                         when :pavel
                           calculate_pavel(home_value, term)
                         end
      rescue => e
        results[model] = { error: e.message }
      end
    end

    # Only include Python if explicitly requested (it's slow)
    if params[:include_python] == 'true'
      begin
        results[:python] = calculate_python(home_value, term, mortgage_type)
      rescue => e
        results[:python] = { error: e.message }
      end
    end

    render json: {
      success: true,
      inputs: {
        home_value: home_value,
        term_years: term,
        mortgage_type: mortgage_type
      },
      results: results,
      comparison: build_comparison(results)
    }
  end

  # GET /api/quotes/models
  # List available models and their descriptions
  def models
    render json: {
      models: {
        original: {
          name: "Original (Demo)",
          description: "Hardcoded lookup tables from demo_webapp_controller.js",
          speed: "instant",
          supports_monte_carlo: false
        },
        tom: {
          name: "Tom's Model (legacy)",
          description: "Legacy total income lookup table for $1.5M base property. Not validated — comparison only.",
          speed: "instant",
          supports_monte_carlo: false,
          info: QuoteService.model_info(:tom)
        },
        pavel: {
          name: "Pavel's Model v14d Optimised (default)",
          description: "Annuity rate based, 50,000-path Monte Carlo validated",
          speed: "instant",
          supports_monte_carlo: false,
          info: QuoteService.model_info(:pavel)
        },
        python: {
          name: "Python Monte Carlo",
          description: "Full Monte Carlo simulation with price paths",
          speed: "slow (1-5 seconds)",
          supports_monte_carlo: true,
          default_paths: 1000
        }
      }
    }
  end

  # GET /api/quotes/regional
  # Region-aware quote using CalculationEngine
  def regional
    home_value = params[:home_value]&.to_f || 1_500_000
    term = params[:term]&.to_i || 10
    region = params[:region]&.downcase || "us"
    model = params[:model]&.to_sym || :pavel

    begin
      engine = CalculationEngine.new(
        home_value: home_value,
        term: term,
        region: region,
        model: model
      )

      render json: { success: true, data: engine.calculate }
    rescue ArgumentError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "Regional quote failed: #{e.message}"
      render json: { success: false, error: "Calculation error" }, status: :internal_server_error
    end
  end

  # GET /api/regions
  # List supported regions and their configurations
  def regions
    render json: {
      success: true,
      regions: RegionHelper::VALID_REGION_CODES.map { |code| CalculationEngine.for_region(code) }
    }
  end

  private

  # Original model - matches demo_webapp_controller.js lookup tables (Tom's model)
  # P&I variant applies the legacy demo factor to interest-only values
  # (EpmModelConfig::PI_INCOME_FACTOR)
  def calculate_original(home_value, term, mortgage_type)
    result = QuoteService.quote(home_value: home_value, term: term, model: :tom)
    lvr = EpmModelConfig.params[:max_ltv]

    monthly = result[:monthly_income]
    if mortgage_type == 'principal_and_interest'
      monthly = (monthly * EpmModelConfig::PI_INCOME_FACTOR).round(0)
    end

    annual = (monthly * 12).round(0)
    total = (annual * term).round(0)

    {
      monthly_income: monthly,
      annual_income: annual,
      total_income: total,
      loan_balance_at_end: mortgage_type == 'principal_and_interest' ? 0 : result[:max_loan],
      lvr: lvr,
      max_loan: result[:max_loan],
      base_property_value: QuoteService::BASE_PROPERTY_VALUE,
      multiplier: (home_value.to_f / QuoteService::BASE_PROPERTY_VALUE).round(4)
    }
  end

  # Tom's model - from QuoteService
  def calculate_tom(home_value, term)
    result = QuoteService.quote(home_value: home_value, term: term, model: :tom)

    {
      monthly_income: result[:monthly_income],
      annual_income: result[:annual_income],
      total_income: result[:total_income],
      loan_balance_at_end: result[:max_loan], # Interest-only, so loan balance = original loan
      lvr: result[:lvr],
      max_loan: result[:max_loan],
      annuity_rate: result[:annuity_rate]
    }
  end

  # Pavel's model - from QuoteService
  def calculate_pavel(home_value, term)
    result = QuoteService.quote(home_value: home_value, term: term, model: :pavel)

    {
      monthly_income: result[:monthly_income],
      annual_income: result[:annual_income],
      total_income: result[:total_income],
      loan_balance_at_end: 0, # P+I, so loan is paid off
      lvr: result[:lvr],
      max_loan: result[:max_loan],
      annuity_rate: result[:annuity_rate]
    }
  end

  # Python Monte Carlo model
  def calculate_python(home_value, term, mortgage_type)
    paths = params[:paths]&.to_i || 1000
    loan_type = mortgage_type == 'principal_and_interest' ? 'Principal and interest' : 'Interest only'

    # Calculate annual income based on Pavel's rate for now
    # (The Python model uses annual_income as input)
    pavel_result = QuoteService.quote(home_value: home_value, term: term, model: :pavel)
    annual_income = pavel_result[:annual_income]

    begin
      ep = EpmModelConfig.params
      service = PythonMonteCarloService.new({
        house_value: home_value,
        loan_duration: ep[:tenure_years],
        annuity_duration: term,
        loan_type: loan_type,
        loan_to_value: ep[:max_ltv] * 100, # PythonMonteCarloService expects percentage
        annual_income: annual_income,
        total_paths: paths,
        random_seed: 42 # For reproducibility
      })

      result = service.calculate

      lvr = EpmModelConfig.params[:max_ltv]
      {
        monthly_income: (annual_income / 12.0).round(0),
        annual_income: annual_income,
        total_income: (annual_income * term).round(0),
        lvr: lvr,
        max_loan: (home_value * lvr).round(0),
        monte_carlo: {
          paths: paths,
          execution_time_seconds: result[:execution_time],
          mean_final_reinvestment: result[:statistics][:mean],
          std_dev: result[:statistics][:std_dev],
          percentiles: result[:statistics][:percentiles],
          prob_deficit: result[:statistics][:prob_deficit]
        }
      }
    rescue => e
      # Python not available or failed - return basic calculation with error info
      Rails.logger.warn "Python Monte Carlo failed: #{e.message}"
      lvr = EpmModelConfig.params[:max_ltv]
      {
        monthly_income: (annual_income / 12.0).round(0),
        annual_income: annual_income,
        total_income: (annual_income * term).round(0),
        lvr: lvr,
        max_loan: (home_value * lvr).round(0),
        monte_carlo: {
          error: "Python Monte Carlo service unavailable: #{e.message}",
          note: "Install numpy and pandas in Python environment to enable Monte Carlo"
        }
      }
    end
  end

  def build_comparison(results)
    comparison = {}

    # Extract monthly income from each model
    monthly_incomes = {}
    results.each do |model, data|
      next if data[:error]
      monthly_incomes[model] = data[:monthly_income]
    end

    # Calculate differences relative to original
    if monthly_incomes[:original]
      baseline = monthly_incomes[:original].to_f
      comparison[:vs_original] = {}

      monthly_incomes.each do |model, income|
        next if model == :original
        diff = income - baseline
        pct = ((income / baseline) - 1) * 100
        comparison[:vs_original][model] = {
          difference: diff.round(0),
          percentage: "#{pct >= 0 ? '+' : ''}#{pct.round(1)}%"
        }
      end
    end

    comparison
  end

  def verify_request_origin
    allowed_origins = [
      Rails.application.routes.default_url_options[:host],
      request.host,
      'localhost',
      '127.0.0.1'
    ].compact.uniq

    referer = request.referer
    origin = request.headers['Origin']

    valid_referer = referer && allowed_origins.any? { |domain| referer.include?(domain) }
    valid_origin = origin && allowed_origins.any? { |domain| origin.include?(domain) }
    same_origin = request.host && (
      (referer && referer.include?(request.host)) ||
      (origin && origin.include?(request.host))
    )

    unless valid_referer || valid_origin || same_origin
      Rails.logger.warn "API request blocked - Invalid origin"
      render json: { error: 'Unauthorized request origin' }, status: :forbidden
      return false
    end
  end

  def rate_limit_check
    cache_key = "api_quotes_rate_limit:#{request.remote_ip}"
    request_count = Rails.cache.read(cache_key) || 0

    max_requests = 100
    time_window = 1.minute

    if request_count >= max_requests
      render json: { error: 'Rate limit exceeded' }, status: :too_many_requests
      return false
    end

    Rails.cache.write(cache_key, request_count + 1, expires_in: time_window)
  end
end
