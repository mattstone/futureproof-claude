class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  protect_from_forgery except: [:saml]
  before_action :set_current_lender

  def saml
    handle_omniauth_callback('saml')
  end

  def failure
    redirect_to new_user_session_path, alert: 'Authentication failed. Please try again.'
  end

  private

  def handle_omniauth_callback(provider)
    auth = request.env["omniauth.auth"]
    Rails.logger.info "[SSO_DEBUG] Starting #{provider} callback for email: #{auth&.info&.email}, host: #{request.host}"

    @user = User.from_omniauth(auth, @current_lender, TenantDetectionService.admin_domain?(request.host))
    Rails.logger.info "[SSO_DEBUG] User created/found: ID=#{@user&.id}, email=#{@user&.email}, admin=#{@user&.admin?}, persisted=#{@user&.persisted?}"

    if @user&.persisted?
      Rails.logger.info "[SSO_DEBUG] Before sign_in: current_user=#{current_user&.id}, user_signed_in=#{user_signed_in?}"

      sign_in @user, event: :authentication

      Rails.logger.info "[SSO_DEBUG] After sign_in: current_user=#{current_user&.id}, user_signed_in=#{user_signed_in?}, session_id=#{session.id}"
      Rails.logger.info "[SSO_DEBUG] Session contents: #{session.to_hash.except('session_id', '_csrf_token')}"

      redirect_path = after_sign_in_path_for(@user)
      Rails.logger.info "[SSO_DEBUG] Redirecting to: #{redirect_path}"

      set_flash_message(:notice, :success, kind: provider.humanize) if is_navigational_format?
      redirect_to redirect_path
    else
      Rails.logger.warn "[SSO_DEBUG] User not persisted, redirecting to registration"
      session["devise.#{provider}_data"] = auth.except(:extra)
      redirect_to new_user_registration_url, alert: 'Failed to authenticate. Please try again.'
    end
  end

  def set_current_lender
    @current_lender = TenantDetectionService.lender_from_domain(request.host)

    unless @current_lender
      redirect_to root_url, alert: 'Domain not configured for authentication.'
    end
  end
end