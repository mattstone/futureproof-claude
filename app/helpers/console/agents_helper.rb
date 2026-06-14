module Console::AgentsHelper
  # The active agent(s) serving a business function, keyed by agent_type. Used
  # to co-locate each agent's live operations inside its functional area
  # (Akane on Acquisition, Rie on Contracts, Yumi on Investments). Returns an
  # empty relation if none is configured yet (e.g. customer_service before a
  # support agent is provisioned), so callers render nothing gracefully.
  #
  #   applications      -> Acquisition
  #   backoffice        -> Contracts / back-office
  #   investment        -> Investments (Finance)
  #   customer_service  -> Customer Service  (future)
  def agents_for_function(agent_type)
    AiAgent.active.where(agent_type: agent_type).order(:name)
  end
end
