# Secure Headers configuration
SecureHeaders::Configuration.default do |config|
  # SecureHeaders handles cookies differently - disable it and let Rails handle cookies
  config.cookies = SecureHeaders::OPT_OUT
  
  config.hsts = "max-age=31536000; includeSubdomains; preload"
  
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "1; mode=block"
  config.x_permitted_cross_domain_policies = "none"
  config.referrer_policy = "strict-origin-when-cross-origin"
  
  # Content Security Policy is handled in content_security_policy.rb
  config.csp = SecureHeaders::OPT_OUT
  
  # Disable in development to avoid breaking functionality during development
  config.hsts = SecureHeaders::OPT_OUT if Rails.env.development? || Rails.env.test?
end