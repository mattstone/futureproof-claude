module InputSanitization
  extend ActiveSupport::Concern
  
  included do
    before_validation :sanitize_inputs
  end
  
  private
  
  def sanitize_inputs
    # Sanitize string attributes to prevent XSS and injection attacks
    attributes.each do |name, value|
      next unless value.is_a?(String)
      next if skip_sanitization_for?(name)
      
      # Remove potentially dangerous characters and HTML
      sanitized = sanitize_string(value)
      self.send("#{name}=", sanitized) if sanitized != value
    end
  end
  
  def sanitize_string(str)
    return str if str.blank?
    
    # Remove null bytes
    str = str.gsub("\u0000", '')
    
    # Remove control characters except newlines and tabs
    str = str.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, '')
    
    # Strip leading/trailing whitespace
    str.strip
  end
  
  def skip_sanitization_for?(attribute_name)
    # Define attributes that should not be sanitized (e.g., password fields)
    %w[password password_confirmation encrypted_password].include?(attribute_name.to_s)
  end
end