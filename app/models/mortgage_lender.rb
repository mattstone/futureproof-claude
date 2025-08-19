class MortgageLender < ApplicationRecord
  include ChangeTracking
  
  # Change tracking configuration
  version_association :mortgage_lender_versions
  track_changes :active
  
  belongs_to :mortgage
  belongs_to :lender
  
  validates :mortgage_id, presence: true
  validates :lender_id, presence: true
  validates :mortgage_id, uniqueness: { scope: :lender_id, message: "Lender is already associated with this mortgage" }
  
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  
  # Utility methods
  def status_display
    active? ? 'Active' : 'Inactive'
  end
  
  def status_badge_class
    active? ? 'status-active' : 'status-inactive'
  end
  
  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end
end