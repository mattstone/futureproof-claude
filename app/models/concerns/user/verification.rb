# User verification concern
# Handles email verification code generation and validation
module User::Verification
  extend ActiveSupport::Concern

  included do
    # No additional associations or validations needed here
    # as they're defined in the main User model
  end

  # Generate a new verification code
  def generate_verification_code
    self.verification_code = SecureRandom.random_number(10**6).to_s.rjust(6, '0')
    self.verification_code_expires_at = 15.minutes.from_now
    save
  end

  # Verify the code and mark user as confirmed
  def verify_code(code)
    return false if verification_code.blank?
    return false if verification_code_expires_at < Time.current
    return false unless verification_code == code

    self.confirmed_at = Time.current
    self.verification_code = nil
    self.verification_code_expires_at = nil
    save
  end

  # Check if verification code is expired
  def verification_code_expired?
    return true if verification_code_expires_at.nil?
    verification_code_expires_at < Time.current
  end

  # Check if user needs verification
  def needs_verification?
    !confirmed? && verification_code.present?
  end
end