# Background job for executing delayed agent actions
class AgentActionJob < ApplicationJob
  queue_as :default

  def perform(agent_id:, entity_type:, entity_id:, action:, stage_name:, context: {})
    agent = AiAgent.find_by(id: agent_id)
    return unless agent

    entity = entity_type.constantize.find_by(id: entity_id)
    return unless entity

    Rails.logger.info "⏰ Executing delayed action for #{agent.name}: #{action['action_type']}"

    # Create a temporary service instance to execute the action
    service = AgentLifecycleService.new(entity, stage_name, context)
    service.instance_variable_set(:@agent, agent)
    service.send(:execute_action_now, action)
  rescue => e
    Rails.logger.error "Failed to execute delayed agent action: #{e.message}"
    raise e
  end
end