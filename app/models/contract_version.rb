class ContractVersion < ApplicationRecord
  belongs_to :contract
  belongs_to :admin_user, class_name: 'User'
  
  validates :action, presence: true, inclusion: { in: %w[created updated viewed status_changed] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :changes_only, -> { where.not(action: 'viewed') }
  scope :views_only, -> { where(action: 'viewed') }
  
  # Action descriptions for display
  def action_description
    case action
    when 'created'
      'created contract'
    when 'updated'
      'updated contract information'
    when 'viewed'
      'viewed contract'
    when 'status_changed'
      'changed contract status'
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
    has_status_changes? || has_date_changes? || has_application_changes?
  end
  
  def has_status_changes?
    previous_status.present? && new_status.present? && previous_status != new_status
  end
  
  def has_date_changes?
    has_start_date_changes? || has_end_date_changes?
  end
  
  def has_start_date_changes?
    previous_start_date.present? && new_start_date.present? && previous_start_date != new_start_date
  end
  
  def has_end_date_changes?
    previous_end_date.present? && new_end_date.present? && previous_end_date != new_end_date
  end
  
  def has_application_changes?
    previous_application_id.present? && new_application_id.present? && previous_application_id != new_application_id
  end
  
  # Generate detailed change summary
  def detailed_changes
    changes = []
    
    if has_status_changes?
      changes << {
        field: 'Status',
        from: previous_status.humanize,
        to: new_status.humanize
      }
    end
    
    if has_start_date_changes?
      changes << {
        field: 'Start Date',
        from: format_date(previous_start_date),
        to: format_date(new_start_date)
      }
    end
    
    if has_end_date_changes?
      changes << {
        field: 'End Date',
        from: format_date(previous_end_date),
        to: format_date(new_end_date)
      }
    end
    
    if has_application_changes?
      changes << {
        field: 'Application',
        from: "Application ##{previous_application_id}",
        to: "Application ##{new_application_id}"
      }
    end
    
    changes
  end
  
  private
  
  def format_date(date)
    return '' unless date
    date.strftime("%B %d, %Y")
  end
end