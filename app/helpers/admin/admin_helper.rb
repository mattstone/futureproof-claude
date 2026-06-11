module Admin::AdminHelper
  # Valid ISO 3166-1 alpha-2 country codes
  VALID_JURISDICTION_CODES = ["AU", "US", "NZ", "UK"].freeze

  # Filter scope based on current admin jurisdiction session
  # Returns all records for "Summary" view, scoped to jurisdiction for specific views
  # Uses standardized ISO 3166-1 alpha-2 country codes (AU, US, NZ, UK)
  def jurisdiction_filtered_scope(scope, jurisdiction_field = :country)
    selected_jurisdiction = session[:admin_jurisdiction] || "Summary"
    
    return scope if selected_jurisdiction == "Summary"
    
    # All country fields are now standardized to uppercase ISO codes
    scope.where(jurisdiction_field => selected_jurisdiction)
  end

  # Get current jurisdiction from session
  def current_admin_jurisdiction
    session[:admin_jurisdiction] || "Summary"
  end

  # Map ISO 3166-1 alpha-2 codes to full country names
  def jurisdiction_display_name(jurisdiction_code)
    {
      "AU" => "Australia",
      "US" => "United States",
      "NZ" => "New Zealand",
      "UK" => "United Kingdom",
      "Summary" => "All Jurisdictions"
    }[jurisdiction_code] || jurisdiction_code
  end
end
