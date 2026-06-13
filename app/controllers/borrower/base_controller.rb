module Borrower
  class BaseController < ApplicationController
    layout "borrower"

    before_action :authenticate_user!
    before_action :ensure_email_verified!
  end
end
