module Admin::AdminHelper
  # Filter scope based on current admin jurisdiction session
  # Returns all records for "Summary" view, scoped to jurisdiction for specific views
  def jurisdiction_filtered_scope(scope, jurisdiction_field = :country)
    selected_jurisdiction = session[:admin_jurisdiction] || "Summary"
    
    return scope if selected_jurisdiction == "Summary"
    
    scope.where(jurisdiction_field => selected_jurisdiction)
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
