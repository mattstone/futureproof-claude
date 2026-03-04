module RegionHelper
  REGIONS_CONFIG = YAML.load_file(Rails.root.join("config", "regions.yml"))["regions"].freeze

  VALID_REGION_CODES = REGIONS_CONFIG.keys.freeze
  DEFAULT_REGION = REGIONS_CONFIG.find { |_k, v| v["default"] }&.first || "us"

  def self.all_regions
    REGIONS_CONFIG
  end

  def self.region_config(code)
    REGIONS_CONFIG[code.to_s.downcase] || REGIONS_CONFIG[DEFAULT_REGION]
  end

  def self.valid_region?(code)
    VALID_REGION_CODES.include?(code.to_s.downcase)
  end

  def self.default_region
    DEFAULT_REGION
  end

  # Instance methods for use in controllers/views
  def current_region
    @current_region ||= determine_region
  end

  def region_config
    @region_config ||= RegionHelper.region_config(current_region)
  end

  def region_currency
    region_config["currency"]
  end

  def region_currency_symbol
    region_config["currency_symbol"]
  end

  def region_name
    region_config["name"]
  end

  def region_legislation
    region_config["legislation"]
  end

  def region_regulatory_body
    region_config["regulatory_body"]
  end

  def format_currency(amount)
    "#{region_currency_symbol}#{number_with_delimiter(amount.to_i)}"
  end

  def region_date_format
    region_config["date_format"]
  end

  def format_region_date(date)
    date&.strftime(region_date_format) || ""
  end

  private

  def determine_region
    # Priority: 1) URL path prefix, 2) subdomain, 3) session, 4) default
    region_from_path || region_from_subdomain || region_from_session || RegionHelper::DEFAULT_REGION
  end

  def region_from_path
    prefix = request.path.split("/")[1]&.downcase
    prefix if RegionHelper.valid_region?(prefix)
  rescue
    nil
  end

  def region_from_subdomain
    sub = request.subdomain&.downcase
    sub if RegionHelper.valid_region?(sub)
  rescue
    nil
  end

  def region_from_session
    code = session[:region]&.downcase
    code if code && RegionHelper.valid_region?(code)
  rescue
    nil
  end
end
