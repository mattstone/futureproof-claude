class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :applications, dependent: :destroy
  belongs_to :agreed_terms, class_name: 'TermsOfUse', foreign_key: 'terms_version', primary_key: 'version', optional: true

  # Temporary attribute to store home value during registration
  attr_accessor :pending_home_value

  # Validations
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

  private

  def valid_mobile_phone_number
    return if mobile_number.blank? # Skip validation if mobile number is blank
    
    unless valid_mobile_phone?
      errors.add(:mobile_number, "is not a valid phone number for the selected country")
    end
  end
end
