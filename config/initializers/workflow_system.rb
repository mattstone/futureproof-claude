# Workflow System Feature Flag Configuration
# Controls which workflow system version is active

module WorkflowSystem
  # Feature flag to control workflow system version
  # 'v1' = Current email workflow system (stable, working)
  # 'v2' = New 3-workflow business process system (development)
  VERSION = ENV.fetch('WORKFLOW_SYSTEM_VERSION', 'v1')
  
  # Safety check - only allow valid versions
  VALID_VERSIONS = %w[v1 v2].freeze
  unless VALID_VERSIONS.include?(VERSION)
    Rails.logger.error "Invalid WORKFLOW_SYSTEM_VERSION: #{VERSION}. Using 'v1' as fallback."
    VERSION = 'v1'
  end
  
  # Helper methods for controllers and views
  def self.use_v2?
    VERSION == 'v2'
  end
  
  def self.use_v1?
    VERSION == 'v1'
  end
  
  # Admin override - allows admins to test v2 regardless of global setting
  def self.use_v2_for_user?(user, params = {})
    return true if VERSION == 'v2'
    return false unless user&.admin?
    params[:workflow_version] == 'v2' || params[:use_new_workflows] == 'true'
  end
  
  Rails.logger.info "Workflow System initialized: VERSION=#{VERSION}"
end