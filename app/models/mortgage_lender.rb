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
  
  # Audit trail methods
  def action_description
    lender_name = lender&.name || 'lender'
    mortgage_name = mortgage&.name || 'mortgage'
    
    case action
    when 'created'
      if active?
        "added lender relationship with #{lender_name} to mortgage #{mortgage_name}"
      else
        "added inactive lender relationship with #{lender_name} to mortgage #{mortgage_name}"
      end
    when 'updated'
      if saved_change_to_active?
        if active?
          "activated lender relationship with #{lender_name} for mortgage #{mortgage_name}"
        else
          "deactivated lender relationship with #{lender_name} for mortgage #{mortgage_name}"
        end
      else
        "updated lender relationship with #{lender_name} for mortgage #{mortgage_name}"
      end
    when 'destroyed'
      "removed lender relationship with #{lender_name} from mortgage #{mortgage_name}"
    else
      "#{action} lender relationship with #{lender_name} for mortgage #{mortgage_name}"
    end
  end
  
  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end
end