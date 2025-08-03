class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :privacy_policy, :terms_of_use, :apply]
  
  def index
    # Homepage
  end

  def privacy_policy
    # Privacy Policy page
  end

  def terms_of_use
    @terms_of_use = TermsOfUse.current
  end

  def apply
    # Apply page - Application process steps
  end
end