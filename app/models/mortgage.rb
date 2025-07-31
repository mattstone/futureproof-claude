class Mortgage < ApplicationRecord
  enum :mortgage_type, {
    interest_only: 0,
    principal_and_interest: 1
  }

  validates :name, presence: true
  validates :mortgage_type, presence: true

  def calculate(principal = 1500000, loan_duration = 30, annuity_duration = 30)
    calc              = FPCalculator.new

    @min_results     = calc.calculate(principal, loan_duration, annuity_duration)
    annuity_duration = 10
    @max_results     = calc.calculate(principal, loan_duration, annuity_duration)

    Rails.logger.debug @min_results.inspect
    Rails.logger.debug "------------------------------------------------"
    Rails.logger.debug @max_results.inspect

    # Return the range values
    {
      min_income: @min_results[:principal_and_interest_monthly_income],
      max_income: @max_results[:interest_only_monthly_income],
      min_results: @min_results,
      max_results: @max_results
    }
  end
end
