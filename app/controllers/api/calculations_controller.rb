class Api::CalculationsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :verify_request_origin
  before_action :verify_csrf_token
  before_action :rate_limit_check

  def mortgage_estimate
    # Get a random mortgage or create a default one for calculation
    mortgage = Mortgage.first || Mortgage.new
    principal = params[:home_value]&.to_i || 1500000
    calculation_results = mortgage.mini_calculator(principal)

    render json: {
      min_income: calculation_results[:min_income],
      max_income: calculation_results[:max_income],
      formatted_min_income: number_to_currency(calculation_results[:min_income], precision: 0),
      formatted_max_income: number_to_currency(calculation_results[:max_income], precision: 0),
      formatted_range: "#{number_to_currency(calculation_results[:min_income], precision: 0)} - #{number_to_currency(calculation_results[:max_income], precision: 0)}"
    }
  end

  def monthly_income
    principal = params[:principal]&.to_i || 1500000
    loan_term = params[:loan_term]&.to_i || 30
    income_payout_term = params[:income_payout_term]&.to_i || 30

    # Calculate for both mortgage types
    interest_only_mortgage = Mortgage.find_by(mortgage_type: :interest_only)
    principal_interest_mortgage = Mortgage.find_by(mortgage_type: :principal_and_interest)

    interest_only_income = interest_only_mortgage&.calculate_monthly_income(principal, loan_term, income_payout_term) || 0
    principal_interest_income = principal_interest_mortgage&.calculate_monthly_income(principal, loan_term, income_payout_term) || 0
    
    # Calculate repayment for interest only mortgage
    interest_only_repayment = interest_only_mortgage&.repayment(principal, loan_term, income_payout_term) || 0

    render json: {
      interest_only_income: interest_only_income,
      principal_interest_income: principal_interest_income,
      interest_only_repayment: interest_only_repayment,
      formatted_interest_only_income: number_to_currency(interest_only_income, precision: 0),
      formatted_principal_interest_income: number_to_currency(principal_interest_income, precision: 0),
      formatted_interest_only_repayment: number_to_currency(interest_only_repayment, precision: 0)
    }
  end

  def check_email
    email = params[:email]
    exists = User.exists?(email: email) if email.present?
    
    render json: { 
      exists: !!exists,
      email: email 
    }
  end

  private

  def verify_request_origin
    # Allow requests from your domain and localhost for development
    allowed_origins = [
      Rails.application.routes.default_url_options[:host],
      request.host,
      'localhost',
      '127.0.0.1'
    ].compact.uniq

    # Check referer header
    referer = request.referer
    origin = request.headers['Origin']
    
    # Verify the request comes from an allowed origin
    valid_referer = referer && allowed_origins.any? { |domain| referer.include?(domain) }
    valid_origin = origin && allowed_origins.any? { |domain| origin.include?(domain) }
    
    # Allow same-origin requests (when referer/origin match the current host)
    same_origin = request.host && (
      (referer && referer.include?(request.host)) ||
      (origin && origin.include?(request.host))
    )
    
    unless valid_referer || valid_origin || same_origin
      Rails.logger.warn "API request blocked - Invalid origin. Referer: #{referer}, Origin: #{origin}, Host: #{request.host}"
      render json: { error: 'Unauthorized request origin' }, status: :forbidden
      return false
    end
  end

  def verify_csrf_token
    # Verify CSRF token for non-GET requests or when explicitly required
    unless request.get?
      unless verified_request?
        Rails.logger.warn "API request blocked - Invalid CSRF token from #{request.remote_ip}"
        render json: { error: 'Invalid security token' }, status: :forbidden
        return false
      end
    end
  end

  def rate_limit_check
    # Simple rate limiting based on IP address
    cache_key = "api_rate_limit:#{request.remote_ip}"
    request_count = Rails.cache.read(cache_key) || 0
    
    # Allow 1000 requests per hour per IP (accommodates slider interactions)
    max_requests = 1000
    time_window = 1.hour
    
    if request_count >= max_requests
      Rails.logger.warn "API request blocked - Rate limit exceeded for IP: #{request.remote_ip}"
      render json: { error: 'Rate limit exceeded. Please try again later.' }, status: :too_many_requests
      return false
    end
    
    # Increment counter
    Rails.cache.write(cache_key, request_count + 1, expires_in: time_window)
  end

  def number_to_currency(amount, options = {})
    ActionController::Base.helpers.number_to_currency(amount, options)
  end
end
