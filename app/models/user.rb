class User < ApplicationRecord
  # include InputSanitization  # Temporarily disabled for testing
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # Note: removed :validatable to implement custom scoped email validation
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :timeoutable, :omniauthable,
         omniauth_providers: [:saml]

  # Associations
  belongs_to :lender
  has_many :applications, dependent: :destroy
  belongs_to :agreed_terms, class_name: 'TermsOfUse', foreign_key: 'terms_version', primary_key: 'version', optional: true
  has_many :user_versions, dependent: :destroy
  
  # Mortgage contract relationships
  has_many :created_mortgage_contracts, class_name: 'MortgageContract', foreign_key: 'created_by_id', dependent: :nullify
  has_many :primary_mortgage_contracts, class_name: 'MortgageContract', foreign_key: 'primary_user_id', dependent: :nullify
  has_many :mortgage_contract_users, dependent: :destroy
  has_many :additional_mortgage_contracts, through: :mortgage_contract_users, source: :mortgage_contract

  # Temporary attribute to store home value during registration
  attr_accessor :pending_home_value
  
  # Track changes with audit functionality
  attr_accessor :current_admin_user
  
  # Callbacks for change tracking
  after_create :log_creation
  after_update :log_update

  # Validations
  # Custom email validation (replacing Devise :validatable)
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { scope: :lender_id, message: "is already taken for this lender" }
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  
  # Lender scoping validation
  validates :lender, presence: true
  
  # Existing validations
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name, presence: true, length: { maximum: 50 }
  validates :country_of_residence, presence: true
  validates :mobile_number, format: { with: /\A[0-9\s\-\(\)]+\z/, message: "must contain only numbers, spaces, hyphens, and parentheses" }, allow_blank: true
  validates :mobile_country_code, presence: true, if: :mobile_number?
  validate :valid_mobile_phone_number
  validates :terms_accepted, acceptance: { message: "You must accept the Terms of Use to create an account" }

  # Scopes
  scope :admins, -> { where(admin: true) }
  scope :regular_users, -> { where(admin: false) }

  # Devise authentication override for lender-scoped users
  def self.find_for_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if (email = conditions.delete(:email))
      lender_id = conditions.delete(:lender_id)
      
      # If lender_id is provided, use it for scoped lookup
      if lender_id.present?
        where(conditions.to_h).where(email: email, lender_id: lender_id).first
      else
        # Fallback: find user by email only (for Futureproof lender or single lender scenarios)
        # In production, you might want to default to Futureproof lender
        futureproof_lender = Lender.lender_type_futureproof.first
        if futureproof_lender
          where(conditions.to_h).where(email: email, lender_id: futureproof_lender.id).first
        else
          where(conditions.to_h).where(email: email).first
        end
      end
    elsif conditions.has_key?(:email)
      where(conditions.to_h).first
    end
  end

  # Methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def admin?
    admin
  end

  def display_name
    full_name.present? ? full_name : email
  end

  def full_mobile_number
    return nil unless mobile_country_code.present? && mobile_number.present?
    "#{mobile_country_code} #{mobile_number}"
  end

  def formatted_mobile_number
    return nil unless valid_mobile_phone?
    begin
      # Combine country code and number for formatting
      full_number = "#{mobile_country_code}#{mobile_number.gsub(/\D/, '')}"
      Phony.format(full_number, format: :international)
    rescue
      full_mobile_number # Fallback to original format
    end
  end

  def valid_mobile_phone?
    return true if mobile_number.blank? # Allow blank numbers
    return false unless mobile_country_code.present? && mobile_number.present?
    
    begin
      # Clean the mobile number and combine with country code
      clean_number = mobile_number.gsub(/\D/, '')
      full_number = "#{mobile_country_code}#{clean_number}"
      Phony.plausible?(full_number)
    rescue
      false
    end
  end

  # Verification code methods
  def generate_verification_code
    self.verification_code = sprintf('%06d', rand(1000000))
    self.verification_code_expires_at = 15.minutes.from_now
    save!
  end

  def verification_code_valid?(code)
    return false if verification_code.blank? || verification_code_expires_at.blank?
    return false if verification_code_expires_at < Time.current
    
    verification_code == code.to_s
  end

  def clear_verification_code
    self.verification_code = nil
    self.verification_code_expires_at = nil
    save!
  end

  def verification_code_expired?
    verification_code_expires_at.blank? || verification_code_expires_at < Time.current
  end

  def confirm_account!
    self.confirmed_at = Time.current
    clear_verification_code
    save!
    
    # Create an application with "created" status to track user progression
    # This allows us to track users who create an account but do not proceed with the application
    unless applications.exists?
      # Use pending_home_value if available, otherwise use default
      home_val = pending_home_value.present? ? pending_home_value.to_i : 1000000
      
      applications.create!(
        status: :created,
        home_value: home_val,
        ownership_status: :individual, # Default - to be updated by user
        property_state: :primary_residence, # Default - to be updated by user
        has_existing_mortgage: false, # Default - to be updated by user
        existing_mortgage_amount: 0, # Default - will be updated if has_existing_mortgage is true
        growth_rate: 2.0, # Default growth rate
        borrower_age: 60 # Default age for form display
        # Note: address will be auto-assigned by the Application model callback
      )
    end
  end

  def confirmed?
    confirmed_at.present?
  end

  # Security tracking methods
  def known_browser_signatures_array
    return [] if known_browser_signatures.blank?
    JSON.parse(known_browser_signatures)
  rescue JSON::ParserError
    []
  end

  def add_known_browser_signature(signature)
    current_signatures = known_browser_signatures_array
    return if current_signatures.include?(signature)
    
    current_signatures << signature
    # Keep only the last 10 browser signatures to prevent unlimited growth
    current_signatures = current_signatures.last(10)
    
    self.known_browser_signatures = current_signatures.to_json
    save!
  end

  def known_browser_signature?(signature)
    known_browser_signatures_array.include?(signature)
  end

  def update_browser_tracking(signature, browser_info)
    was_unknown = !known_browser_signature?(signature)
    
    # Update last browser signature and info
    self.last_browser_signature = signature
    self.last_browser_info = browser_info.to_json
    
    # Add to known signatures if not already known
    add_known_browser_signature(signature)
    
    was_unknown
  end

  def parsed_browser_info
    return {} if last_browser_info.blank?
    JSON.parse(last_browser_info)
  rescue JSON::ParserError
    {}
  end

  # Terms of Use methods
  def agreed_to_terms_version
    terms_version
  end

  def agreed_to_current_terms?
    return false if terms_version.blank?
    current_terms = TermsOfUse.current
    return false if current_terms.blank?
    terms_version == current_terms.version
  end
  
  # Log when admin views user profile
  def log_view_by(admin_user)
    return unless admin_user&.admin?

    user_versions.create!(
      admin_user: admin_user,
      action: 'viewed',
      change_details: "Admin #{admin_user.display_name} viewed user profile"
    )
  end

  # SSO Methods
  def self.from_omniauth(auth, lender, is_admin_domain = false)
    # Find existing user by SSO credentials within the lender scope
    user = where(sso_provider: auth.provider, sso_uid: auth.uid, lender: lender).first

    if user
      # Update user info from SSO
      user.update_from_sso(auth)
      user
    else
      # Check if user exists by email within this lender
      existing_user = where(email: auth.info.email, lender: lender).first

      if existing_user
        # Link existing account to SSO
        existing_user.update!(
          sso_provider: auth.provider,
          sso_uid: auth.uid
        )
        existing_user.update_from_sso(auth)
        existing_user
      else
        # Create new user for this lender
        create_from_sso(auth, lender, is_admin_domain)
      end
    end
  end

  def self.create_from_sso(auth, lender, is_admin_domain = false)
    # Extract name parts from auth (SAML specific)
    first_name = auth.info.first_name || auth.extra&.raw_info&.[]('http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname')&.first
    last_name = auth.info.last_name || auth.extra&.raw_info&.[]('http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname')&.first
    display_name = auth.info.name || auth.extra&.raw_info&.[]('http://schemas.xmlsoap.org/ws/2005/05/identity/claims/displayname')&.first

    # Fallback to parsing display name if first/last not available
    if first_name.blank? && display_name.present?
      name_parts = display_name.split(' ')
      first_name = name_parts.first
      last_name = name_parts[1..-1]&.join(' ')
    end

    create!(
      email: auth.info.email,
      first_name: first_name || 'SAML',
      last_name: last_name || 'User',
      lender: lender,
      sso_provider: auth.provider,
      sso_uid: auth.uid,
      admin: is_admin_domain, # Auto-assign admin for futureproofinancial.co
      confirmed_at: Time.current, # SSO users are pre-verified
      country_of_residence: 'United States', # Default for SSO users
      terms_accepted: true, # SSO implies terms acceptance
      terms_version: TermsOfUse.current&.version,
      password: Devise.friendly_token[0, 20] # Random password for SSO users
    )
  end

  def update_from_sso(auth)
    # Update name if provided and current values are empty/default
    updates = {}

    if auth.info.first_name.present? && (first_name == 'SSO' || first_name.blank?)
      updates[:first_name] = auth.info.first_name
    end

    if auth.info.last_name.present? && (last_name == 'User' || last_name.blank?)
      updates[:last_name] = auth.info.last_name
    end

    # Parse name if first/last not available but name is
    if auth.info.name.present? && (first_name == 'SSO' || last_name == 'User')
      name_parts = auth.info.name.split(' ')
      updates[:first_name] = name_parts.first if first_name == 'SSO'
      updates[:last_name] = name_parts[1..-1]&.join(' ') if last_name == 'User'
    end

    update!(updates)
  end

  def sso_user?
    sso_provider.present? && sso_uid.present?
  end

  # Class method to determine available omniauth providers based on environment
  def self.available_omniauth_providers
    providers = []

    # Add SAML - always available (Microsoft SAML SSO)
    # In production, SAML will work once MICROSOFT_SAML_SSO_URL is configured
    providers << :saml

    providers
  end

  private
  
  # Password validation helper (replacing Devise :validatable)
  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end
  
  def log_creation
    return unless current_admin_user&.admin?
    
    user_versions.create!(
      admin_user: current_admin_user,
      action: 'created',
      change_details: "Created user account for #{display_name}",
      new_first_name: first_name,
      new_last_name: last_name,
      new_email: email,
      new_admin: admin,
      new_country_of_residence: country_of_residence,
      new_mobile_number: mobile_number,
      new_mobile_country_code: mobile_country_code,
      new_terms_version: terms_version,
      new_confirmed_at: confirmed_at
    )
  end
  
  def log_update
    return unless current_admin_user&.admin?
    return unless saved_changes.any?
    
    # Special handling for admin role changes
    if saved_change_to_admin?
      action = admin? ? 'admin_promoted' : 'admin_demoted'
      change_details = admin? ? "Promoted #{display_name} to admin" : "Removed admin privileges from #{display_name}"
    elsif saved_change_to_confirmed_at?
      action = 'confirmed'
      change_details = "Confirmed user account for #{display_name}"
    else
      action = 'updated'
      change_details = build_change_summary
    end
    
    user_versions.create!(
      admin_user: current_admin_user,
      action: action,
      change_details: change_details,
      previous_first_name: saved_change_to_first_name ? saved_change_to_first_name[0] : nil,
      new_first_name: saved_change_to_first_name ? saved_change_to_first_name[1] : nil,
      previous_last_name: saved_change_to_last_name ? saved_change_to_last_name[0] : nil,
      new_last_name: saved_change_to_last_name ? saved_change_to_last_name[1] : nil,
      previous_email: saved_change_to_email ? saved_change_to_email[0] : nil,
      new_email: saved_change_to_email ? saved_change_to_email[1] : nil,
      previous_admin: saved_change_to_admin ? saved_change_to_admin[0] : nil,
      new_admin: saved_change_to_admin ? saved_change_to_admin[1] : nil,
      previous_country_of_residence: saved_change_to_country_of_residence ? saved_change_to_country_of_residence[0] : nil,
      new_country_of_residence: saved_change_to_country_of_residence ? saved_change_to_country_of_residence[1] : nil,
      previous_mobile_number: saved_change_to_mobile_number ? saved_change_to_mobile_number[0] : nil,
      new_mobile_number: saved_change_to_mobile_number ? saved_change_to_mobile_number[1] : nil,
      previous_mobile_country_code: saved_change_to_mobile_country_code ? saved_change_to_mobile_country_code[0] : nil,
      new_mobile_country_code: saved_change_to_mobile_country_code ? saved_change_to_mobile_country_code[1] : nil,
      previous_terms_version: saved_change_to_terms_version ? saved_change_to_terms_version[0] : nil,
      new_terms_version: saved_change_to_terms_version ? saved_change_to_terms_version[1] : nil,
      previous_confirmed_at: saved_change_to_confirmed_at ? saved_change_to_confirmed_at[0] : nil,
      new_confirmed_at: saved_change_to_confirmed_at ? saved_change_to_confirmed_at[1] : nil
    )
  end
  
  def build_change_summary
    changes_list = []
    
    if saved_change_to_first_name?
      changes_list << "First name changed from '#{saved_change_to_first_name[0]}' to '#{saved_change_to_first_name[1]}'"
    end
    
    if saved_change_to_last_name?
      changes_list << "Last name changed from '#{saved_change_to_last_name[0]}' to '#{saved_change_to_last_name[1]}'"
    end
    
    if saved_change_to_email?
      changes_list << "Email changed from '#{saved_change_to_email[0]}' to '#{saved_change_to_email[1]}'"
    end
    
    if saved_change_to_country_of_residence?
      changes_list << "Country changed from '#{saved_change_to_country_of_residence[0]}' to '#{saved_change_to_country_of_residence[1]}'"
    end
    
    if saved_change_to_mobile_number?
      old_mobile = format_mobile_change(saved_change_to_mobile_country_code ? saved_change_to_mobile_country_code[0] : mobile_country_code, saved_change_to_mobile_number[0])
      new_mobile = format_mobile_change(mobile_country_code, saved_change_to_mobile_number[1])
      changes_list << "Mobile number changed from '#{old_mobile}' to '#{new_mobile}'"
    end
    
    if saved_change_to_terms_version?
      changes_list << "Terms version changed from #{saved_change_to_terms_version[0]} to #{saved_change_to_terms_version[1]}"
    end
    
    changes_list.join("; ")
  end
  
  def format_mobile_change(country_code, number)
    return number || '' unless country_code.present?
    "#{country_code} #{number}"
  end

  def valid_mobile_phone_number
    return if mobile_number.blank? # Skip validation if mobile number is blank

    unless valid_mobile_phone?
      errors.add(:mobile_number, "is not a valid phone number for the selected country")
    end
  end
end
