class Api::CalculationsController < ApplicationController
  skip_before_action :authenticate_user!

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

  def number_to_currency(amount, options = {})
    ActionController::Base.helpers.number_to_currency(amount, options)
  end
end
