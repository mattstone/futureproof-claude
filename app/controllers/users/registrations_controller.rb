class Users::RegistrationsController < Devise::RegistrationsController
  layout 'dashboard', only: [:edit, :update]

  # Override the update method to handle Turbo Stream responses
  def update
    self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
    prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

    resource_updated = update_resource(resource, account_update_params)
    yield resource if block_given?
    
    if resource_updated
      set_flash_message_for_update(resource, prev_unconfirmed_email)
      bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?

      respond_to do |format|
        format.html { redirect_to after_update_path_for(resource) }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("profile_form_container", partial: "profile_form_success", locals: { resource: resource }),
            turbo_stream.replace("profile_notices", partial: "shared/notice", locals: { notice: "Your profile has been updated successfully." })
          ]
        end
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("profile_form_container", partial: "profile_form_errors", locals: { resource: resource }),
            turbo_stream.replace("profile_notices", "")
          ]
        end
      end
    end
  end

  # Override the create method to handle reCAPTCHA and avoid routing issues
  def create
    Rails.logger.debug "reCAPTCHA verification starting..."
    Rails.logger.debug "Site key: #{ENV['RECAPTCHA_SITE_KEY']}"
    Rails.logger.debug "Secret key present: #{ENV['RECAPTCHA_SECRET_KEY'].present?}"
    Rails.logger.debug "Environment: #{Rails.env}"
    
    # In development, always bypass reCAPTCHA to avoid test key issues
    if Rails.env.development?
      Rails.logger.debug "Bypassing reCAPTCHA for development environment"
      recaptcha_result = true
    else
      Rails.logger.debug "Verifying reCAPTCHA in production"
      recaptcha_result = verify_recaptcha
    end
    
    Rails.logger.debug "reCAPTCHA result: #{recaptcha_result}"
    
    unless recaptcha_result
      Rails.logger.debug "reCAPTCHA failed, building resource with errors"
      build_resource(sign_up_params)
      resource.validate
      set_minimum_password_length
      resource.errors.add(:base, "reCAPTCHA verification failed, please try again.")
      render :new, status: :unprocessable_entity
      return
    end

    Rails.logger.debug "reCAPTCHA passed, creating user"
    
    # Build the user resource
    build_resource(sign_up_params)
    
    if resource.save
      # Generate and send verification code instead of using Devise confirmation
      resource.generate_verification_code
      UserMailer.verification_code(resource).deliver_now
      
      # Redirect to verification page
      redirect_to new_users_verification_path(email: resource.email)
    else
      set_minimum_password_length
      render :new, status: :unprocessable_entity
    end
  end

  protected

  # Override the path where user is redirected after successful registration
  def after_sign_up_path_for(resource)
    new_application_path
  end

  # Override the path where user is redirected after email confirmation
  def after_confirmation_path_for(resource_name, resource)
    new_application_path
  end

  # Override the path where user is redirected after failed sign up
  def after_inactive_sign_up_path_for(resource)
    new_user_session_path
  end

  private

  # Add a users_url method to prevent the undefined method error
  def users_url(options = {})
    user_registration_url(options)
  end

  # Also add users_path for completeness
  def users_path(options = {})
    user_registration_path(options)
  end

  # Strong parameters for user registration
  def sign_up_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :country_of_residence)
  end

  # Strong parameters for account update
  def account_update_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :current_password, :country_of_residence, :mobile_country_code, :mobile_number)
  end
end