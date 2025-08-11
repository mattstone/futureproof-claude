require 'test_helper'

class MessageEncryptorTest < ActiveSupport::TestCase
  self.use_transactional_tests = true
  
  # Override fixtures to use none
  self.fixture_paths = []
  self.set_fixture_class({})
  
  # Disable fixture loading
  def load_fixtures(*); end
  test "SecureTokenEncryptor should be available" do
    assert defined?(SecureTokenEncryptor)
  end
  
  test "SecureTokenEncryptor should work correctly" do
    encryptor = SecureTokenEncryptor.instance
    assert_not_nil encryptor
    assert encryptor.is_a?(ActiveSupport::MessageEncryptor)
  end
  
  test "should encrypt and decrypt data correctly" do
    data = { 
      application_id: 123,
      user_id: 456,
      expires_at: 24.hours.from_now.to_i
    }
    
    # Use SecureTokenEncryptor instead of Rails.application.message_encryptor
    encrypted = SecureTokenEncryptor.encrypt_and_sign(data)
    
    assert_not_nil encrypted
    assert encrypted.is_a?(String)
    assert encrypted.length > 0
    
    decrypted = SecureTokenEncryptor.decrypt_and_verify(encrypted)
    assert_equal data[:application_id], decrypted['application_id']
    assert_equal data[:user_id], decrypted['user_id']
    assert_equal data[:expires_at], decrypted['expires_at']
  end
  
  test "should reject tampered tokens" do
    data = { test: 'data' }
    # Use SecureTokenEncryptor instead of Rails.application.message_encryptor
    encrypted = SecureTokenEncryptor.encrypt_and_sign(data)
    
    # Tamper with the token
    tampered = encrypted[0..-2] + 'X'  # Change last character
    
    assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) do
      SecureTokenEncryptor.decrypt_and_verify(tampered)
    end
  end
  
  test "should handle invalid tokens gracefully" do
    # Use SecureTokenEncryptor instead of Rails.application.message_encryptor
    
    assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) do
      SecureTokenEncryptor.decrypt_and_verify('invalid_token')
    end
    
    assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) do
      SecureTokenEncryptor.decrypt_and_verify('')
    end
    
    assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) do
      SecureTokenEncryptor.decrypt_and_verify(nil)
    end
  end
  
  test "ApplicationMailer generate_secure_token method should work" do
    user = User.new(id: 123, email: 'test@example.com')
    application = Application.new(id: 456)
    
    mailer = ApplicationMailer.new
    mailer.instance_variable_set(:@user, user)
    mailer.instance_variable_set(:@application, application)
    
    token = mailer.send(:generate_secure_token)
    
    assert_not_nil token
    assert token.is_a?(String)
    assert token.length > 0
    
    # Verify token can be decrypted
    # Use SecureTokenEncryptor instead of Rails.application.message_encryptor
    payload = SecureTokenEncryptor.decrypt_and_verify(token)
    
    assert_equal 456, payload['application_id']
    assert_equal 123, payload['user_id']
    assert payload['expires_at'] > Time.current.to_i
  end
  
  test "should use consistent encryptor instances" do
    # Use SecureTokenEncryptor for consistent encryption/decryption
    data = { test: 'consistency' }
    encrypted = SecureTokenEncryptor.encrypt_and_sign(data)
    decrypted = SecureTokenEncryptor.decrypt_and_verify(encrypted)
    
    assert_equal data[:test], decrypted['test']
  end
end