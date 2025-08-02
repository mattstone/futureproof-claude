class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :applications, dependent: :destroy

  # Validations
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name, presence: true, length: { maximum: 50 }
  validates :country_of_residence, presence: true
  validates :mobile_number, format: { with: /\A[0-9\s\-\(\)]+\z/, message: "must contain only numbers, spaces, hyphens, and parentheses" }, allow_blank: true
  validates :mobile_country_code, presence: true, if: :mobile_number?

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
end
