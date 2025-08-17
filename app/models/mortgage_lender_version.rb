class MortgageLenderVersion < ApplicationRecord
  belongs_to :mortgage_lender
  belongs_to :user
  
  # Alias for consistency with shared change history interface
  alias_method :admin_user, :user
  
  validates :action, presence: true
  validates :change_details, presence: true
  
  scope :recent, -> { order(created_at: :desc) }
  
  def action_description
    mortgage_lender&.action_description || change_details
  end
  
  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end
  
  def lender_name
    mortgage_lender&.lender&.name || 'Unknown Lender'
  end
  
  def mortgage_name
    mortgage_lender&.mortgage&.name || 'Unknown Mortgage'
  end
end
