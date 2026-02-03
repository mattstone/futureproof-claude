class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :privacy_policy, :terms_of_use, :terms_and_conditions, :apply, :hero_option_1, :hero_option_2, :hero_option_3, :get_started]

  def index
    # Homepage
  end

  def get_started
    # React webapp replica - mobile-first calculator experience
    # Loan lookup table for calculations (matches React app exactly)
    @loan_lookup = {
      10 => { interest_only: 300_000, principal_interest: 262_986 },
      15 => { interest_only: 410_468, principal_interest: 335_142 },
      20 => { interest_only: 443_306, principal_interest: 359_861 },
      25 => { interest_only: 498_478, principal_interest: 396_494 },
      30 => { interest_only: 553_088, principal_interest: 425_961 }
    }
    @base_property_value = 1_500_000
    @default_property_value = 1_500_000
    @min_property_value = 800_000
    @max_property_value = 10_000_000
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