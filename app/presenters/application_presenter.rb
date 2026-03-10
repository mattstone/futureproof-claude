class ApplicationPresenter
  attr_reader :application

  def initialize(application)
    @application = application
  end

  # Delegation for easy access to application attributes
  delegate :home_value, :existing_mortgage_amount, :growth_rate, :loan_term,
           :property_valuation_low, :property_valuation_high, :property_valuation_middle,
           :address, :status, :user, :mortgage, :borrower_names,
           :loan_value, :interest_paid_on_behalf, :loan_principal_paid_on_behalf,
           :repayment_due_at_end_of_loan, :total_income_amount, :monthly_income_amount,
           :monthly_income_total_paid, :home_equity_preserved, :property_appreciation,
           :future_property_value, :has_existing_mortgage?, to: :application

  # =================================
  # Currency Formatting Helper
  # =================================
  # Consolidates all ActionController::Base.helpers.number_to_currency calls
  def format_currency(amount, options = {})
    return "$0" unless amount.present? && amount > 0
    ActionController::Base.helpers.number_to_currency(amount, { precision: 0 }.merge(options))
  end

  def format_percentage(value, default = 2.0)
    "#{value || default}%"
  end

  # =================================
  # Property Value Formatters
  # =================================
  def home_value_formatted
    format_currency(home_value)
  end

  def existing_mortgage_amount_formatted
    return "$0" unless has_existing_mortgage? && existing_mortgage_amount > 0
    format_currency(existing_mortgage_amount)
  end

  def future_property_value_formatted(growth_rate_override = nil)
    format_currency(future_property_value(growth_rate_override))
  end

  def property_appreciation_formatted(growth_rate_override = nil)
    format_currency(property_appreciation(growth_rate_override))
  end

  def growth_rate_formatted
    format_percentage(growth_rate)
  end

  # =================================
  # CoreLogic Property Valuation Formatters
  # =================================
  def property_valuation_range_formatted
    if property_valuation_low.present? && property_valuation_high.present?
      low = format_currency(property_valuation_low)
      high = format_currency(property_valuation_high)
      "#{low} - #{high}"
    else
      "Not available"
    end
  end

  def property_valuation_middle_formatted
    if property_valuation_middle.present?
      format_currency(property_valuation_middle)
    else
      "Not available"
    end
  end

  # =================================
  # Equity & Loan Value Formatters
  # =================================
  def home_equity_preserved_formatted(growth_rate_override = nil)
    format_currency(home_equity_preserved(growth_rate_override))
  end

  def loan_value_formatted
    format_currency(loan_value)
  end

  # =================================
  # Payment Summary Formatters
  # =================================
  def interest_paid_on_behalf_formatted
    format_currency(interest_paid_on_behalf)
  end

  def loan_principal_paid_on_behalf_formatted
    format_currency(loan_principal_paid_on_behalf)
  end

  def repayment_due_at_end_of_loan_formatted
    format_currency(repayment_due_at_end_of_loan)
  end

  # =================================
  # Income Summary Formatters
  # =================================
  def total_income_amount_formatted
    format_currency(total_income_amount)
  end

  def monthly_income_amount_formatted
    format_currency(monthly_income_amount)
  end

  # =================================
  # Status & Display Formatters
  # =================================
  def status_display
    status.humanize
  end

  def status_badge_class
    case status
    when 'created'
      'badge-secondary'
    when 'property_details', 'income_and_loan_options'
      'badge-warning'
    when 'submitted', 'processing'
      'badge-info'
    when 'accepted'
      'badge-success'
    when 'rejected'
      'badge-danger'
    else
      'badge-secondary'
    end
  end

  def display_address
    address.present? ? address : "Address not set"
  end

  def contract_display_name
    "#{user.display_name} - #{address[0..50]}"
  end

  # =================================
  # Borrower Information Formatters
  # =================================
  def borrower_names_formatted
    return nil unless application.has_borrower_names?
    
    # Use concern's parsed method (safe JSON parsing)
    names_data = application.borrower_names_array
    
    if names_data.is_a?(Array) && names_data.any?
      names_data.map { |item| "#{item['name']} (Age: #{item['age']})" }.join("\n")
    else
      application.borrower_names # Return raw if not expected format
    end
  end

  def has_borrower_names?
    application.has_borrower_names?
  end
end
