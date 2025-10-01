class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :privacy_policy, :terms_of_use, :terms_and_conditions, :apply, :hero_option_1, :hero_option_2, :hero_option_3]
  
  def index
    # Homepage
  end

  def privacy_policy
    @privacy_policy = PrivacyPolicy.current
  end

  def terms_of_use
    @terms_of_use = TermsOfUse.current
  end

  def terms_and_conditions
    @terms_and_conditions = TermsAndCondition.current
  end

  def apply
    # Apply page - Application process steps
  end

  def hero_option_1
    # Hero design option 1 preview
  end

  def hero_option_2
    # Hero design option 2 preview
  end

  def hero_option_3
    # Hero design option 3 preview
  end
end