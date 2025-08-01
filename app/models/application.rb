class Application < ApplicationRecord
  belongs_to :user
  belongs_to :mortgage, optional: true

  # Enums
  enum :ownership_status, {
    individual: 0,
    joint: 1,
    company: 2,
    super: 3
  }

  enum :property_state, {
    primary_residence: 0,
    investment: 1,
    holiday: 2
  }

  enum :status, {
    user_details: 0,
    property_details: 1,
    income_and_loan_options: 2,
    submitted: 3,
    processing: 4,
    rejected: 5,
    accepted: 6
  }

  # Validations
  validates :address, presence: true, length: { maximum: 255 }
  validates :home_value, presence: true, numericality: { 
    greater_than: 0, 
    less_than_or_equal_to: 50_000_000,
    only_integer: true 
  }
  validates :user, presence: true
  validates :ownership_status, presence: true
  validates :property_state, presence: true
  validates :status, presence: true
  validates :existing_mortgage_amount, numericality: { 
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 50_000_000
  }, allow_blank: true
  validates :rejected_reason, presence: true, if: :rejected?
  validates :borrower_age, presence: true, numericality: { 
    greater_than_or_equal_to: 18, 
    less_than_or_equal_to: 85,
    only_integer: true 
  }, if: :individual?
  validates :borrower_names, presence: true, if: :joint?
  validates :company_name, presence: true, if: :company?
  validates :super_fund_name, presence: true, if: :super?
  validates :loan_term, presence: true, numericality: { 
    greater_than_or_equal_to: 10, 
    less_than_or_equal_to: 30,
    only_integer: true 
  }, on: :income_loan_update
  validates :income_payout_term, presence: true, numericality: { 
    greater_than_or_equal_to: 10, 
    less_than_or_equal_to: 30,
    only_integer: true 
  }, on: :income_loan_update
  validates :mortgage, presence: true, on: :income_loan_update
  validates :growth_rate, presence: true, numericality: { 
    greater_than: 0, 
    less_than_or_equal_to: 20 
  }

  # Custom validations
  validate :mortgage_amount_required_if_has_mortgage
  validate :borrower_names_format_if_joint

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_value_range, ->(min, max) { where(home_value: min..max) }
  scope :with_existing_mortgage, -> { where(has_existing_mortgage: true) }
  scope :in_progress, -> { where(status: [:user_details, :property_details, :income_and_loan_options]) }
  scope :completed, -> { where(status: [:submitted, :processing, :accepted, :rejected]) }
  scope :pending_review, -> { where(status: [:submitted, :processing]) }

  # Methods
  def formatted_home_value
    ActionController::Base.helpers.number_to_currency(home_value, precision: 0)
  end

  def formatted_existing_mortgage_amount
    return "N/A" unless has_existing_mortgage? && existing_mortgage_amount.present?
    ActionController::Base.helpers.number_to_currency(existing_mortgage_amount, precision: 0)
  end

  def ownership_status_display
    ownership_status.humanize
  end

  def property_state_display
    property_state.humanize
  end

  def status_display
    status.humanize
  end

  def status_badge_class
    case status
    when 'user_details', 'property_details', 'income_and_loan_options'
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

  def can_be_edited?
    user_details? || property_details? || income_and_loan_options?
  end

  def next_step
    case status
    when 'user_details'
      'property_details'
    when 'property_details'
      'income_and_loan_options'
    when 'income_and_loan_options'
      'submitted'
    else
      nil
    end
  end

  def progress_percentage
    case status
    when 'user_details'
      25
    when 'property_details'
      50
    when 'income_and_loan_options'
      75
    else
      100
    end
  end

  def advance_to_next_step!
    next_status = next_step
    if next_status
      update!(status: next_status)
    end
  end

  # Property value calculations
  def future_property_value(growth_rate_override = nil)
    rate = growth_rate_override || growth_rate || 2.0
    term = loan_term || 30
    current_value = home_value || 0
    
    # Simple interest calculation: Future Value = Present Value * (1 + rate * time)
    current_value * (1 + (rate / 100.0) * term)
  end

  def formatted_future_property_value(growth_rate_override = nil)
    ActionController::Base.helpers.number_to_currency(future_property_value(growth_rate_override), precision: 0)
  end

  def property_appreciation(growth_rate_override = nil)
    future_property_value(growth_rate_override) - (home_value || 0)
  end

  def formatted_property_appreciation(growth_rate_override = nil)
    ActionController::Base.helpers.number_to_currency(property_appreciation(growth_rate_override), precision: 0)
  end

  def formatted_growth_rate
    "#{growth_rate || 2.0}%"
  end

  # Equity preservation calculations
  def home_equity_preserved(growth_rate_override = nil)
    return 0 unless mortgage.present?
    
    future_value = future_property_value(growth_rate_override)
    
    if mortgage.mortgage_type_principal_and_interest?
      # For Principal & Interest: equity preserved is the full future property value
      future_value
    else
      # For Interest Only: equity preserved is future value minus total income paid to customer
      total_income_paid = monthly_income_total_paid
      future_value - total_income_paid
    end
  end

  def formatted_home_equity_preserved(growth_rate_override = nil)
    ActionController::Base.helpers.number_to_currency(home_equity_preserved(growth_rate_override), precision: 0)
  end

  # Loan value calculation (Principal * LVR)
  def loan_value
    return 0 unless mortgage.present? && home_value.present?
    
    lvr_decimal = (mortgage.lvr || 80.0) / 100.0
    home_value * lvr_decimal
  end

  def formatted_loan_value
    ActionController::Base.helpers.number_to_currency(loan_value, precision: 0)
  end

  # Payment Summary calculations
  def interest_paid_on_behalf
    return 0 unless loan_term.present?
    
    principal = loan_value
    rate = 7.45 / 100.0  # 7.45% as decimal
    term = loan_term
    
    # Simple interest calculation: Principal * Rate * Time
    principal * rate * term
  end

  def formatted_interest_paid_on_behalf
    ActionController::Base.helpers.number_to_currency(interest_paid_on_behalf, precision: 0)
  end

  def loan_principal_paid_on_behalf
    return 0 unless mortgage.present?
    
    if mortgage.mortgage_type_principal_and_interest?
      loan_value
    else
      0  # Interest only loans don't pay down principal
    end
  end

  def formatted_loan_principal_paid_on_behalf
    ActionController::Base.helpers.number_to_currency(loan_principal_paid_on_behalf, precision: 0)
  end

  def repayment_due_at_end_of_loan
    return 0 unless mortgage.present?
    
    if mortgage.mortgage_type_principal_and_interest?
      0  # No repayment due at end for principal & interest
    else
      monthly_income_total_paid  # For interest only, customer must repay what they received
    end
  end

  def formatted_repayment_due_at_end_of_loan
    ActionController::Base.helpers.number_to_currency(repayment_due_at_end_of_loan, precision: 0)
  end

  # Income Summary calculations
  def total_income_amount
    monthly_income_total_paid
  end

  def formatted_total_income_amount
    ActionController::Base.helpers.number_to_currency(total_income_amount, precision: 0)
  end

  def monthly_income_amount
    return 0 unless mortgage.present?
    
    mortgage.calculate_monthly_income(
      home_value || 0,
      loan_term || 30,
      income_payout_term || 30
    )
  end

  def formatted_monthly_income_amount
    ActionController::Base.helpers.number_to_currency(monthly_income_amount, precision: 0)
  end

  def annuity_duration_years
    loan_term || 30
  end

  def monthly_income_total_paid
    return 0 unless mortgage.present? && income_payout_term.present?
    
    # Calculate monthly income using the mortgage's calculate_monthly_income method
    monthly_income = mortgage.calculate_monthly_income(
      home_value || 0,
      loan_term || 30,
      income_payout_term || 30
    )
    
    # Total paid = monthly income * 12 months * income payout term
    monthly_income * 12 * income_payout_term
  end

  private

  def mortgage_amount_required_if_has_mortgage
    if has_existing_mortgage? && existing_mortgage_amount.blank?
      errors.add(:existing_mortgage_amount, "is required when property has an existing mortgage")
    end
  end

  def borrower_names_format_if_joint
    return unless joint? && borrower_names.present?
    
    # Check if it's valid JSON format for multiple names/ages
    begin
      names_data = JSON.parse(borrower_names)
      unless names_data.is_a?(Array) && names_data.all? { |item| item.is_a?(Hash) && item.key?('name') && item.key?('age') }
        errors.add(:borrower_names, "must be in valid format for joint ownership")
      end
    rescue JSON::ParserError
      errors.add(:borrower_names, "must be in valid JSON format")
    end
  end
end
