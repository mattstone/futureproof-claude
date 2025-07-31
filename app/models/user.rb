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
end
