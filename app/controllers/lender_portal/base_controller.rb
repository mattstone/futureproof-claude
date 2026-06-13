module LenderPortal
  class BaseController < ApplicationController
    # Note: Pundit gem is not in Gemfile - removed include
    # Authorization handled by authenticate_user! and authorize_lender! checks

    before_action :authenticate_user!
    before_action :authorize_lender!
    before_action :set_current_lender

    layout "lender"

    private

    def authorize_lender!
      # User must be a lender type (User with role: 'lender')
      redirect_to root_path, alert: "Access denied" unless current_user&.lender?
    end

    def set_current_lender
      @current_lender = current_user
    end
  end
end
