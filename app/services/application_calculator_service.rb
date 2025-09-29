# Service object for application financial calculations
# Extracts calculation logic from Application model for better separation of concerns
class ApplicationCalculatorService
  attr_reader :application

  def initialize(application)
    @application = application
  end

  # Property value calculations
  def future_property_value(growth_rate_override = nil)
    rate = growth_rate_override || application.growth_rate || 2.0
    term = application.loan_term || 30
    current_value = application.home_value || 0

    # Simple interest calculation: Future Value = Present Value * (1 + rate * time)
    current_value * (1 + (rate / 100.0) * term)
  end

  def property_appreciation(growth_rate_override = nil)
    future_property_value(growth_rate_override) - (application.home_value || 0)
  end

  # Monthly payment calculations
  def monthly_income_amount
    return 0 unless application.income_amount && application.income_frequency

    case application.income_frequency
    when 'weekly'
      application.income_amount * 52 / 12
    when 'fortnightly'
      application.income_amount * 26 / 12
    when 'monthly'
      application.income_amount
    when 'annually'
      application.income_amount / 12
    else
      0
    end
  end

  def annual_income_amount
    return 0 unless application.income_amount && application.income_frequency

    case application.income_frequency
    when 'weekly'
      application.income_amount * 52
    when 'fortnightly'
      application.income_amount * 26
    when 'monthly'
      application.income_amount * 12
    when 'annually'
      application.income_amount
    else
      0
    end
  end

  # Loan calculation
  def net_loan_value
    (application.home_value || 0) - (application.existing_mortgage_amount || 0)
  end

  def loan_to_value_ratio
    return 0 if application.home_value.nil? || application.home_value.zero?
    return 0 if application.loan_value.nil?

    (application.loan_value.to_f / application.home_value.to_f * 100).round(2)
  end

  # Eligibility calculations
  def borrowing_capacity
    # Simplified calculation - can be enhanced based on business rules
    monthly_income = monthly_income_amount
    return 0 if monthly_income.zero?

    # Assume 30% of monthly income can go toward loan payments
    affordable_monthly_payment = monthly_income * 0.30

    # Calculate loan amount based on interest rate and term
    interest_rate = (application.mortgage&.interest_rate || 7.45) / 100.0 / 12
    term_months = (application.loan_term || 30) * 12

    if interest_rate.zero?
      affordable_monthly_payment * term_months
    else
      # Present value of annuity formula
      affordable_monthly_payment * ((1 - (1 + interest_rate)**-term_months) / interest_rate)
    end
  end

  def surplus_income
    monthly_income_amount - monthly_expenses
  end

  def monthly_expenses
    # This would be calculated based on application data
    # Placeholder for now
    application.monthly_expenses || 0
  end
end