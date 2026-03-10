# Concern for jurisdiction validation logic
module JurisdictionValidation
  extend ActiveSupport::Concern

  included do
    # Validations are defined in the Application model
    # This concern exists for organization and future extension
    class_attribute :jurisdiction_field_name, default: nil
  end

  class_methods do
    # Set which field stores the jurisdiction
    def jurisdiction_field=(field_name)
      self.jurisdiction_field_name = field_name
    end

    # Get the jurisdiction field name
    def jurisdiction_field
      jurisdiction_field_name
    end
  end

  # Normalize jurisdiction code to standard format (uppercase)
  def self.normalize_jurisdiction(code)
    return nil unless code.present?
    code.to_s.upcase
  end

  # NOTE: Actual jurisdiction validation methods are defined in Application model:
  # - region_matches_user_jurisdiction (private)
  # - validate_epm_jurisdiction_rules (private)
  # - user_home_jurisdiction_code (private)
end
