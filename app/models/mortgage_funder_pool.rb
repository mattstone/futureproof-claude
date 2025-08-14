class MortgageFunderPool < ApplicationRecord
  belongs_to :mortgage
  belongs_to :funder_pool
  
  validates :mortgage_id, uniqueness: { scope: :funder_pool_id }
  
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