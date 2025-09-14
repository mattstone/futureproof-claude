class Application < ApplicationRecord
  # include InputSanitization  # Temporarily disabled for testing

  belongs_to :user
  belongs_to :mortgage, optional: true
  has_one :contract, dependent: :destroy
  has_many :application_versions, dependent: :destroy
  has_many :application_messages, dependent: :destroy
  has_many :application_checklists, class_name: 'ApplicationChecklist', dependent: :destroy

  # Enums
  enum :ownership_status, {
    individual: 0,
    joint: 1,
    lender: 2,
    super: 3
  }, prefix: true

  enum :property_state, {
    primary_residence: 0,
    investment: 1,
    holiday: 2
  }, prefix: true

  enum :status, {
    created: 0,
    user_details: 1,
    property_details: 2,
    income_and_loan_options: 3,
    submitted: 4,
    processing: 5,
    rejected: 6,
    accepted: 7
  }, prefix: true

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
  validates :rejected_reason, presence: true, if: :status_rejected?
  validates :borrower_age, presence: true, numericality: {
    greater_than_or_equal_to: 18,
    less_than_or_equal_to: 85,
    only_integer: true
  }, if: -> { ownership_status_individual? && !status_created? }
  validates :borrower_names, presence: true, if: -> { ownership_status_joint? && !status_created? }
  validates :company_name, presence: true, if: -> { ownership_status_lender? && !status_created? }
  validates :super_fund_name, presence: true, if: -> { ownership_status_super? && !status_created? }
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
  validate :checklist_completed_for_acceptance

  # Callbacks
  before_validation :assign_demo_address, on: :create
  before_validation :set_default_existing_mortgage_amount

  # Track changes with audit functionality
  attr_accessor :current_user

  after_create :log_creation
  after_update :log_update
  after_update :create_contract_if_accepted
  after_update :auto_create_checklist_on_submitted
  after_update :ensure_checklist_for_processing_and_beyond
  after_commit :trigger_email_workflows

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_value_range, ->(min, max) { where(home_value: min..max) }
  scope :with_existing_mortgage, -> { where(has_existing_mortgage: true) }
  scope :in_progress, -> { where(status: [:created, :property_details, :income_and_loan_options]) }
  scope :completed, -> { where(status: [:submitted, :processing, :accepted, :rejected]) }
  scope :pending_review, -> { where(status: [:submitted, :processing]) }

  # Methods
  def formatted_home_value
    ActionController::Base.helpers.number_to_currency(home_value, precision: 0)
  end

  def formatted_existing_mortgage_amount
    return "$0" unless has_existing_mortgage? && existing_mortgage_amount > 0
    ActionController::Base.helpers.number_to_currency(existing_mortgage_amount, precision: 0)
  end

  def display_address
    address.present? ? address : "Address not set"
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

  def formatted_borrower_names
    return nil unless borrower_names.present?

    begin
      names_data = JSON.parse(borrower_names)
      if names_data.is_a?(Array)
        names_data.map { |item| "#{item['name']} (Age: #{item['age']})" }.join("\n")
      else
        borrower_names # Return raw if not expected format
      end
    rescue JSON::ParserError
      borrower_names # Return raw if JSON is invalid
    end
  end

  def has_borrower_names?
    borrower_names.present? && borrower_names != "" && borrower_names != "null"
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

  def can_be_edited?
    status_created? || status_property_details? || status_income_and_loan_options?
    # Note: Accepted applications cannot be edited as they have active contracts
  end

  def next_step
    case status
    when 'created'
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
    when 'created'
      0
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
  
  def contract_display_name
    "#{user.display_name} - #{address[0..50]}"
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

  # Loan value calculation ((Home Value - Existing Mortgage) * LVR)
  def loan_value
    return 0 unless mortgage.present? && home_value.present?

    # Calculate net property value after existing mortgage
    net_property_value = home_value - (existing_mortgage_amount || 0)

    # Ensure we don't have a negative loan value
    return 0 if net_property_value <= 0

    lvr_decimal = (mortgage.lvr || 80.0) / 100.0
    net_property_value * lvr_decimal
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

  # Messaging methods
  def has_unread_customer_messages?
    application_messages.customer_messages.unread.exists?
  end

  def unread_customer_messages_count
    application_messages.customer_messages.unread.count
  end

  def latest_customer_message
    application_messages.customer_messages.sent.order(:created_at).last
  end

  def message_threads
    application_messages.thread_messages.includes(:replies, :sender).order(created_at: :desc)
  end

  # Log when admin views application
  def log_view_by(user)
    return unless user

    application_versions.create!(
      user: user,
      action: 'viewed',
      change_details: "Admin #{user.display_name} viewed application"
    )
  end
  
  # Checklist management methods
  def create_checklist!
    return if application_checklists.exists?
    
    ApplicationChecklist::STANDARD_CHECKLIST_ITEMS.each_with_index do |item_name, index|
      application_checklists.create!(
        name: item_name,
        position: index,
        completed: false
      )
    end
  end
  
  def checklist_completed?
    return false unless application_checklists.exists?
    application_checklists.all?(&:completed?)
  end
  
  def checklist_completion_percentage
    return 0 unless application_checklists.exists?
    completed_count = application_checklists.completed.count
    total_count = application_checklists.count
    return 0 if total_count.zero?
    (completed_count.to_f / total_count * 100).round
  end
  
  def advance_to_processing_with_checklist!(user)
    transaction do
      create_checklist!
      update!(status: :processing)
      
      # Log the status change and checklist creation
      application_versions.create!(
        user: user,
        action: 'status_changed',
        change_details: "Application submitted and checklist created. Status changed from 'Submitted' to 'Processing'",
        previous_status: 4, # submitted
        new_status: 5 # processing
      )
    end
  end
  

  private

  def set_default_existing_mortgage_amount
    self.existing_mortgage_amount ||= 0
  end

  def mortgage_amount_required_if_has_mortgage
    if has_existing_mortgage? && (existing_mortgage_amount.nil? || existing_mortgage_amount <= 0)
      errors.add(:existing_mortgage_amount, "must be greater than 0 when property has an existing mortgage")
    end
  end

  def borrower_names_format_if_joint
    return unless ownership_status_joint? && borrower_names.present?

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

  def checklist_completed_for_acceptance
    # Only validate if status is being changed to accepted
    return unless will_save_change_to_status? && status_accepted?
    
    # Skip validation if no checklist exists (for applications that don't have checklists yet)
    return unless application_checklists.exists?
    
    # Validate that all checklist items are completed
    unless checklist_completed?
      errors.add(:status, "cannot be set to accepted until all checklist items are completed")
    end
  end

  def assign_demo_address
    return if address.present? && address != "Placeholder - to be updated by user"

    # Random Sydney addresses for demonstration purposes
    sydney_addresses = [
      "15 Circular Quay West, Sydney NSW 2000",
      "42 Kent Street, Sydney NSW 2000",
      "128 George Street, The Rocks NSW 2000",
      "73 Miller Street, North Sydney NSW 2060",
      "91 Pittwater Road, Manly NSW 2095",
      "156 Oxford Street, Paddington NSW 2021",
      "234 Crown Street, Surry Hills NSW 2010",
      "67 Victoria Road, Drummoyne NSW 2047",
      "445 Pacific Highway, Crows Nest NSW 2065",
      "182 Blues Point Road, McMahons Point NSW 2060",
      "298 Military Road, Neutral Bay NSW 2089",
      "76 Anzac Parade, Kensington NSW 2033",
      "523 King Street, Newtown NSW 2042",
      "145 Glebe Point Road, Glebe NSW 2037",
      "287 Darling Street, Balmain NSW 2041",
      "94 Norton Street, Leichhardt NSW 2040",
      "367 Cleveland Street, Redfern NSW 2016",
      "189 Bondi Road, Bondi NSW 2026",
      "256 Campbell Parade, Bondi Beach NSW 2026",
      "412 Bourke Street, Darlinghurst NSW 2010",
      "78 Liverpool Street, Sydney NSW 2000",
      "345 Pitt Street, Sydney NSW 2000",
      "123 Macquarie Street, Sydney NSW 2000",
      "567 Elizabeth Street, Surry Hills NSW 2010",
      "89 King Street, Sydney NSW 2000"
    ]

    self.address = sydney_addresses.sample
  end

  def log_creation
    return unless current_user

    application_versions.create!(
      user: current_user,
      action: 'created',
      change_details: "Created new application for #{address} with home value #{formatted_home_value}",
      new_status: status_before_type_cast,
      new_address: address,
      new_home_value: home_value,
      new_existing_mortgage_amount: existing_mortgage_amount,
      new_borrower_age: borrower_age,
      new_ownership_status: ownership_status_before_type_cast
    )
  end

  def log_update
    return unless current_user

    # Special handling for status changes
    if saved_change_to_status?
      old_status = saved_change_to_status[0]
      new_status = saved_change_to_status[1]
      application_versions.create!(
        user: current_user,
        action: 'status_changed',
        change_details: "Changed application status from '#{status_label(old_status)}' to '#{status_label(new_status)}'",
        previous_status: old_status,
        new_status: new_status
      )
    elsif saved_changes.any?
      # Log other field changes
      application_versions.create!(
        user: current_user,
        action: 'updated',
        change_details: build_change_summary,
        previous_status: saved_change_to_status ? saved_change_to_status[0] : nil,
        new_status: saved_change_to_status ? saved_change_to_status[1] : nil,
        previous_address: saved_change_to_address ? saved_change_to_address[0] : nil,
        new_address: saved_change_to_address ? saved_change_to_address[1] : nil,
        previous_home_value: saved_change_to_home_value ? saved_change_to_home_value[0] : nil,
        new_home_value: saved_change_to_home_value ? saved_change_to_home_value[1] : nil,
        previous_existing_mortgage_amount: saved_change_to_existing_mortgage_amount ? saved_change_to_existing_mortgage_amount[0] : nil,
        new_existing_mortgage_amount: saved_change_to_existing_mortgage_amount ? saved_change_to_existing_mortgage_amount[1] : nil,
        previous_borrower_age: saved_change_to_borrower_age ? saved_change_to_borrower_age[0] : nil,
        new_borrower_age: saved_change_to_borrower_age ? saved_change_to_borrower_age[1] : nil,
        previous_ownership_status: saved_change_to_ownership_status ? saved_change_to_ownership_status[0] : nil,
        new_ownership_status: saved_change_to_ownership_status ? saved_change_to_ownership_status[1] : nil
      )
    end
  end
  
  def create_contract_if_accepted
    # Only create contract if status changed to accepted and no contract exists yet
    return unless saved_change_to_status?
    return unless status_accepted?
    return if contract.present?
    
    # Get the lender - for now, use the first lender associated with the mortgage
    # In the future, this might be determined by the user's choice or application data
    lender = mortgage&.active_lenders&.first
    if lender.nil?
      Rails.logger.error "No active lender found for mortgage #{mortgage&.id} in application #{id}"
      raise StandardError, "No active lender available for this mortgage"
    end
    
    # Get the lender's active funder pool
    funder_pool = lender.active_funder_pool
    if funder_pool.nil?
      Rails.logger.error "Lender #{lender.name} has no active funder pool for application #{id}"
      raise StandardError, "Lender #{lender.name} has no active funder pool available"
    end
    
    # Check if the funder pool has sufficient capital
    if funder_pool.amount - funder_pool.allocated < home_value
      Rails.logger.error "Lender #{lender.name}'s funder pool has insufficient capital (need: #{home_value}, available: #{funder_pool.amount - funder_pool.allocated})"
      raise StandardError, "Insufficient funding available in lender's pool"
    end
    
    # Get the active mortgage contract (the terms document)
    mortgage_contract = MortgageContract.current
    if mortgage_contract.nil?
      Rails.logger.error "No active mortgage contract found for application #{id}"
      raise StandardError, "No active mortgage contract available"
    end
    
    # Create contract linking user, lender, terms, and funding
    contract = Contract.create!(
      application: self,
      lender: lender,
      mortgage_contract: mortgage_contract,
      funder_pool: funder_pool,
      allocated_amount: home_value,
      start_date: Date.current,
      end_date: Date.current + (loan_term || 30).years,
      status: :awaiting_funding
    )
    
    # Allocate the capital from the funder pool
    funder_pool.allocate_capital!(home_value)
    
    Rails.logger.info "Contract created for application #{id}: User #{user.display_name} + Lender #{lender.name} + MortgageContract v#{mortgage_contract.version} + FunderPool #{funder_pool.id}"
  rescue => e
    Rails.logger.error "Failed to create contract for application #{id}: #{e.message}"
    raise e
  end

  def build_change_summary
    changes_list = []

    if saved_change_to_address?
      changes_list << "Address changed from '#{saved_change_to_address[0]}' to '#{saved_change_to_address[1]}'"
    end

    if saved_change_to_home_value?
      old_value = ActionController::Base.helpers.number_to_currency(saved_change_to_home_value[0], precision: 0)
      new_value = ActionController::Base.helpers.number_to_currency(saved_change_to_home_value[1], precision: 0)
      changes_list << "Home value changed from #{old_value} to #{new_value}"
    end

    if saved_change_to_existing_mortgage_amount?
      old_amount = ActionController::Base.helpers.number_to_currency(saved_change_to_existing_mortgage_amount[0], precision: 0)
      new_amount = ActionController::Base.helpers.number_to_currency(saved_change_to_existing_mortgage_amount[1], precision: 0)
      changes_list << "Existing mortgage amount changed from #{old_amount} to #{new_amount}"
    end

    if saved_change_to_borrower_age?
      changes_list << "Borrower age changed from #{saved_change_to_borrower_age[0]} to #{saved_change_to_borrower_age[1]}"
    end

    if saved_change_to_ownership_status?
      old_status = ownership_status_label(saved_change_to_ownership_status[0])
      new_status = ownership_status_label(saved_change_to_ownership_status[1])
      changes_list << "Ownership status changed from '#{old_status}' to '#{new_status}'"
    end

    changes_list.join("; ")
  end

  def status_label(status_value)
    case status_value
    when 0 then 'Created'
    when 1 then 'User Details'
    when 2 then 'Property Details'
    when 3 then 'Income and Loan Options'
    when 4 then 'Submitted'
    when 5 then 'Processing'
    when 6 then 'Rejected'
    when 7 then 'Accepted'
    else status_value.to_s
    end
  end

  def ownership_status_label(ownership_value)
    case ownership_value
    when 0 then 'Individual'
    when 1 then 'Joint'
    when 2 then 'Lender'
    when 3 then 'Super Fund'
    else ownership_value.to_s
    end
  end
  
  def auto_create_checklist_on_submitted
    # Only trigger if status changed TO submitted and we have a current_user
    return unless saved_change_to_status?
    return unless current_user
    return unless status_submitted?
    
    # Automatically advance to processing with checklist
    advance_to_processing_with_checklist!(current_user)
  end
  
  def ensure_checklist_for_processing_and_beyond
    # Only trigger if status changed TO processing, rejected, or accepted
    return unless saved_change_to_status?
    return unless status_processing? || status_rejected? || status_accepted?
    
    # If no checklist exists, create one
    if application_checklists.empty?
      create_checklist!
      
      # Log the checklist creation if we have a current_user
      if current_user
        application_versions.create!(
          user: current_user,
          action: 'checklist_updated',
          change_details: "Checklist automatically created when application status changed to '#{status_display}'"
        )
      end
    end
  end
  
  def trigger_email_workflows
    # Trigger workflows when application is created
    if saved_change_to_id? # This means it's a new record
      trigger_workflows_for('application_created')
    end
    
    # Trigger workflows when status changes
    if saved_change_to_status?
      old_status, new_status = saved_change_to_status
      trigger_workflows_for('application_status_changed', from_status: old_status, to_status: new_status)
    end
  end
  
  private
  
  def trigger_workflows_for(trigger_type, context = {})
    EmailWorkflow.active.for_trigger(trigger_type).find_each do |workflow|
      begin
        Rails.logger.info "Triggering workflow '#{workflow.name}' for Application #{id}"
        workflow.execute_for(self, context.merge(
          user: user,
          application: self,
          triggered_at: Time.current
        ))
      rescue => e
        Rails.logger.error "Failed to trigger workflow '#{workflow.name}' for Application #{id}: #{e.message}"
      end
    end
  end
end
