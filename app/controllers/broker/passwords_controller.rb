module Broker
  class PasswordsController < ApplicationController
    before_action :set_broker_from_token, only: [:new, :create]
    skip_before_action :verify_authenticity_token, only: [:create] # Allow password setup without session

    # Show password setup form (first login)
    def new
      @page_title = 'Set Up Your Password'
    end

    # Create password after setup
    def create
      if password_params[:password].blank?
        flash[:alert] = 'Password cannot be blank'
        render :new
        return
      end

      if password_params[:password] != password_params[:password_confirmation]
        flash[:alert] = 'Passwords do not match'
        render :new
        return
      end

      @broker.password = password_params[:password]
      @broker.password_confirmation = password_params[:password_confirmation]

      if @broker.save
        flash[:notice] = 'Password set successfully. You can now sign in.'
        redirect_to new_broker_session_path
      else
        flash[:alert] = 'Failed to set password: ' + @broker.errors.full_messages.join(', ')
        render :new
      end
    end

    # Show password reset form (forgot password)
    def edit
      @broker = Broker.find_by(reset_password_token: params[:token])
      unless @broker
        flash[:alert] = 'Invalid or expired password reset link'
        redirect_to new_broker_session_path
      end
    end

    # Update password after reset
    def update
      @broker = Broker.find_by(reset_password_token: params[:token])
      unless @broker
        flash[:alert] = 'Invalid or expired password reset link'
        redirect_to new_broker_session_path
        return
      end

      if password_params[:password].blank?
        flash[:alert] = 'Password cannot be blank'
        render :edit
        return
      end

      if password_params[:password] != password_params[:password_confirmation]
        flash[:alert] = 'Passwords do not match'
        render :edit
        return
      end

      @broker.password = password_params[:password]
      @broker.password_confirmation = password_params[:password_confirmation]
      @broker.reset_password_token = nil # Clear reset token
      @broker.reset_password_sent_at = nil

      if @broker.save
        flash[:notice] = 'Password reset successfully. You can now sign in.'
        redirect_to new_broker_session_path
      else
        flash[:alert] = 'Failed to reset password: ' + @broker.errors.full_messages.join(', ')
        render :edit
      end
    end

    private

    def set_broker_from_token
      @broker = Broker.find_by(reset_password_token: params[:token])
      unless @broker
        flash[:alert] = 'Invalid or expired password setup link'
        redirect_to new_broker_session_path
      end
    end

    def password_params
      params.require(:broker).permit(:password, :password_confirmation)
    end
  end
end
