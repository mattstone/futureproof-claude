class LenderVersion < ApplicationRecord
  belongs_to :lender
  belongs_to :user
  
  # Alias for consistency with shared change history interface
  alias_method :admin_user, :user
  
  validates :action, presence: true, inclusion: { in: %w[created updated viewed] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :changes_only, -> { where.not(action: 'viewed') }
  scope :views_only, -> { where(action: 'viewed') }
  
  # Action descriptions for display
  def action_description
    case action
    when 'created'
      'created lender'
    when 'updated'
      'updated lender'
    when 'viewed'
      'viewed lender'
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
    has_name_changes? || has_lender_type_changes? || has_contact_email_changes? || has_country_changes?
  end
  
  def has_name_changes?
    previous_name.present? && new_name.present? && previous_name != new_name
  end
  
  def has_lender_type_changes?
    previous_lender_type.present? && new_lender_type.present? && previous_lender_type != new_lender_type
  end
  
  def has_contact_email_changes?
    previous_contact_email.present? && new_contact_email.present? && previous_contact_email != new_contact_email
  end
  
  def has_country_changes?
    previous_country.present? && new_country.present? && previous_country != new_country
  end
  
  # Generate detailed change summary
  def detailed_changes
    changes = []
    
    if has_name_changes?
      changes << {
        field: 'Name',
        from: previous_name,
        to: new_name
      }
    end
    
    if has_lender_type_changes?
      changes << {
        field: 'Lender Type',
        from: lender_type_label(previous_lender_type),
        to: lender_type_label(new_lender_type)
      }
    end
    
    if has_contact_email_changes?
      changes << {
        field: 'Contact Email',
        from: previous_contact_email,
        to: new_contact_email
      }
    end
    
    if has_country_changes?
      changes << {
        field: 'Country',
        from: previous_country,
        to: new_country
      }
    end
    
    changes
  end
  
  private
  
  def lender_type_label(type_value)
    case type_value
    when 0
      'Futureproof'
    when 1
      'Lender'
    else
      type_value.to_s
    end
  end
end