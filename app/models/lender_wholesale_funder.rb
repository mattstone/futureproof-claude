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
    was_active = active?
    self.active = !active
    
    # If deactivating, cascade to all related funder pools
    if was_active && !active?
      deactivate_related_funder_pools!
    end
    
    save!
  end
  
  # Deactivate all funder pools related to this wholesale funder for this lender
  def deactivate_related_funder_pools!
    related_pool_relationships = lender.lender_funder_pools
                                      .joins(:funder_pool)
                                      .where(funder_pools: { wholesale_funder: wholesale_funder })
                                      .where(active: true)
    
    related_pool_relationships.each do |pool_relationship|
      pool_relationship.current_user = current_user if pool_relationship.respond_to?(:current_user=)
      pool_relationship.update!(active: false)
    end
  end
end
