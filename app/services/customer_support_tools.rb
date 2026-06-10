class CustomerSupportTools
  TOOL_DEFINITIONS = [
    {
      name: 'get_user_region',
      description: "Returns the authenticated user's region (au, us, nz, uk). Use this when you need to give region-specific guidance and the user has not stated their region.",
      input_schema: { type: 'object', properties: {}, required: [] }
    },
    {
      name: 'get_user_applications',
      description: "Returns the authenticated user's mortgage applications: id, status, region, age in days, last update. Use this when the user asks about *their* applications.",
      input_schema: { type: 'object', properties: {}, required: [] }
    },
    {
      name: 'get_application_status',
      description: 'Returns detailed status for a specific application owned by the authenticated user — current state, missing documents, blockers. Use after get_user_applications to drill in.',
      input_schema: {
        type: 'object',
        properties: {
          application_id: { type: 'integer', description: 'The numeric application id from get_user_applications' }
        },
        required: ['application_id']
      }
    }
  ].freeze

  def self.for(user)
    new(user)
  end

  def self.tool_definitions
    TOOL_DEFINITIONS
  end

  def initialize(user)
    @user = user
  end

  def call(name:, input:)
    return error('Authentication required for this tool') unless @user

    case name
    when 'get_user_region'
      get_user_region
    when 'get_user_applications'
      get_user_applications
    when 'get_application_status'
      get_application_status(input[:application_id] || input['application_id'])
    else
      error("Unknown tool: #{name}")
    end
  rescue StandardError => e
    Rails.logger.error("CustomerSupportTools##{name} failed: #{e.class}: #{e.message}")
    error("Tool execution failed: #{e.class}")
  end

  private

  def get_user_region
    region = @user.respond_to?(:country) ? @user.country : nil
    region ||= @user.applications.first&.region
    region ? "Region: #{region.upcase}" : 'Region not set on account'
  end

  def get_user_applications
    applications = @user.applications.order(updated_at: :desc).limit(10)
    return 'No applications found for this user.' if applications.empty?

    applications.map do |app|
      "##{app.id}: status=#{app.status}, region=#{app.region}, age_days=#{(Date.today - app.created_at.to_date).to_i}, last_update=#{app.updated_at.iso8601}"
    end.join("\n")
  end

  def get_application_status(application_id)
    return error('application_id is required') unless application_id

    app = @user.applications.find_by(id: application_id)
    return error("Application #{application_id} not found or not owned by this user") unless app

    docs = app.application_documents
    outstanding = docs.outstanding.pluck(:document_type)
    complete = docs.complete.pluck(:document_type)

    [
      "Application ##{app.id}",
      "Status: #{app.status}",
      "Region: #{app.region}",
      "Created: #{app.created_at.to_date}",
      "Last update: #{app.updated_at.to_date}",
      "Documents complete: #{complete.any? ? complete.join(', ') : 'none'}",
      "Documents outstanding: #{outstanding.any? ? outstanding.join(', ') : 'none'}"
    ].join("\n")
  end

  def error(message)
    "ERROR: #{message}"
  end
end
