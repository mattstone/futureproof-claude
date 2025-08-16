class LenderWholesaleFunder < ApplicationRecord
  include ChangeTracking
  
  # Change tracking configuration
  version_association :lender_wholesale_funder_versions
  track_changes :active
  
  belongs_to :lender
  belongs_to :wholesale_funder
  
  validates :lender_id, uniqueness: { scope: :wholesale_funder_id }
  validates :active, inclusion: { in: [true, false] }
  
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  
  def status_display
    active? ? 'Active' : 'Inactive'
  end
  
  def status_badge_class
    active? ? 'status-active' : 'status-inactive'
  end
  
  def toggle_active!
    update!(active: !active)
  end
end
