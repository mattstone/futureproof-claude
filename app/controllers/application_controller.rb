class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # CSRF protection - verify authenticity tokens on all requests
  protect_from_forgery with: :exception, prepend: true
  
  # Security headers
  before_action :set_security_headers
  
  before_action :authenticate_user!
  before_action :ensure_email_verified!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :load_unread_message_count, if: :user_signed_in?
  
  # Skip authentication for verification pages since users aren't logged in yet
  skip_before_action :authenticate_user!, if: :verification_controller?
  skip_before_action :ensure_email_verified!, if: :verification_or_devise_controller?

  private

  def ensure_email_verified!
    return unless user_signed_in?
    return if current_user.confirmed?
    
    # Redirect unverified users to verification page with message
    flash[:alert] = "Please verify your email address before accessing your account."
    redirect_to new_users_verification_path(email: current_user.email)
  end

  # Override Devise redirect after sign in
  def after_sign_in_path_for(resource)
    # Check email verification first
    unless resource.confirmed?
      flash[:notice] = "Please verify your email address to access your account."
      return new_users_verification_path(email: resource.email)
    end
    
    # Check if user has pending message access from email link
    if session[:pending_message_access] && 
       session[:pending_message_access]['user_id'] == resource.id &&
       session[:pending_message_access]['token_verified'] &&
       session[:pending_message_access]['expires_at'] > Time.current.to_i
      
      # Clear the session data
      session.delete(:pending_message_access)
      
      # Redirect to dashboard where they can see their messages
      dashboard_path
    elsif resource.admin?
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

  def verification_or_devise_controller?
    verification_controller? || devise_controller?
  end
  
  def load_unread_message_count
    return unless user_signed_in?
    
    @unread_message_count = current_user.applications.joins(:application_messages)
      .where(application_messages: { message_type: 'admin_to_customer', status: 'sent' })
      .count('application_messages.id')
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
