# Concern for auditing cross-jurisdiction access
# Logs any access to data outside user's home jurisdiction
# Alerts admins to potential security issues

module JurisdictionAuditLogging
  extend ActiveSupport::Concern

  included do
    # Audit before accessing application data
    before_action :audit_jurisdiction_access, only: [:show, :edit, :update]
  end

  # ✅ CRITICAL: Audit cross-jurisdiction access
  def audit_jurisdiction_access
    return unless @application && current_user

    user_jurisdiction = user_home_jurisdiction_code(current_user)
    app_jurisdiction = @application.region

    if user_jurisdiction && app_jurisdiction != user_jurisdiction
      log_security_warning(
        "Cross-jurisdiction access",
        user_jurisdiction,
        app_jurisdiction,
        @application.id
      )
      
      # Could reject access here, or just alert
      # For now: log + alert (softer approach for launch)
    end
  end

  private

  # ✅ Get user's home jurisdiction as ISO code
  def user_home_jurisdiction_code(user)
    return nil unless user&.country_of_residence
    
    country_to_code = {
      'Australia' => 'AU',
      'United States' => 'US',
      'New Zealand' => 'NZ',
      'United Kingdom' => 'UK'
    }
    
    country_to_code[user.country_of_residence]
  end

  # ✅ Log security warning
  def log_security_warning(event_type, user_jurisdiction, accessed_jurisdiction, resource_id)
    log_entry = {
      timestamp: Time.current.iso8601,
      event_type: event_type,
      user_id: current_user.id,
      user_email: current_user.email,
      user_jurisdiction: user_jurisdiction,
      accessed_jurisdiction: accessed_jurisdiction,
      resource_id: resource_id,
      resource_type: controller_name.classify,
      remote_ip: request.remote_ip,
      user_agent: request.user_agent
    }

    # Log to security log
    Rails.logger.warn "[SECURITY] #{log_entry.to_json}"
    
    # Store in audit trail for investigation
    JurisdictionAuditLog.create!(log_entry)
    
    # Alert admin (can trigger email/notification)
    AdminMailer.security_alert(log_entry).deliver_later
  end

  # ✅ CRITICAL: Scope queries by user's jurisdiction
  def scope_applications_by_jurisdiction(applications = Application.all)
    return applications unless current_user
    
    user_jurisdiction = user_home_jurisdiction_code(current_user)
    return applications if user_jurisdiction.nil?
    
    applications.where(region: user_jurisdiction)
  end

  def scope_distributions_by_jurisdiction(distributions = Distribution.all)
    return distributions unless current_user
    
    # Join through application to filter by jurisdiction
    distributions.joins(:application).where(applications: { region: user_home_jurisdiction_code(current_user) })
  end
end
