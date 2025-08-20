class ApplicationChecklist < ApplicationRecord
  belongs_to :application
  belongs_to :completed_by, class_name: 'User', optional: true
  
  validates :name, presence: true
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  scope :ordered, -> { order(:position) }
  scope :completed, -> { where(completed: true) }
  scope :pending, -> { where(completed: false) }
  
  # Standard checklist items for all applications
  STANDARD_CHECKLIST_ITEMS = [
    "Verification of identity check",
    "Property ownership verified", 
    "Existing mortgage status verified",
    "Signed contract"
  ].freeze
  
  def mark_completed!(user)
    update!(
      completed: true,
      completed_at: Time.current,
      completed_by: user
    )
  end
  
  def mark_incomplete!
    update!(
      completed: false,
      completed_at: nil,
      completed_by: nil
    )
  end
  
  def completed_by_name
    completed_by&.display_name || "Unknown"
  end
end
