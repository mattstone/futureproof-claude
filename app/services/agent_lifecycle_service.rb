# Service for executing agent-owned lifecycle workflows
# Replaces complex graph-based workflow execution with simple stage-based execution
class AgentLifecycleService
  attr_reader :entity, :event_type, :context, :agent

  def initialize(entity, event_type, context = {})
    @entity = entity
    @event_type = event_type
    @context = context
    @agent = nil
  end

  # Main execution method
  def execute!
    @agent = determine_responsible_agent
    return { success: false, error: 'No agent found for this event' } unless @agent

    stage = find_stage_for_event
    return { success: false, error: 'No stage configuration found' } unless stage

    Rails.logger.info "🤖 #{@agent.name} handling #{@event_type} for #{@entity.class.name}##{@entity.id}"

    execute_stage_actions(stage)
    check_handoff_conditions(stage)

    { success: true, agent: @agent.name, stage: stage['stage_name'] }
  rescue => e
    Rails.logger.error "❌ Agent lifecycle execution failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: e.message }
  end

  private

  # Determine which agent should handle this event
  def determine_responsible_agent
    case @entity
    when Application
      agent_for_application_stage
    when Contract
      AiAgent.find_by(name: 'Yumi') # Yumi always handles contracts
    else
      AiAgent.active.first # Fallback to first active agent
    end
  end

  # Map application stages to agents
  def agent_for_application_stage
    case @event_type
    when 'user_registered', 'application_created', 'application_started'
      AiAgent.find_by(name: 'Motoko') # Acquisition
    when 'application_submitted', 'application_processing', 'application_review'
      AiAgent.find_by(name: 'Rei') # Operations
    when 'application_accepted', 'contract_created', 'contract_active'
      AiAgent.find_by(name: 'Yumi') # Lifetime management
    else
      # Dynamic determination based on application status
      determine_by_status
    end
  end

  def determine_by_status
    return nil unless @entity.respond_to?(:status)

    case @entity.status.to_s
    when 'created', 'user_details', 'property_details', 'income_and_loan_options'
      AiAgent.find_by(name: 'Motoko')
    when 'submitted', 'processing'
      AiAgent.find_by(name: 'Rei')
    when 'accepted'
      AiAgent.find_by(name: 'Yumi')
    else
      AiAgent.find_by(name: 'Motoko') # Default to Motoko for unknown statuses
    end
  end

  # Find the lifecycle stage configuration for this event
  def find_stage_for_event
    return nil unless @agent&.lifecycle_stages.present?

    @agent.lifecycle_stages.find do |stage|
      stage['entry_trigger'] == @event_type ||
      stage['entry_triggers']&.include?(@event_type)
    end
  end

  # Execute all automated actions for a stage
  def execute_stage_actions(stage)
    actions = stage['automated_actions'] || []

    actions.each do |action|
      next unless should_execute_action?(action)

      if has_delay?(action)
        schedule_delayed_action(action, stage)
      else
        execute_action_now(action)
      end
    end
  end

  # Check if action should be executed based on conditions
  def should_execute_action?(action)
    conditions = action['conditions']
    return true if conditions.blank?

    evaluate_conditions(conditions)
  end

  # Evaluate action conditions
  def evaluate_conditions(conditions)
    conditions.all? do |key, value|
      entity_value = @entity.send(key) if @entity.respond_to?(key)

      case value
      when Array
        value.include?(entity_value.to_s)
      when Hash
        evaluate_complex_condition(entity_value, value)
      else
        entity_value.to_s == value.to_s
      end
    end
  rescue => e
    Rails.logger.error "Failed to evaluate condition: #{e.message}"
    false
  end

  # Evaluate complex conditions (operators)
  def evaluate_complex_condition(entity_value, condition_hash)
    operator = condition_hash['operator']
    expected = condition_hash['value']

    case operator
    when 'equals'
      entity_value.to_s == expected.to_s
    when 'not_equals'
      entity_value.to_s != expected.to_s
    when 'greater_than'
      entity_value.to_f > expected.to_f
    when 'less_than'
      entity_value.to_f < expected.to_f
    when 'contains'
      entity_value.to_s.include?(expected.to_s)
    else
      false
    end
  end

  # Check if action has a delay
  def has_delay?(action)
    delay = action['delay']
    delay.present? && delay['duration'].to_i > 0
  end

  # Execute action immediately
  def execute_action_now(action)
    case action['action_type']
    when 'send_email'
      send_agent_email(action)
    when 'create_task'
      create_task(action)
    when 'update_status'
      update_entity_status(action)
    when 'notify_admin'
      notify_admin(action)
    else
      Rails.logger.warn "Unknown action type: #{action['action_type']}"
    end
  end

  # Schedule delayed action
  def schedule_delayed_action(action, stage)
    delay = action['delay']
    duration = delay['duration'].to_i
    unit = delay['unit'] || 'minutes'

    delay_time = duration.send(unit)

    Rails.logger.info "📅 Scheduling #{action['action_type']} in #{duration} #{unit}"

    AgentActionJob.set(wait: delay_time).perform_later(
      agent_id: @agent.id,
      entity_type: @entity.class.name,
      entity_id: @entity.id,
      action: action,
      stage_name: stage['stage_name'],
      context: @context
    )
  end

  # Send email through agent
  def send_agent_email(action)
    template_id = action['email_template_id']
    template = EmailTemplate.find_by(id: template_id)

    unless template
      Rails.logger.error "Email template #{template_id} not found"
      return
    end

    user = get_target_user
    return unless user&.email

    # Render email content with context
    rendered = template.render_content(build_email_context(user))

    # Send email with agent branding
    WorkflowMailer.send_agent_email(
      agent: @agent,
      to: user.email,
      subject: rendered[:subject],
      body: rendered[:content],
      from_name: @agent.name
    ).deliver_now

    Rails.logger.info "✉️  #{@agent.name} sent email '#{template.name}' to #{user.email}"
  rescue => e
    Rails.logger.error "Failed to send agent email: #{e.message}"
  end

  # Create task for human operator
  def create_task(action)
    # TODO: Implement task creation system
    Rails.logger.info "📋 Creating task: #{action['task_type']}"
  end

  # Update entity status
  def update_entity_status(action)
    new_status = action['new_status']
    return unless new_status && @entity.respond_to?(:status=)

    @entity.update!(status: new_status)
    Rails.logger.info "✅ Updated #{@entity.class.name}##{@entity.id} status to #{new_status}"
  end

  # Notify admin
  def notify_admin(action)
    # TODO: Implement admin notification system
    Rails.logger.info "🔔 Notifying admin: #{action['message']}"
  end

  # Check if stage conditions require handoff to another agent
  def check_handoff_conditions(stage)
    handoff_to = stage['handoff_to']
    handoff_conditions = stage['handoff_conditions']

    return unless handoff_to && handoff_conditions

    if evaluate_conditions(handoff_conditions)
      target_agent = AiAgent.find_by(name: handoff_to.to_s.capitalize)

      if target_agent
        Rails.logger.info "🔄 Handing off from #{@agent.name} to #{target_agent.name}"
        # TODO: Trigger handoff workflow
      end
    end
  end

  # Get the user associated with this entity
  def get_target_user
    case @entity
    when Application
      @entity.user
    when Contract
      @entity.application&.user
    when User
      @entity
    else
      nil
    end
  end

  # Build email template context
  def build_email_context(user)
    {
      user: user,
      application: @entity.is_a?(Application) ? @entity : @entity.try(:application),
      contract: @entity.is_a?(Contract) ? @entity : nil,
      agent: @agent,
      entity: @entity,
      context: @context
    }
  end
end