class MortgageLenderVersion < ApplicationRecord
  belongs_to :mortgage_lender
  belongs_to :user
  
  # Alias for consistency with shared change history interface
  alias_method :admin_user, :user
  
  validates :action, presence: true
  validates :change_details, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  
  def action_description
    case action
    when 'created'
      "added lender relationship"
    when 'updated'
      "updated lender relationship"
    when 'destroyed'
      "removed lender relationship"
    else
      change_details || action
    end
  end
  
  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end
  
  # Check if this version has field changes to display
  def has_field_changes?
    has_active_changes?
  end
  
  def has_active_changes?
    previous_active.present? && new_active.present? && previous_active != new_active
  end
  
  # Generate detailed change summary
  def detailed_changes
    changes = []
    
    if has_active_changes?
      changes << {
        field: 'Status',
        from: previous_active? ? 'Active' : 'Inactive',
        to: new_active? ? 'Active' : 'Inactive'
      }
    end
    
    changes
  end
  
  def lender_name
    mortgage_lender&.lender&.name || 'Unknown Lender'
  end
  
  def mortgage_name
    mortgage_lender&.mortgage&.name || 'Unknown Mortgage'
  end
end
