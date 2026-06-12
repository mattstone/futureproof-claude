# The customer-service operational view: who's waiting on us, where the
# pipeline is aging, what's escalated.
class Console::ServiceDeskController < Console::BaseController
  before_action -> { require_capability(:manage_users) }

  def show
    presenter = Console::ServiceDeskPresenter.new
    @health = presenter.health_snapshot
    @pipeline_aging = presenter.pipeline_aging
    @unanswered_threads = presenter.unanswered_threads
    @stalled_applications = presenter.stalled_applications
    @escalated_conversations = presenter.escalated_conversations
    @urgent_tickets = presenter.urgent_tickets
  end
end
