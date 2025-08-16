class WholesaleFunderVersion < ApplicationRecord
  belongs_to :wholesale_funder
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
      'created wholesale funder'
    when 'updated'
      'updated wholesale funder'
    when 'viewed'
      'viewed wholesale funder'
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
    has_name_changes? || has_country_changes? || has_currency_changes?
  end
  
  def has_name_changes?
    previous_name.present? && new_name.present? && previous_name != new_name
  end
  
  def has_country_changes?
    previous_country.present? && new_country.present? && previous_country != new_country
  end
  
  def has_currency_changes?
    previous_currency.present? && new_currency.present? && previous_currency != new_currency
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
    
    if has_country_changes?
      changes << {
        field: 'Country',
        from: previous_country,
        to: new_country
      }
    end
    
    if has_currency_changes?
      changes << {
        field: 'Currency',
        from: previous_currency,
        to: new_currency
      }
    end
    
    changes
  end
end