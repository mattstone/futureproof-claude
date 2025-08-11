class SecureTokenEncryptor
  def self.instance
    @instance ||= ActiveSupport::MessageEncryptor.new(
      Rails.application.secret_key_base[0, 32]
    )
  end
  
  def self.encrypt_and_sign(data)
    instance.encrypt_and_sign(data)
  end
  
  def self.decrypt_and_verify(token)
    raise ActiveSupport::MessageEncryptor::InvalidMessage if token.nil? || token.empty?
    instance.decrypt_and_verify(token)
  end
end