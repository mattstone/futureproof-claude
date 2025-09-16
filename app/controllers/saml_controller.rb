class SamlController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_email_verified!

  def metadata
    # Generate SAML metadata XML for Microsoft to consume
    settings = OneLogin::RubySaml::Settings.new

    # Service Provider (us)
    settings.sp_entity_id = "futureproof-financial-saml"
    settings.assertion_consumer_service_url = "#{request.protocol}#{request.host_with_port}/users/auth/saml/callback"
    settings.name_identifier_format = "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"

    # Generate metadata
    meta = OneLogin::RubySaml::Metadata.new
    xml = meta.generate(settings, true)

    render xml: xml, content_type: 'application/samlmetadata+xml'
  rescue => e
    Rails.logger.error "SAML metadata error: #{e.message}"
    render plain: "SAML metadata generation error: #{e.message}", status: :internal_server_error
  end
end