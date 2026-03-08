module Admin::AdminHelper
  # Filter scope based on current admin jurisdiction session
  # Returns all records for "Summary" view, scoped to jurisdiction for specific views
  # Handles mapping between jurisdiction codes (AU/US) and region codes (au/us)
  def jurisdiction_filtered_scope(scope, jurisdiction_field = :country)
    selected_jurisdiction = session[:admin_jurisdiction] || "Summary"
    
    return scope if selected_jurisdiction == "Summary"
    
    # Map jurisdiction codes to possible field values (uppercase, lowercase, full names)
    possible_values = case selected_jurisdiction.upcase
      when "AU"
        ["AU", "au", "Australia"]
      when "US"
        ["US", "us", "United States"]
      when "NZ"
        ["NZ", "nz", "New Zealand"]
      when "UK"
        ["UK", "uk", "United Kingdom"]
      else
        [selected_jurisdiction]
    end
    
    scope.where(jurisdiction_field => possible_values)
  end

  # Get current jurisdiction from session
  def current_admin_jurisdiction
    session[:admin_jurisdiction] || "Summary"
  end

  # Map jurisdiction codes to full names
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
