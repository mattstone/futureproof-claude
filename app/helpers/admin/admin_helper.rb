module Admin::AdminHelper
  # Filter scope based on current admin jurisdiction session
  # Returns all records for "Summary" view, scoped to jurisdiction for specific views
  # Handles mapping between jurisdiction codes (AU/US) and region codes (au/us)
  def jurisdiction_filtered_scope(scope, jurisdiction_field = :country)
    selected_jurisdiction = session[:admin_jurisdiction] || "Summary"
    
    return scope if selected_jurisdiction == "Summary"
    
    # Map jurisdiction selector values to region field values (case-insensitive)
    region_value = selected_jurisdiction.downcase
    scope.where(jurisdiction_field => region_value)
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
