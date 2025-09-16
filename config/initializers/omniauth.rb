# SAML SSO Configuration for Microsoft
Rails.application.config.middleware.use OmniAuth::Builder do
  # Microsoft SAML Configuration using Rails credentials
  # Fallback to environment variables for development/testing
  saml_config = Rails.application.credentials.microsoft_saml

  if saml_config.present?
    # Use Rails credentials (preferred)
    saml_settings = {
      assertion_consumer_service_url: "#{Rails.application.config.force_ssl ? 'https' : 'http'}://#{Rails.env.production? ? 'demo.futureprooffinancial.co' : 'localhost:3000'}/users/auth/saml/callback",
      issuer: "futureproof-financial-saml",
      idp_sso_target_url: saml_config[:sso_url],
      idp_cert: saml_config[:certificate],
      name_identifier_format: "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent",
      uid_attribute: "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name",
      attribute_statements: {
        email: ["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"],
        first_name: ["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"],
        last_name: ["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"],
        name: ["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/displayname"]
      }
    }
  else
    # Fallback to environment variables
    saml_settings = {
      assertion_consumer_service_url: "#{Rails.application.config.force_ssl ? 'https' : 'http'}://#{Rails.env.production? ? 'demo.futureprooffinancial.co' : 'localhost:3000'}/users/auth/saml/callback",
      issuer: "futureproof-financial-saml",
      idp_sso_target_url: ENV['MICROSOFT_SAML_SSO_URL'],
      idp_cert: ENV['MICROSOFT_SAML_CERT'],
      name_identifier_format: "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent",
      uid_attribute: "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name",
      attribute_statements: {
        email: ["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"],
        first_name: ["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"],
        last_name: ["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"],
        name: ["http://schemas.xmlsoap.org/ws/2005/05/identity/claims/displayname"]
      }
    }
  end

  # Add SAML provider - always add it, but it will only work when properly configured
  provider :saml, saml_settings
end

# Configure OmniAuth settings
OmniAuth.config.logger = Rails.logger
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true