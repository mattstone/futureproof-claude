class LegalController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :ensure_email_verified!

  before_action :set_region_from_params

  # GET /legal/contracts/mortgage/:region
  def mortgage_contract
    render "legal/contracts/mortgage_#{@legal_region}"
  end

  # GET /legal/contracts/wholesale_funder/:region
  def wholesale_funder_agreement
    render "legal/agreements/wholesale_funder_#{@legal_region}"
  end

  # GET /legal/contracts/investment_management/:region
  def investment_management_agreement
    render "legal/agreements/investment_management_#{@legal_region}"
  end

  # GET /legal/contracts/referral_partner/:region
  def referral_partner_agreement
    render "legal/agreements/referral_partner_#{@legal_region}"
  end

  # GET /legal/terms/:region
  def terms
    render "legal/terms/terms_#{@legal_region}"
  end

  # GET /legal/privacy/:region
  def privacy
    render "legal/privacy/privacy_#{@legal_region}"
  end

  # GET /legal/index
  def index
    @regions = RegionHelper.all_regions
  end

  private

  def set_region_from_params
    code = params[:region]&.downcase || current_region
    @legal_region = RegionHelper.valid_region?(code) ? code : RegionHelper.default_region
    @legal_config = RegionHelper.region_config(@legal_region)
  end
end
