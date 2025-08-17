class LenderFunderPool < ApplicationRecord
  include ChangeTracking
  
  # Change tracking configuration
  version_association :lender_funder_pool_versions
  track_changes :active
  
  belongs_to :lender
  belongs_to :funder_pool
  
  validates :lender_id, uniqueness: { scope: :funder_pool_id }
  validates :active, inclusion: { in: [true, false] }
  
  # Validate that lender has relationship with the wholesale funder
  validate :lender_must_have_wholesale_funder_relationship
  
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  
  def status_display
    active? ? 'Active' : 'Inactive'
  end
  
  def status_badge_class
    active? ? 'status-active' : 'status-inactive'
  end
  
  def toggle_active!
    self.active = !active
    save!
  end
  
  def wholesale_funder
    funder_pool&.wholesale_funder
  end
  
  private
  
  def lender_must_have_wholesale_funder_relationship
    return unless lender && funder_pool
    
    unless lender.lender_wholesale_funders.active.joins(:wholesale_funder).where(wholesale_funders: { id: funder_pool.wholesale_funder_id }).exists?
      errors.add(:funder_pool, "can only be selected if lender has an active relationship with the wholesale funder")
    end
  end
end
