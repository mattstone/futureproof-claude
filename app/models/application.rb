class Application < ApplicationRecord
  belongs_to :user

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

  # Custom validations
  validate :mortgage_amount_required_if_has_mortgage

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

  private

  def mortgage_amount_required_if_has_mortgage
    if has_existing_mortgage? && existing_mortgage_amount.blank?
      errors.add(:existing_mortgage_amount, "is required when property has an existing mortgage")
    end
  end
end
