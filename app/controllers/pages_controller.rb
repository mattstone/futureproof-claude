class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :privacy_policy, :terms_of_use, :terms_and_conditions, :apply, :hero_option_1, :hero_option_2, :hero_option_3, :get_started, :tax_discussion ]

  def index
    # Homepage
  end

  def get_started
    @show_akane_chat = true
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

    # Detect market from params, or geo-detect from IP/headers
    @detected_market = params[:market].presence || detect_market_from_request

    # Load published FAQs for this jurisdiction
    jurisdiction = detect_jurisdiction_for_legal
    @faqs = Faq.published.for_jurisdiction(jurisdiction).ordered
  end

  def tax_discussion
    @jurisdiction = detect_jurisdiction_for_legal
    @region_config = region_tax_config(@jurisdiction)

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "FutureProof_Tax_Discussion_#{@jurisdiction}",
               template: "pages/tax_discussion.pdf",
               layout: "pdf",
               disposition: "attachment"
      end
    end
  end

  private

  # Map URL region prefix to LegalDocument jurisdiction code
  def detect_jurisdiction_for_legal
    region = params[:region]&.downcase
    case region
    when "au" then "AU"
    when "nz" then "NZ"
    when "uk" then "UK"
    else "US"
    end
  end

  # Detect market based on IP geolocation or browser hints
  # Returns 'au' for Australia/New Zealand, 'us' for everywhere else
  def detect_market_from_request
    # 1. Check CloudFlare's country header (if behind CF)
    cf_country = request.headers["CF-IPCountry"]
    if cf_country.present?
      return "au" if %w[AU NZ].include?(cf_country.upcase)
      return "us"
    end

    # 2. Check Fly.io's country header (if deployed on Fly)
    fly_country = request.headers["Fly-Client-Country"]
    if fly_country.present?
      return "au" if %w[AU NZ].include?(fly_country.upcase)
      return "us"
    end

    # 3. Check Accept-Language header for AU/NZ locale hints
    accept_language = request.headers["Accept-Language"].to_s.downcase
    if accept_language.include?("en-au") || accept_language.include?("en-nz")
      return "au"
    end

    # 4. Check timezone offset from cookie (set by JavaScript)
    # Australian timezones are typically UTC+8 to UTC+11
    tz_offset = cookies[:tz_offset].to_i
    if tz_offset != 0 && tz_offset >= -660 && tz_offset <= -480
      # Negative because JS getTimezoneOffset returns minutes behind UTC
      # Australia is UTC+8 to UTC+11, so offset is -480 to -660 minutes
      return "au"
    end

    # Default to US
    "us"
  end

  def region_tax_config(jurisdiction)
    configs = {
      "AU" => {
        country: "Australia",
        currency: "AUD",
        regulator: "Australian Prudential Regulation Authority (APRA)",
        tax_authority: "Australian Taxation Office (ATO)",
        gst_vat: "GST (10%)",
        capital_gains: "Capital Gains Tax (CGT) with 50% discount for assets held >12 months",
        income_tax: "Progressive rates 0%–45% plus 2% Medicare levy",
        stamp_duty: "State-based stamp duty on property transfers",
        reporting: "Annual tax return lodgement, BAS for GST-registered entities"
      },
      "NZ" => {
        country: "New Zealand",
        currency: "NZD",
        regulator: "Reserve Bank of New Zealand (RBNZ)",
        tax_authority: "Inland Revenue (IRD)",
        gst_vat: "GST (15%)",
        capital_gains: "No general CGT; Bright-line test applies to residential property",
        income_tax: "Progressive rates 10.5%–39%",
        stamp_duty: "No stamp duty in New Zealand",
        reporting: "Annual tax return, GST returns for registered persons"
      },
      "UK" => {
        country: "United Kingdom",
        currency: "GBP",
        regulator: "Financial Conduct Authority (FCA) & Prudential Regulation Authority (PRA)",
        tax_authority: "HM Revenue & Customs (HMRC)",
        gst_vat: "VAT (20%)",
        capital_gains: "Capital Gains Tax at 10%/20% (basic/higher rate) for non-residential, 18%/28% for residential",
        income_tax: "Progressive rates 20%–45%",
        stamp_duty: "Stamp Duty Land Tax (SDLT) on property purchases",
        reporting: "Self-Assessment tax returns, Making Tax Digital (MTD)"
      },
      "US" => {
        country: "United States",
        currency: "USD",
        regulator: "Consumer Financial Protection Bureau (CFPB) & State regulators",
        tax_authority: "Internal Revenue Service (IRS)",
        gst_vat: "No federal sales tax; state sales tax varies 0%–10.25%",
        capital_gains: "Long-term CGT at 0%/15%/20% (income dependent); NIIT 3.8% surcharge",
        income_tax: "Federal progressive rates 10%–37% plus state income tax",
        stamp_duty: "Transfer taxes vary by state and county",
        reporting: "Annual federal (Form 1040) and state tax returns, 1098/1099 reporting"
      }
    }
    configs[jurisdiction] || configs["US"]
  end

  # NOTE: everything from here down is a routed ACTION and must be public.
  # These sat below `private` for months, so Rails served the templates via
  # implicit rendering with nil ivars — the controller bodies never ran.
  public

  # LegalDocument is the single source of truth for legal content — the
  # legacy TermsOfUse/PrivacyPolicy/TermsAndCondition fallbacks were removed
  # when the consolidation migration replicated their content per
  # jurisdiction (verified by LegalConsolidationTest).
  def privacy_policy
    @legal_document = LegalDocument.current_for("privacy_policy", detect_jurisdiction_for_legal)
  end

  def terms_of_use
    @legal_document = LegalDocument.current_for("terms_of_use", detect_jurisdiction_for_legal)
  end

  def terms_and_conditions
    @legal_document = LegalDocument.current_for("terms_conditions", detect_jurisdiction_for_legal)
  end

  def apply
    @show_akane_chat = true
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
