class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
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

    @user = User.from_omniauth(auth, @current_lender, TenantDetectionService.admin_domain?(request.host))

    if @user&.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: provider.humanize) if is_navigational_format?
    else
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