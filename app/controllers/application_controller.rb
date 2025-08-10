class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # CSRF protection - verify authenticity tokens on all requests
  protect_from_forgery with: :exception, prepend: true
  
  # Security headers
  before_action :set_security_headers
  
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  # Skip authentication for verification pages since users aren't logged in yet
  skip_before_action :authenticate_user!, if: :verification_controller?

  private

  # Override Devise redirect after sign in
  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_root_path
    else
      dashboard_path
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :country_of_residence])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :country_of_residence])
  end

  def verification_controller?
    controller_name == 'verifications' && controller_path == 'users/verifications'
  end
  
  def set_security_headers
    # Prevent clickjacking attacks
    response.headers['X-Frame-Options'] = 'DENY'
    
    # Prevent content type sniffing
    response.headers['X-Content-Type-Options'] = 'nosniff'
    
    # Enable XSS filtering in browsers
    response.headers['X-XSS-Protection'] = '1; mode=block'
    
    # Only allow HTTPS connections
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains' if request.ssl?
    
    # Prevent referrer leakage
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
  end
end
