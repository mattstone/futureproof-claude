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
    # If no stage config, use smart defaults based on event type
    Rails.logger.info "🤖 #{@agent.name} handling #{@event_type} for #{@entity.class.name}##{@entity.id}"

    if stage
      execute_stage_actions(stage)
      check_handoff_conditions(stage)
    end

    # Always run decision-driven flow to evaluate and log decisions
    decision_result = execute_decision_driven_flow

    {
      success: true,
      agent: @agent.name,
      stage: stage ? stage['stage_name'] : @event_type,
      decision: decision_result
    }
  rescue => e
    Rails.logger.error "❌ Agent lifecycle execution failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: e.message }
  end

  private

  # Execute a decision-driven flow for events without explicit stage config
  def execute_decision_driven_flow
    return nil unless @entity.is_a?(Application)

    case @event_type
    when 'application_created'
      handle_application_created
    when 'application_submitted'
      handle_application_submitted
    when 'application_processing', 'status_changed'
      handle_status_change
    else
      nil
    end
  end

  def handle_application_created
    decision_result = run_evaluation('evaluate')

    case decision_result&.decision
    when :approve
      log_action('communicate', 'approve', decision_result, "Welcome message sent")
      # Don't auto-advance on creation — user fills in details step by step
      decision_result
    when :flag
      log_action('communicate', 'flag', decision_result, "Clarification requested")
      decision_result
    when :reject
      log_action('decide', 'reject', decision_result, "Application rejected at intake")
      decision_result
    else
      decision_result
    end
  end

  def handle_application_submitted
    # Motoko final check
    motoko = AiAgent.find_by(name: 'Motoko')
    if motoko && @agent.id == motoko.id
      decision_result = run_evaluation('evaluate')
      log_action('handoff', decision_result&.decision&.to_s, decision_result, "Handing off to Rei")

      # Hand off to Rei
      rei = AiAgent.find_by(name: 'Rei')
      if rei
        @agent = rei
        rei_result = run_evaluation('evaluate')
        if rei_result&.decision == :approve
          log_action('decide', 'advance', rei_result, "Ready for processing")
        else
          log_action('decide', rei_result&.decision&.to_s, rei_result, "Not ready for processing")
        end
        return rei_result
      end
    end

    run_evaluation('evaluate')
  end

  def handle_status_change
    return nil unless @context[:to_status].present?

    new_status = @context[:to_status].to_s

    case new_status
    when 'processing', '5'
      # Rei evaluates processing readiness
      decision_result = run_evaluation('evaluate')
      if decision_result&.decision == :approve
        log_action('decide', 'advance', decision_result, "Processing complete, recommending acceptance")
        # Hand off to Yumi
        yumi = AiAgent.find_by(name: 'Yumi')
        if yumi
          log_action('handoff', 'advance', decision_result, "Handing off to Yumi for acceptance")
        end
      else
        log_action('decide', decision_result&.decision&.to_s, decision_result, "Processing issues found")
      end
      decision_result
    when 'accepted', '7'
      # Yumi evaluates for acceptance
      yumi = AiAgent.find_by(name: 'Yumi')
      @agent = yumi if yumi
      decision_result = run_evaluation('evaluate')
      log_action('decide', decision_result&.decision&.to_s, decision_result, "Acceptance evaluation complete")
      decision_result
    else
      nil
    end
  end

  def run_evaluation(action_type)
    return nil unless @entity.is_a?(Application)

    service = AgentDecisionService.new(@agent, @entity)
    result = service.evaluate

    log_action(action_type, result.decision.to_s, result)
    result
  rescue => e
    Rails.logger.error "Decision evaluation failed: #{e.message}"
    log_action(action_type, 'failed', nil, "Evaluation error: #{e.message}")
    nil
  end

  def log_action(action_type, decision, decision_result = nil, notes = nil)
    AgentAction.create!(
      ai_agent: @agent,
      actionable: @entity,
      action_type: action_type,
      decision: decision,
      confidence: decision_result&.confidence,
      reasoning: decision_result&.reasoning || notes,
      context: {
        event_type: @event_type,
        entity_snapshot: entity_snapshot
      },
      result: decision_result ? {
        flags: decision_result.flags,
        risk_score: decision_result.risk_score,
        next_action: decision_result.next_action&.to_s,
        agent_notes: decision_result.agent_notes,
        contract_terms: decision_result.contract_terms
      } : { notes: notes },
      status: 'completed'
    )
  rescue => e
    Rails.logger.error "Failed to log agent action: #{e.message}"
  end

  def entity_snapshot
    if @entity.is_a?(Application)
      {
        id: @entity.id,
        status: @entity.status,
        home_value: @entity.home_value,
        borrower_age: @entity.borrower_age,
        ownership_status: @entity.ownership_status
      }
    else
      { id: @entity.id, type: @entity.class.name }
    end
  end

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
    when 'evaluate_application'
      execute_evaluate_application(action)
    when 'auto_advance'
      execute_auto_advance(action)
    when 'request_documents'
      execute_request_documents(action)
    when 'escalate_to_human'
      execute_escalate_to_human(action)
    else
      Rails.logger.warn "Unknown action type: #{action['action_type']}"
    end
  end

  # New action: evaluate application via AgentDecisionService
  def execute_evaluate_application(_action)
    result = run_evaluation('evaluate')
    return unless result

    case result.next_action
    when :advance
      @entity.advance_to_next_step! if @entity.respond_to?(:advance_to_next_step!)
    when :escalate
      execute_escalate_to_human('reason' => result.reasoning)
    end
  end

  # New action: auto-advance if evaluation passes
  def execute_auto_advance(_action)
    result = run_evaluation('evaluate')
    return unless result&.decision == :approve

    if @entity.respond_to?(:advance_to_next_step!)
      @entity.advance_to_next_step!
      log_action('decide', 'advance', result, "Auto-advanced application")
    end
  end

  # New action: request documents
  def execute_request_documents(action)
    doc_types = action['document_types'] || ApplicationDocument::REQUIRED_FOR_SUBMISSION

    if @entity.respond_to?(:application_documents)
      existing = @entity.application_documents.pluck(:document_type)
      missing = doc_types - existing
      missing.each do |doc_type|
        @entity.application_documents.create!(
          document_type: doc_type,
          status: :pending,
          name: doc_type.humanize
        )
      end
      log_action('communicate', 'request_info', nil, "Requested documents: #{missing.join(', ')}")
    else
      log_action('communicate', 'request_info', nil, "Document request logged: #{doc_types.join(', ')}")
    end
  end

  # New action: escalate to human
  def execute_escalate_to_human(action)
    reason = action['reason'] || 'Flagged for manual review'
    log_action('escalate', 'flag', nil, reason)
    Rails.logger.info "🚨 #{@agent.name} escalated #{@entity.class.name}##{@entity.id}: #{reason}"
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
        log_action('handoff', 'advance', nil, "Handed off to #{target_agent.name}")
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
