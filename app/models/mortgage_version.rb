class MortgageVersion < ApplicationRecord
  belongs_to :mortgage
  belongs_to :user
  
  validates :action, presence: true, inclusion: { in: %w[created updated activated deactivated] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  
  # Action descriptions for display
  def action_description
    case action
    when 'created'
      'created mortgage'
    when 'updated'
      'updated mortgage'
    when 'activated'
      'activated mortgage'
    when 'deactivated'
      'deactivated mortgage'
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
    has_name_changes? || has_mortgage_type_changes? || has_lvr_changes?
  end
  
  def has_name_changes?
    previous_name.present? && new_name.present? && previous_name != new_name
  end
  
  def has_mortgage_type_changes?
    previous_mortgage_type.present? && new_mortgage_type.present? && previous_mortgage_type != new_mortgage_type
  end
  
  def has_lvr_changes?
    previous_lvr.present? && new_lvr.present? && previous_lvr != new_lvr
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
    
    if has_mortgage_type_changes?
      changes << {
        field: 'Mortgage Type',
        from: mortgage_type_label(previous_mortgage_type),
        to: mortgage_type_label(new_mortgage_type)
      }
    end
    
    if has_lvr_changes?
      changes << {
        field: 'LVR',
        from: format_lvr_for_display(previous_lvr),
        to: format_lvr_for_display(new_lvr)
      }
    end
    
    changes
  end
  
  private
  
  def format_lvr_for_display(lvr_value)
    return '' unless lvr_value.present?
    
    if lvr_value % 1 == 0
      "#{lvr_value.to_i}%"
    else
      "#{lvr_value}%"
    end
  end
  
  def mortgage_type_label(type_value)
    case type_value
    when 0
      'Interest Only'
    when 1
      'Principal and Interest'
    else
      type_value.to_s
    end
  end
end