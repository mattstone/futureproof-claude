module Borrower
  class AccountsController < BaseController
    # Show account settings
    def show
    end

    # Edit account settings
    def edit
    end

    # Update account info
    def update
      if current_user.update(account_params)
        redirect_to borrower_account_path, notice: "Account updated successfully."
      else
        flash.now[:alert] = "Failed to update account."
        render :edit
      end
    end

    private

    def account_params
      params.require(:user).permit(:first_name, :last_name, :email, :phone)
    end
  end
end
