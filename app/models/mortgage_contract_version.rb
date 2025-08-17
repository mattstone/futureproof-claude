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
end