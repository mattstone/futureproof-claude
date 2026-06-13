# Concern for jurisdiction validation and scoping
# Standardizes jurisdiction handling across models
# Converts between ISO codes (AU, US, NZ, UK) and full names (Australia, United States, etc.)

module JurisdictionValidation
  extend ActiveSupport::Concern

  # Module-level normalize method (callable as JurisdictionValidation.normalize_jurisdiction)
  def self.normalize_jurisdiction(input)
    return nil if input.blank?

    code = input.to_s.upcase

    # Already a code (AU, US, NZ, UK)
    return code if VALID_JURISDICTIONS.include?(code)

    # Convert full name to code
    ISO_TO_CODE[input.to_s] || code
  end

  # Standardized jurisdiction constants
  JURISDICTION_MAP = {
    "AU" => "Australia",
    "US" => "United States",
    "NZ" => "New Zealand",
    "UK" => "United Kingdom"
  }.freeze

  ISO_TO_CODE = {
    "Australia" => "AU",
    "United States" => "US",
    "New Zealand" => "NZ",
    "United Kingdom" => "UK"
  }.freeze

  VALID_JURISDICTIONS = JURISDICTION_MAP.keys.freeze
  VALID_JURISDICTION_NAMES = JURISDICTION_MAP.values.freeze

  included do
    # Only add AR validations/scopes for ActiveRecord models
    if respond_to?(:validate) && respond_to?(:scope)
      validate :validate_jurisdiction_code, if: -> { respond_to?(self.class.jurisdiction_field) }
      scope :by_jurisdiction, ->(code) { where(self.class.jurisdiction_field => normalize_jurisdiction(code)) }
    end
  end

  class_methods do
    # Set which field stores jurisdiction (default: :jurisdiction)
    def jurisdiction_field
      @jurisdiction_field || :jurisdiction
    end

    def jurisdiction_field=(field)
      @jurisdiction_field = field
    end

    # Normalize jurisdiction input (converts full names to ISO codes)
    def normalize_jurisdiction(input)
      return nil if input.blank?

      code = input.to_s.upcase

      # Already a code (AU, US, NZ, UK)
      return code if VALID_JURISDICTIONS.include?(code)

      # Convert full name to code
      ISO_TO_CODE[input.to_s] || code
    end

    # Get full jurisdiction name from code
    def jurisdiction_name(code)
      JURISDICTION_MAP[code.to_s.upcase] || code
    end
  end

  # Instance methods
  def jurisdiction_code
    code = send(self.class.jurisdiction_field)
    self.class.normalize_jurisdiction(code)
  end

  def jurisdiction_name
    self.class.jurisdiction_name(jurisdiction_code)
  end

  def jurisdiction_code=(code)
    send("#{self.class.jurisdiction_field}=", self.class.normalize_jurisdiction(code))
  end

  # Validate jurisdiction is valid ISO code
  def validate_jurisdiction_code
    code = send(self.class.jurisdiction_field)
    return if code.blank?

    normalized = self.class.normalize_jurisdiction(code)

    unless VALID_JURISDICTIONS.include?(normalized)
      field_name = self.class.jurisdiction_field
      errors.add(field_name, "must be a valid jurisdiction (AU, US, NZ, UK)")
    end
  end

  # Check if jurisdiction matches another object's jurisdiction
  def jurisdiction_matches?(other)
    other_code = case other
    when String
                   self.class.normalize_jurisdiction(other)
    when JurisdictionValidation
                   other.jurisdiction_code
    else
                   return false
    end

    jurisdiction_code == other_code
  end
end
