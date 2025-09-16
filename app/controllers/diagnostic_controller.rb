class DiagnosticController < ApplicationController
  # Skip authentication for public debug endpoint
  skip_before_action :authenticate_user!, only: [:sso_debug_public]
  skip_before_action :ensure_email_verified!, only: [:sso_debug_public]

  # Only allow admin access for detailed debug
  before_action :ensure_admin_or_development, only: [:sso_debug]

  def sso_debug
    @azure_client_id_present = ENV['AZURE_CLIENT_ID'].present?
    @azure_client_secret_present = ENV['AZURE_CLIENT_SECRET'].present?

    # SAML configuration check
    @saml_sso_url_present = ENV['MICROSOFT_SAML_SSO_URL'].present?
    @saml_cert_present = ENV['MICROSOFT_SAML_CERT'].present?

    @available_providers = User.available_omniauth_providers
    @tenant_detection = TenantDetectionService.admin_domain?(request.host)
    @current_host = request.host
  end

  def sso_debug_public
    @azure_client_id_present = ENV['AZURE_CLIENT_ID'].present?
    @azure_client_secret_present = ENV['AZURE_CLIENT_SECRET'].present?

    # Check Rails credentials too (safely)
    begin
      @azure_client_id_from_credentials = Rails.application.credentials.dig(:azure, :client_id).present?
      @azure_client_secret_from_credentials = Rails.application.credentials.dig(:azure, :client_secret).present?
    rescue
      @azure_client_id_from_credentials = false
      @azure_client_secret_from_credentials = false
    end

    # SAML configuration check
    @saml_sso_url_present = ENV['MICROSOFT_SAML_SSO_URL'].present?
    @saml_cert_present = ENV['MICROSOFT_SAML_CERT'].present?

    @available_providers = User.available_omniauth_providers
    @tenant_detection = TenantDetectionService.admin_domain?(request.host)
    @current_host = request.host
    @hide_sensitive = true

    render :sso_debug
  end

  private

  def ensure_admin_or_development
    unless Rails.env.development? || (current_user&.admin?)
      redirect_to root_path, alert: 'Access denied'
    end
  end
end