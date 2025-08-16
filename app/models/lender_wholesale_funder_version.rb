class LenderWholesaleFunderVersion < ApplicationRecord
  belongs_to :lender_wholesale_funder
  belongs_to :user
  alias_method :admin_user, :user
  
  validates :action, presence: true
  validates :change_details, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :changes_only, -> { where.not(action: 'viewed') }
  scope :views_only, -> { where(action: 'viewed') }
  
  def action_description
    case action
    when 'created'
      'added wholesale funder relationship'
    when 'updated' 
      'updated wholesale funder relationship'
    when 'viewed'
      'viewed wholesale funder relationship'
    else
      action
    end
  end
  
  def has_field_changes?
    previous_active.present? || new_active.present?
  end
  
  def detailed_changes
    changes = []
    
    if has_active_changes?
      changes << {
        field: 'Status',
        from: format_active_status(previous_active),
        to: format_active_status(new_active)
      }
    end
    
    changes
  end
  
  private
  
  def has_active_changes?
    previous_active.present? && new_active.present? && previous_active != new_active
  end
  
  def format_active_status(status)
    case status
    when true
      'Active'
    when false  
      'Inactive'
    else
      status.to_s
    end
  end
end