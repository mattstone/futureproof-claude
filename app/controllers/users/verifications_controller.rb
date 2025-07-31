class Users::VerificationsController < ApplicationController
  before_action :find_user_by_email, only: [:new, :create, :resend]
  before_action :redirect_if_confirmed, only: [:new, :create, :resend]

  def new
    # Show verification form
  end

  def create
    verification_code = params[:verification_code]

    if @user.verification_code_valid?(verification_code)
      @user.confirm_account!
      sign_in(@user) # Log the user in
      redirect_to new_application_path, notice: 'Your account has been successfully verified!'
    else
      if @user.verification_code_expired?
        flash.now[:alert] = 'Verification code has expired. Please request a new one.'
      else
        flash.now[:alert] = 'Invalid verification code. Please try again.'
      end
      render :new, status: :unprocessable_entity
    end
  end

  def resend
    @user.generate_verification_code
    UserMailer.verification_code(@user).deliver_now
    redirect_to new_users_verification_path(email: @user.email), 
                notice: 'A new verification code has been sent to your email.'
  end

  private

  def find_user_by_email
    email = params[:email]
    @user = User.find_by(email: email)
    
    if @user.nil?
      redirect_to new_user_registration_path, alert: 'User not found.'
    end
  end

  def redirect_if_confirmed
    if @user&.confirmed?
      redirect_to new_application_path, notice: 'Your account is already verified.'
    end
  end
end
