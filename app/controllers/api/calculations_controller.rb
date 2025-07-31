class Api::CalculationsController < ApplicationController
  skip_before_action :authenticate_user!

  def mortgage_estimate
    # Get a random mortgage or create a default one for calculation
    mortgage = Mortgage.first || Mortgage.new
    principal = params[:home_value]&.to_i || 1500000
    calculation_results = mortgage.calculate(principal)

    render json: {
      min_income: calculation_results[:min_income],
      max_income: calculation_results[:max_income],
      formatted_min_income: number_to_currency(calculation_results[:min_income], precision: 0),
      formatted_max_income: number_to_currency(calculation_results[:max_income], precision: 0),
      formatted_range: "#{number_to_currency(calculation_results[:min_income], precision: 0)} - #{number_to_currency(calculation_results[:max_income], precision: 0)}"
    }
  end

  private

  def number_to_currency(amount, options = {})
    ActionController::Base.helpers.number_to_currency(amount, options)
  end
end
