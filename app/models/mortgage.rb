class Mortgage < ApplicationRecord
  enum :mortgage_type, {
    interest_only: 0,
    principal_and_interest: 1
  }, prefix: true

  validates :name, presence: true
  validates :mortgage_type, presence: true
  validates :lvr, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }

  def calculate_monthly_income(principal = 1500000, loan_duration = 30, annuity_duration = 30)
    calc = FPCalculator.new

    results = calc.calculate(principal, loan_duration, annuity_duration)

    case mortgage_type
    when "interest_only"          then results[:interest_only_monthly_income]
    when "principal_and_interest" then results[:principal_and_interest_monthly_income]
    end
  end

  def repayment(principal = 1500000, loan_duration = 30, annuity_duration = 30)
    return 0 if mortgage_type_principal_and_interest?

    mortgage_type          = "interest_only"
    monthly_income_payment = calculate_monthly_income(principal, loan_duration, annuity_duration)
    ((monthly_income_payment * 12.to_f) * loan_duration.to_f).round(2)
  end

  def mini_calculator(principal = 1500000, loan_duration = 30, annuity_duration = 30)
    calc              = FPCalculator.new

    @min_results     = calc.calculate(principal, loan_duration, annuity_duration)
    annuity_duration = 10
    @max_results     = calc.calculate(principal, loan_duration, annuity_duration)

    # Return the range values
    {
      min_income: @min_results[:principal_and_interest_monthly_income],
      max_income: @max_results[:interest_only_monthly_income],
      min_results: @min_results,
      max_results: @max_results
    }
  end
end
