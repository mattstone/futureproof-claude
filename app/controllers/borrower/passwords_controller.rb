module Borrower
  class PasswordsController < BaseController
    # Show password change form
    def edit
    end

    # Update password
    def update
      if current_user.update_with_password(password_params)
        redirect_to borrower_account_path, notice: "Password changed successfully."
      else
        flash.now[:alert] = current_user.errors.full_messages.join(", ")
        render :edit
      end
    end

    private

    def password_params
      params.require(:user).permit(:current_password, :password, :password_confirmation)
    end
  end
end
