# Concern for jurisdiction validation logic
module JurisdictionValidation
  extend ActiveSupport::Concern

  included do
    # Validations are defined in the Application model
    # This concern exists for organization and future extension
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
