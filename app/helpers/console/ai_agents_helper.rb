module Console::AiAgentsHelper
  # Maps an AgentAction's polymorphic actionable to its console page so the
  # action log can link through to the entity that triggered it. Unknown
  # types fall back to nil (the caller renders plain text).
  def entity_path_for(action)
    case action.actionable_type
    when "Application" then console_application_path(action.actionable_id)
    when "Contract" then console_contract_path(action.actionable_id)
    when "User" then console_user_path(action.actionable_id)
    end
  end
end
