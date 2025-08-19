class MortgageContractVersion < ApplicationRecord
  belongs_to :mortgage_contract
  belongs_to :user
  
  # Alias for consistency with shared change history interface
  alias_method :admin_user, :user
  
  validates :action, presence: true
  validates :change_details, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  scope :recent_first, -> { order(created_at: :desc) }
  
  def action_description
    change_details || action.humanize
  end
  
  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end
  
  def contract_title
    mortgage_contract&.title || 'Unknown Contract'
  end
  
  def contract_version
    mortgage_contract&.version || 'Unknown'
  end

  # Check if this version has detailed field changes to display
  def has_field_changes?
    # Check if we have any detailed changes data
    respond_to?(:detailed_changes) && detailed_changes.present?
  end

  # Provide detailed changes if available (placeholder for future implementation)
  def detailed_changes
    # For now, return empty array - this can be enhanced later
    # to show actual field-by-field changes if needed
    []
  end
end