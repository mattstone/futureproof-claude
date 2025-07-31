class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  # Skip authentication for verification pages since users aren't logged in yet
  skip_before_action :authenticate_user!, if: :verification_controller?

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :country_of_residence])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :country_of_residence])
  end

  def verification_controller?
    controller_name == 'verifications' && controller_path == 'users/verifications'
  end
end
