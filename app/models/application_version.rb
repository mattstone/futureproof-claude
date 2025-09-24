class ApplicationVersion < ApplicationRecord
  belongs_to :application
  belongs_to :user
  
  # Alias for consistency with shared change history interface
  alias_method :admin_user, :user
  
  validates :action, presence: true, inclusion: { in: %w[created updated viewed status_changed checklist_updated valuation_updated] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :changes_only, -> { where.not(action: 'viewed') }
  scope :views_only, -> { where(action: 'viewed') }
  
  # Action descriptions for display
  def action_description
    case action
    when 'created'
      'created application'
    when 'updated'
      'updated application'
    when 'viewed'
      'viewed application'
    when 'status_changed'
      'changed application status'
    when 'checklist_updated'
      'updated processing checklist'
    when 'valuation_updated'
      'updated property valuation'
    else
      action
    end
  end
  
  # Formatted creation time
  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end
  
  # Check if this version has field changes to display
  def has_field_changes?
    has_status_changes? || has_address_changes? || has_home_value_changes? || 
    has_existing_mortgage_amount_changes? || has_borrower_age_changes? || has_ownership_status_changes?
  end
  
  def has_status_changes?
    previous_status.present? && new_status.present? && previous_status != new_status
  end
  
  def has_address_changes?
    previous_address.present? && new_address.present? && previous_address != new_address
  end
  
  def has_home_value_changes?
    previous_home_value.present? && new_home_value.present? && previous_home_value != new_home_value
  end
  
  def has_existing_mortgage_amount_changes?
    previous_existing_mortgage_amount.present? && new_existing_mortgage_amount.present? && 
    previous_existing_mortgage_amount != new_existing_mortgage_amount
  end
  
  def has_borrower_age_changes?
    previous_borrower_age.present? && new_borrower_age.present? && previous_borrower_age != new_borrower_age
  end
  
  def has_ownership_status_changes?
    previous_ownership_status.present? && new_ownership_status.present? && 
    previous_ownership_status != new_ownership_status
  end
  
  # Generate detailed change summary
  def detailed_changes
    changes = []
    
    if has_status_changes?
      changes << {
        field: 'Status',
        from: status_label(previous_status),
        to: status_label(new_status)
      }
    end
    
    if has_address_changes?
      changes << {
        field: 'Address',
        from: previous_address,
        to: new_address
      }
    end
    
    if has_home_value_changes?
      changes << {
        field: 'Home Value',
        from: ActionController::Base.helpers.number_to_currency(previous_home_value, precision: 0),
        to: ActionController::Base.helpers.number_to_currency(new_home_value, precision: 0)
      }
    end
    
    if has_existing_mortgage_amount_changes?
      changes << {
        field: 'Existing Mortgage Amount',
        from: ActionController::Base.helpers.number_to_currency(previous_existing_mortgage_amount, precision: 0),
        to: ActionController::Base.helpers.number_to_currency(new_existing_mortgage_amount, precision: 0)
      }
    end
    
    if has_borrower_age_changes?
      changes << {
        field: 'Borrower Age',
        from: previous_borrower_age.to_s,
        to: new_borrower_age.to_s
      }
    end
    
    if has_ownership_status_changes?
      changes << {
        field: 'Ownership Status',
        from: ownership_status_label(previous_ownership_status),
        to: ownership_status_label(new_ownership_status)
      }
    end
    
    changes
  end
  
  private
  
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
end