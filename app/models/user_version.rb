class UserVersion < ApplicationRecord
  belongs_to :user
  belongs_to :admin_user, class_name: 'User'
  
  validates :action, presence: true, inclusion: { in: %w[created updated viewed admin_promoted admin_demoted confirmed] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :changes_only, -> { where.not(action: 'viewed') }
  scope :views_only, -> { where(action: 'viewed') }
  
  # Action descriptions for display
  def action_description
    case action
    when 'created'
      'created user account'
    when 'updated'
      'updated user information'
    when 'viewed'
      'viewed user profile'
    when 'admin_promoted'
      'promoted user to admin'
    when 'admin_demoted'
      'removed admin privileges'
    when 'confirmed'
      'confirmed user account'
    else
      action
    end
  end
  
  # Formatted creation time
  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end
  
  # Check if this version has field changes to display
  def has_field_changes?
    has_name_changes? || has_email_changes? || has_admin_changes? || 
    has_country_changes? || has_mobile_changes? || has_terms_changes? || has_confirmation_changes?
  end
  
  def has_name_changes?
    (previous_first_name.present? && new_first_name.present? && previous_first_name != new_first_name) ||
    (previous_last_name.present? && new_last_name.present? && previous_last_name != new_last_name)
  end
  
  def has_email_changes?
    previous_email.present? && new_email.present? && previous_email != new_email
  end
  
  def has_admin_changes?
    !previous_admin.nil? && !new_admin.nil? && previous_admin != new_admin
  end
  
  def has_country_changes?
    previous_country_of_residence.present? && new_country_of_residence.present? && 
    previous_country_of_residence != new_country_of_residence
  end
  
  def has_mobile_changes?
    (previous_mobile_number.present? && new_mobile_number.present? && previous_mobile_number != new_mobile_number) ||
    (previous_mobile_country_code.present? && new_mobile_country_code.present? && previous_mobile_country_code != new_mobile_country_code)
  end
  
  def has_terms_changes?
    previous_terms_version.present? && new_terms_version.present? && previous_terms_version != new_terms_version
  end
  
  def has_confirmation_changes?
    previous_confirmed_at != new_confirmed_at
  end
  
  # Generate detailed change summary
  def detailed_changes
    changes = []
    
    if previous_first_name.present? && new_first_name.present? && previous_first_name != new_first_name
      changes << {
        field: 'First Name',
        from: previous_first_name,
        to: new_first_name
      }
    end
    
    if previous_last_name.present? && new_last_name.present? && previous_last_name != new_last_name
      changes << {
        field: 'Last Name',
        from: previous_last_name,
        to: new_last_name
      }
    end
    
    if has_email_changes?
      changes << {
        field: 'Email',
        from: previous_email,
        to: new_email
      }
    end
    
    if has_admin_changes?
      changes << {
        field: 'Role',
        from: previous_admin ? 'Admin' : 'User',
        to: new_admin ? 'Admin' : 'User'
      }
    end
    
    if has_country_changes?
      changes << {
        field: 'Country of Residence',
        from: previous_country_of_residence,
        to: new_country_of_residence
      }
    end
    
    if previous_mobile_number.present? && new_mobile_number.present? && previous_mobile_number != new_mobile_number
      changes << {
        field: 'Mobile Number',
        from: format_mobile(previous_mobile_country_code, previous_mobile_number),
        to: format_mobile(new_mobile_country_code, new_mobile_number)
      }
    end
    
    if has_terms_changes?
      changes << {
        field: 'Terms Version',
        from: previous_terms_version.to_s,
        to: new_terms_version.to_s
      }
    end
    
    if has_confirmation_changes?
      changes << {
        field: 'Account Status',
        from: previous_confirmed_at ? 'Confirmed' : 'Pending',
        to: new_confirmed_at ? 'Confirmed' : 'Pending'
      }
    end
    
    changes
  end
  
  private
  
  def format_mobile(country_code, number)
    return number unless country_code.present?
    "#{country_code} #{number}"
  end
end